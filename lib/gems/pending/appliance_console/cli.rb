require 'trollop'
require 'pathname'
require 'appliance_console/utilities'
require 'appliance_console/logging'
require 'appliance_console/database_configuration'
require 'appliance_console/internal_database_configuration'
require 'appliance_console/external_database_configuration'
require 'appliance_console/external_httpd_authentication'
require 'appliance_console/external_auth_options'
require 'appliance_console/temp_storage_configuration'
require 'appliance_console/key_configuration'
require 'appliance_console/principal'
require 'appliance_console/certificate'
require 'appliance_console/certificate_authority'
require 'appliance_console/logfile_configuration'
require 'appliance_console/database_maintenance_hourly'

# support for appliance_console methods
unless defined?(say)
  def say(arg)
    puts(arg)
  end
end

module ApplianceConsole
  class Cli
    attr_accessor :options

    # machine host
    def host
      options[:host] || LinuxAdmin::Hosts.new.hostname
    end

    # database hostname
    def hostname
      options[:internal] ? "localhost" : options[:hostname]
    end

    def local?(name = hostname)
      name.presence.in?(["localhost", "127.0.0.1", nil])
    end

    def set_host?
      options[:host]
    end

    def key?
      options[:key] || options[:fetch_key] || (local_database? && !key_configuration.key_exist?)
    end

    def database?
      hostname
    end

    def local_database?
      database? && local?(hostname)
    end

    def certs?
      options[:postgres_client_cert] || options[:postgres_server_cert] || options[:http_cert]
    end

    def uninstall_ipa?
      options[:uninstall_ipa]
    end

    def install_ipa?
      options[:ipaserver]
    end

    def tmp_disk?
      options[:tmpdisk]
    end

    def log_disk?
      options[:logdisk]
    end

    def time_zone?
      options[:timezone]
    end

    def extauth_opts?
      options[:extauth_opts]
    end

    def set_server_state?
      options[:server]
    end

    def db_hourly_maintenance?
      options[:db_hourly_maintenance]
    end

    def initialize(options = {})
      self.options = options
    end

    def disk_from_string(path)
      return if path.blank?
      path == "auto" ? disk : disk_by_path(path)
    end

    def disk
      LinuxAdmin::Disk.local.detect { |d| d.partitions.empty? }
    end

    def disk_by_path(path)
      LinuxAdmin::Disk.local.detect { |d| d.path == path }
    end

    def parse(args)
      args.shift if args.first == "--" # Handle when called through script/runner
      self.options = Trollop.options(args) do
        banner "Usage: appliance_console_cli [options]"

        opt :host,     "/etc/hosts name",    :type => :string,  :short => 'H'
        opt :region,   "Region Number",      :type => :integer, :short => "r"
        opt :internal, "Internal Database",                     :short => 'i'
        opt :hostname, "Database Hostname",  :type => :string,  :short => 'h'
        opt :port,     "Database Port",      :type => :integer,                :default => 5432
        opt :username, "Database Username",  :type => :string,  :short => 'U', :default => "root"
        opt :password, "Database Password",  :type => :string,  :short => "p"
        opt :dbname,   "Database Name",      :type => :string,  :short => "d", :default => "vmdb_production"
        opt :db_hourly_maintenance, "Configure database hourly maintenance", :type => :bool, :short => :none
        opt :standalone, "Run this server as a standalone database server", :type => :bool, :short => 'S'
        opt :key,      "Create encryption key",  :type => :boolean, :short => "k"
        opt :fetch_key, "SSH host with encryption key", :type => :string, :short => "K"
        opt :force_key, "Forcefully create encryption key", :type => :boolean, :short => "f"
        opt :sshlogin,  "SSH login",         :type => :string,                 :default => "root"
        opt :sshpassword, "SSH password",    :type => :string
        opt :verbose,  "Verbose",            :type => :boolean, :short => "v"
        opt :dbdisk,   "Database Disk Path", :type => :string
        opt :logdisk,  "Log Disk Path",      :type => :string
        opt :tmpdisk,   "Temp storage Disk Path", :type => :string
        opt :uninstall_ipa, "Uninstall IPA Client", :type => :boolean,         :default => false
        opt :ipaserver,  "IPA Server FQDN",  :type => :string
        opt :ipaprincipal,  "IPA Server principal", :type => :string,          :default => "admin"
        opt :ipapassword,   "IPA Server password",  :type => :string
        opt :ipadomain,     "IPA Server domain (optional)", :type => :string
        opt :iparealm,      "IPA Server realm (optional)", :type => :string
        opt :ca,                   "CA name used for certmonger",       :type => :string,  :default => "ipa"
        opt :timezone,             "Time zone",                         :type => :string
        opt :postgres_client_cert, "install certs for postgres client", :type => :boolean
        opt :postgres_server_cert, "install certs for postgres server", :type => :boolean
        opt :http_cert,            "install certs for http server",     :type => :boolean
        opt :extauth_opts,         "External Authentication Options",   :type => :string
        opt :server,               "Server status",                     :type => :string
      end
      Trollop.die :region, "needed when setting up a local database" if options[:region].nil? && local_database?
      self
    end

    def run
      Trollop.educate unless set_host? || key? || database? || tmp_disk? || log_disk? ||
                             uninstall_ipa? || install_ipa? || certs? || extauth_opts? ||
                             time_zone? || set_server_state? || db_hourly_maintenance?
      if set_host?
        system_hosts = LinuxAdmin::Hosts.new
        system_hosts.hostname = options[:host]
        system_hosts.set_loopback_hostname(options[:host])
        system_hosts.save
        LinuxAdmin::Service.new("network").restart
      end
      create_key if key?
      set_db if database?
      set_time_zone if time_zone?
      config_db_hourly_maintenance if db_hourly_maintenance?
      config_tmp_disk if tmp_disk?
      config_log_disk if log_disk?
      uninstall_ipa if uninstall_ipa?
      install_ipa if install_ipa?
      install_certs if certs?
      extauth_opts if extauth_opts?
      set_server_state if set_server_state?
    rescue AwesomeSpawn::CommandResultError => e
      say e.result.output
      say e.result.error
      say ""
      raise
    end

    def set_db
      raise "No encryption key (v2_key) present" unless key_configuration.key_exist?
      if local?
        set_internal_db
      else
        set_external_db
      end
    end

    def set_internal_db
      say "configuring internal database"
      config = ApplianceConsole::InternalDatabaseConfiguration.new({
        :database          => options[:dbname],
        :region            => options[:region],
        :username          => options[:username],
        :password          => options[:password],
        :interactive       => false,
        :disk              => disk_from_string(options[:dbdisk]),
        :run_as_evm_server => !options[:standalone]
      }.delete_if { |_n, v| v.nil? })

      # create partition, pv, vg, lv, ext4, update fstab, mount disk
      # initdb, relabel log directory for selinux, update configs,
      # start pg, create user, create db update the rails configuration,
      # verify, set up the database with region. activate does it all!
      unless config.activate
        say "Failed to configure internal database"
        return
      end

      # enable/start related services
      config.post_activation
    end

    def set_external_db
      say "configuring external database"
      config = ApplianceConsole::ExternalDatabaseConfiguration.new({
        :host        => options[:hostname],
        :port        => options[:port],
        :database    => options[:dbname],
        :region      => options[:region],
        :username    => options[:username],
        :password    => options[:password],
        :interactive => false,
      }.delete_if { |_n, v| v.nil? })

      # call create_or_join_region (depends on region value)
      unless config.activate
        say "Failed to configure external database"
        return
      end

      # enable/start related services
      config.post_activation
    end

    def set_time_zone
      timezone_config = ApplianceConsole::TimezoneConfiguration.new(options[:timezone])
      if timezone_config.activate
        say("Timezone configured")
      else
        say("Timezone not configured")
      end
    end

    def key_configuration
      @key_configuration ||= KeyConfiguration.new(
        :action   => options[:fetch_key] ? :fetch : :create,
        :force    => options[:fetch_key] ? true : options[:force_key],
        :host     => options[:fetch_key],
        :login    => options[:sshlogin],
        :password => options[:sshpassword],
      )
    end

    def create_key
      say "#{key_configuration.action} encryption key"
      unless key_configuration.activate
        raise "Could not create encryption key (v2_key)"
      end
    end

    def install_certs
      say "creating ssl certificates"
      config = CertificateAuthority.new(
        :hostname => host,
        :realm    => options[:iparealm],
        :ca_name  => options[:ca],
        :pgclient => options[:postgres_client_cert],
        :pgserver => options[:postgres_server_cert],
        :http     => options[:http_cert],
        :verbose  => options[:verbose],
      )

      config.activate
      say "\ncertificate result: #{config.status_string}"
      unless config.complete?
        say "After the certificates are retrieved, rerun to update service configuration files"
      end
    end

    def install_ipa
      raise "please uninstall ipa before reinstalling" if ExternalHttpdAuthentication.ipa_client_configured?
      config = ExternalHttpdAuthentication.new(
        host,
        :ipaserver => options[:ipaserver],
        :domain    => options[:ipadomain],
        :realm     => options[:iparealm],
        :principal => options[:ipaprincipal],
        :password  => options[:ipapassword],
      )

      config.post_activation if config.activate
    end

    def uninstall_ipa
      say "Uninstalling IPA-client"
      config = ExternalHttpdAuthentication.new
      config.deactivate if config.ipa_client_configured?
    end

    def config_tmp_disk
      if (tmp_disk = disk_from_string(options[:tmpdisk]))
        say "creating temp disk"
        config = ApplianceConsole::TempStorageConfiguration.new(:disk => tmp_disk)
        config.activate
      else
        report_disk_error(options[:tmpdisk])
      end
    end

    def config_log_disk
      if (log_disk = disk_from_string(options[:logdisk]))
        say "creating log disk"
        config = ApplianceConsole::LogfileConfiguration.new(:disk => log_disk)
        config.activate
      else
        report_disk_error(options[:logdisk])
      end
    end

    def report_disk_error(missing_disk)
      choose_disk = disk.try(:path)
      if choose_disk
        say "could not find disk #{missing_disk}"
        say "if you pass auto, it will choose: #{choose_disk}"
      else
        say "no disks with a free partition"
      end
    end

    def extauth_opts
      extauthopts = ExternalAuthOptions.new
      extauthopts_hash = extauthopts.parse(options[:extauth_opts])
      raise "Must specify at least one external authentication option to set" unless extauthopts_hash.present?
      extauthopts.update_configuration(extauthopts_hash)
    end

    def set_server_state
      service = LinuxAdmin::Service.new("evmserverd")
      service_running = service.running?
      case options[:server]
      when "start"
        service.start unless service_running
      when "stop"
        service.stop if service_running
      when "restart"
        service.restart
      else
        raise "Invalid server action"
      end
    end

    def config_db_hourly_maintenance
      hourly = ApplianceConsole::DatabaseMaintenanceHourly.new
      hourly.requested_activate = true
      hourly.activate
    end

    def self.parse(args)
      new.parse(args).run
    end
  end
end
