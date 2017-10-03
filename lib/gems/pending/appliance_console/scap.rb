require 'linux_admin'

module ApplianceConsole
  class Scap
    def initialize(rules_dir)
      @rules_dir = rules_dir
    end

    def lockdown
      if packages_installed? && config_exists?
        say("Locking down the appliance for SCAP...")
        require 'yaml'
        scap_config = YAML.load_file(yaml_filename)
        begin
          LinuxAdmin::Scap.new("rhel7").lockdown(*scap_config['rules'], scap_config['values'])
        rescue => e
          say("Configuration failed: #{e.message}")
        else
          say("Complete")
        end
      end
    end

    private

    def yaml_filename
      File.expand_path("scap_rules.yml", @rules_dir)
    end

    def packages_installed?
      if !LinuxAdmin::Scap.openscap_available?
        say("OpenSCAP has not been installed")
        false
      elsif !LinuxAdmin::Scap.ssg_available?("rhel7")
        say("SCAP Security Guide has not been installed")
        false
      else
        true
      end
    end

    def config_exists?
      if File.exist?(yaml_filename)
        true
      else
        say("SCAP rules configuration file missing")
        false
      end
    end
  end
end
