require 'util/runcmd'
require 'awesome_spawn/spec_helper'

describe 'MiqUtil.runcmd' do
  include AwesomeSpawn::SpecHelper

  let(:cmd)        { 'echo Hi; echo Hitoo 1>&2' }
  let(:failed_cmd) { 'echo Hi; false --foo --bar -fkxv arg1' }

  # wrap in "/bin/sh -c" so this set of specs is shared between the original
  # implementation and AwesomeSpawn.run!
  def runcmd(cmd_str, args = {}, test = false)
    cmd_str = "/bin/sh -c '#{cmd_str}'" unless test
    MiqUtil.runcmd(cmd_str, test)
  end

  it "returns stdout & stderr as output" do
    expect(runcmd(cmd)).to eq("Hi\nHitoo\n")
  end

  it "raises the resulting output" do
    expect { runcmd(failed_cmd) }.to raise_error(RuntimeError)
  end

  context "test mode" do
    before { disable_spawning }

    it "prints the executed command" do
      cmd    = "true --opt1 foo --opt2=bar -fkvx arg1 arg2"
      output = "#{cmd}: Test output"

      expect(runcmd(cmd, nil, true)).to eq output
    end
  end
end
