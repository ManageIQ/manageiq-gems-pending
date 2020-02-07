require 'awesome_spawn'

class MiqUtil
  def self.runcmd(cmd, cmd_args = {}, test = false)
    unless [Hash, Array, String].any? { |klass| cmd_args.kind_of?(klass) }
      test     = cmd_args
      cmd_args = {}
    end

    args = { :combined_output => true }.merge(cmd_args)
    if !test
      rv = AwesomeSpawn.run!(cmd, args)
      rv.output
    else
      cmd_str = AwesomeSpawn::CommandLineBuilder.new.build(cmd, args[:params])
      "#{cmd_str}: Test output"
    end
  end
end
