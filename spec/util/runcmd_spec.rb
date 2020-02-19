require 'util/runcmd'
require 'awesome_spawn/spec_helper'

describe 'MiqUtil.runcmd' do
  include AwesomeSpawn::SpecHelper

  let(:cmd)        { 'echo Hi; echo Hitoo 1>&2' }
  let(:failed_cmd) { 'echo Hi; false --foo --bar -fkxv arg1' }

  # wrap in "/bin/sh -c" so this set of specs is shared between the original
  # implementation and AwesomeSpawn.run!
  def runcmd(cmd_str, args = {}, test = false)
    MiqUtil.runcmd(cmd_str, args, test)
  end

  it "returns stdout & stderr as output" do
    expect(runcmd(cmd)).to eq("Hi\nHitoo\n")
  end

  it "raises the resulting output" do
    expect { runcmd(failed_cmd) }.to raise_error(AwesomeSpawn::CommandResultError)
  end

  context "test mode" do
    before       { disable_spawning }
    let(:cmd)    { "true --opt1 foo --opt2=bar -fkvx arg1 arg2" }
    let(:output) { "#{cmd}: Test output" }

    it "prints the executed command" do
      expect(runcmd(cmd, true)).to eq output
    end

    it "works with a params hash for cmd_args" do
      args = {
        :opt1  => "foo",
        :opt2= => "bar",
        :f     => nil,
        :k     => nil,
        :v     => nil,
        :x     => nil,
        nil    => %w[arg1 arg2]
      }
      output.gsub!(/-fkvx/, "-f -k -v -x")

      expect(runcmd("true", {:params => args}, true)).to eq output
    end
  end
end
