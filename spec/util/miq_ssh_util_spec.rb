require 'util/MiqSshUtil'

RSpec.describe MiqSshUtil do
  let(:hostname) { 'localhost' }
  let(:username) { 'someuser' }
  let(:password) { 'xxxxxxxx' }

  let(:ssh_session)  { instance_double(Net::SSH::Connection::Session) }
  let(:ssh_channel)  { instance_double(Net::SSH::Connection::Channel) }
  let(:data)    { Net::SSH::Buffer.new([0].pack('N')) }

  let(:ssh_util) { MiqSshUtil.new(hostname, username, password) }

  before do
    allow(ssh_util).to receive(:run_session).and_yield(ssh_session)
  end

  def stub_channels
    allow(ssh_channel).to receive(:on_data).and_yield(ssh_channel, 'some_data')
    allow(ssh_channel).to receive(:on_request).with('exit-status').and_yield(ssh_channel, data)
    allow(ssh_channel).to receive(:on_request).with('exit-signal').and_yield(ssh_channel, data)
    allow(ssh_channel).to receive(:on_eof).and_yield(ssh_channel)
    allow(ssh_channel).to receive(:on_close).and_yield(ssh_channel)
    allow(ssh_channel).to receive(:on_extended_data).and_yield(ssh_channel, 1, '')
  end

  context "#exec" do
    before do
      stub_channels
      allow(ssh_session).to receive(:open_channel).and_yield(ssh_channel)
      allow(ssh_session).to receive(:loop)
    end

    it "raises an error if the command is unsuccessful" do
      allow(ssh_channel).to receive(:exec).and_yield(ssh_channel, false)
      expect { ssh_util.exec('bogus') }.to raise_error(RuntimeError, /could not execute command/i)
    end

    it "raises the expected error if a signal is found" do
      allow(ssh_channel).to receive(:exec).and_yield(ssh_channel, true)
      allow(data).to receive(:read_string).and_return('KILL')
      expect { ssh_util.exec('bogus') }.to raise_error(RuntimeError, /exited with signal KILL/i)
    end

    it "raises the expected error if a status is non-zero and error buffer is empty" do
      allow(ssh_channel).to receive(:exec).and_yield(ssh_channel, true)
      allow(data).to receive(:read_long).and_return(127)
      expect { ssh_util.exec('bogus') }.to raise_error(RuntimeError, /exited with status 127/i)
    end

    it "raises the expected error if a status is non-zero and error buffer is not empty" do
      allow(ssh_channel).to receive(:exec).and_yield(ssh_channel, true)
      allow(ssh_channel).to receive(:on_extended_data).and_yield(ssh_channel, 1, 'invalid')
      allow(data).to receive(:read_long).and_return(127)
      expect { ssh_util.exec('bogus') }.to raise_error(RuntimeError, /'bogus' failed: invalid, status: 127/i)
    end
  end

  context "#temp_cmd_file" do
    before do
      @ssh_util = MiqSshUtil.new("localhost", "temp", "something")
    end

    it "creates a file" do
      count = Dir.glob("/var/tmp/miq-*").size

      @ssh_util.temp_cmd_file("pwd") do |_cmd|
        expect(Dir.glob("/var/tmp/miq-*").size).to eq(count + 1)
      end
    end

    it "writes to file" do
      @ssh_util.temp_cmd_file("pwd") do |cmd|
        expect(File.read(cmd.split(";")[1].strip)).to eq("pwd")
      end
    end

    it "deletes the file" do
      count = Dir.glob("/var/tmp/miq-*").size
      @ssh_util.temp_cmd_file("pwd") {}

      expect(Dir.glob("/var/tmp/miq-*").size).to eq(count)
    end
  end
end
