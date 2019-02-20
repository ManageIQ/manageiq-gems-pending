require "linux_admin"

require_relative 'support/mixins/pg_environment_updater'

class CiPostgresRunner
  PGVER       = "10".freeze
  PGDATADIR   = "/var/lib/postgresql/#{PGVER}/main".freeze
  PGCONFIGDIR = "/etc/postgresql/#{PGVER}/main".freeze

  def self.start
    # Make sure we have our postgresql.conf in the right spot on Travis
    system("cp #{PGDATADIR}/postgresql.conf #{PGCONFIGDIR}/postgresql.conf")

    # Move our configured `pg_hba.conf` to the config dir as well
    system("cp #{PGDATADIR}/pg_hba.conf #{PGCONFIGDIR}/pg_hba.conf")

    # Make sure directly in the postgresql.conf, the data_directory is set
    # (requirement for pg_wrapper I think...)
    system("echo \"data_directory = '#{PGDATADIR}'\" >> #{PGCONFIGDIR}/postgresql.conf")

    # Clear out the existing ramfs dir so it will be re-generated on boot
    system("sudo rm -rf /var/ramfs/postgresql/10")

    # Finally, restart the postgres service
    system("sudo systemctl start postgresql@10-main", :out => File::NULL)
  end

  def self.stop
    system("sudo systemctl stop postgresql", :out => File::NULL)
  end
end

# Override LinuxAdmin::Service.new to return CiPostgresRunner if the
# service_name is the configured postgresql service name
module LinuxAdmin
  def Service.new(service_name)
    if PostgresAdmin.service_name == service_name
      CiPostgresRunner
    else
      super
    end
  end
end

# Since we will be loading this file in a non-rspec context to get the
# overrides from above but with elevated root permissions, only include the
# RSpec.configure if `RSpec` is defined.
if defined?(RSpec)
  RSpec.configure do |config|
    config.add_setting :with_postgres_specs, :default => true

    config.before(:suite) do
      PgEnvironmentUpdater.create_root_role
      PgEnvironmentUpdater.create_stub_manageiq_configs_on_ci
    end
  end
end
