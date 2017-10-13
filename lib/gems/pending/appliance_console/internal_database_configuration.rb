require "appliance_console/database_configuration"
require "appliance_console/logical_volume_management"
require "pathname"
require "util/postgres_admin"
require "pg"
require "linux_admin"

RAILS_ROOT ||= Pathname.new(__dir__).join("../../../")

module ApplianceConsole
  class InternalDatabaseConfiguration < DatabaseConfiguration
    attr_accessor :disk, :ssl, :run_as_evm_server

    DEDICATED_DB_SHARED_BUFFERS = "'1GB'".freeze
    SHARED_DB_SHARED_BUFFERS = "'128MB'".freeze

    def self.postgres_dir
      PostgresAdmin.data_directory.relative_path_from(Pathname.new("/"))
    end

    def self.postgresql_template
      PostgresAdmin.template_directory.join(postgres_dir)
    end

    def initialize(hash = {})
      set_defaults
      super
    end

    def set_defaults
      self.host              = 'localhost'
      self.username          = "root"
      self.database          = "vmdb_production"
      self.run_as_evm_server = true
    end

    def activate
      if PostgresAdmin.initialized?
        say(<<-EOF.gsub!(/^\s+/, ""))
          An internal database already exists.
          Choose "Reset Configured Database" to reset the existing installation
          EOF
        return false
      end
      initialize_postgresql_disk if disk
      initialize_postgresql
      return super if run_as_evm_server
      true
    end

    def ask_questions
      choose_disk
      check_disk_is_mount_point
      self.run_as_evm_server = !ask_yn?(<<-EOS.gsub!(/^ +/m, ""), "N")

        Should this appliance run as a standalone database server?

        NOTE:
        * The #{I18n.t("product.name")} application will not be running.
        * This is required when using highly available database deployments.
        * CAUTION: This is not reversible.

      EOS
      # TODO: Assume we want to create a region for a new internal database disk
      # until we allow for the internal selection against an already initialized disk.
      create_new_region_questions(false) if run_as_evm_server
      ask_for_database_credentials
    end

    def choose_disk
      @disk = ask_for_disk("database disk", true, false)
    end

    def check_disk_is_mount_point
      error_message = "The disk for database must be a mount point"
      raise error_message unless disk || pg_mount_point?
    end

    def initialize_postgresql_disk
      log_and_feedback(__method__) do
        LogicalVolumeManagement.new(:disk                => disk,
                                    :mount_point         => mount_point,
                                    :name                => "pg",
                                    :volume_group_name   => PostgresAdmin.volume_group_name,
                                    :filesystem_type     => PostgresAdmin.database_disk_filesystem,
                                    :logical_volume_path => PostgresAdmin.logical_volume_path).setup
      end
    end

    def initialize_postgresql
      log_and_feedback(__method__) do
        PostgresAdmin.prep_data_directory
        run_initdb
        relabel_postgresql_dir
        configure_postgres
        start_postgres
        create_postgres_root_user
        create_postgres_database
        apply_initial_configuration
      end
    end

    def configure_postgres
      self.ssl = File.exist?(PostgresAdmin.certificate_location.join("postgres.key"))

      copy_template "postgresql.conf"
      copy_template "pg_hba.conf.erb"
      copy_template "pg_ident.conf"
    end

    def post_activation
      start_evm if run_as_evm_server
    end

    private

    def mount_point
      PostgresAdmin.mount_point
    end

    def copy_template(src, src_dir = self.class.postgresql_template, dest_dir = PostgresAdmin.data_directory)
      full_src = src_dir.join(src)
      if src.include?(".erb")
        full_dest = dest_dir.join(src.gsub(".erb", ""))
        File.open(full_dest, "w") { |f| f.puts ERB.new(File.read(full_src), nil, '-').result(binding) }
      else
        FileUtils.cp full_src, dest_dir
      end
    end

    def pg_mount_point?
      LinuxAdmin::LogicalVolume.mount_point_exists?(mount_point)
    end

    def run_initdb
      AwesomeSpawn.run!("service", :params => {nil => [PostgresAdmin.service_name, "initdb"]})
    end

    def start_postgres
      LinuxAdmin::Service.new(PostgresAdmin.service_name).enable.start
      block_until_postgres_accepts_connections
    end

    def restart_postgres
      LinuxAdmin::Service.new(PostgresAdmin.service_name).restart
      block_until_postgres_accepts_connections
    end

    def block_until_postgres_accepts_connections
      loop do
        break if AwesomeSpawn.run("psql -U postgres -c 'select 1'").success?
      end
    end

    def create_postgres_root_user
      with_pg_connection do |conn|
        esc_pass = conn.escape_string(password)
        conn.exec("CREATE ROLE #{username} WITH LOGIN CREATEDB SUPERUSER PASSWORD '#{esc_pass}'")
      end
    end

    def create_postgres_database
      with_pg_connection do |conn|
        conn.exec("CREATE DATABASE #{database} OWNER #{username} ENCODING 'utf8'")
      end
    end

    def relabel_postgresql_dir
      AwesomeSpawn.run!("/sbin/restorecon -R -v #{mount_point}")
    end

    def with_pg_connection
      conn = PG.connect(:user => "postgres", :dbname => "postgres")
      yield conn
    ensure
      conn.close
    end

    def apply_initial_configuration
      shared_buffers = run_as_evm_server ? SHARED_DB_SHARED_BUFFERS : DEDICATED_DB_SHARED_BUFFERS
      with_pg_connection do |conn|
        conn.exec("ALTER SYSTEM SET ssl TO on") if ssl
        conn.exec("ALTER SYSTEM SET shared_buffers TO #{shared_buffers}")
      end

      restart_postgres
    end
  end
end
