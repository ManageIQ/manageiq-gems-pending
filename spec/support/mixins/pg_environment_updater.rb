require 'pg'
require 'more_core_extensions/core_ext/hash'

# This is simply to allow the dumps to be restored properly for the default
# config that is usually in place on an appliance.
#
# Set up as a mixin so both CI and the local code can use this.  Lifted from
# manageiq-appliance_console's internal database configuration.
module PgEnvironmentUpdater
  def create_root_role
    with_connection do |conn|
      pass = conn.escape_string("smartvm")
      conn.exec("CREATE ROLE root WITH LOGIN CREATEDB SUPERUSER PASSWORD '#{pass}'")
    end
  end
  module_function :create_root_role

  def create_postgres_role
    with_connection do |conn|
      conn.exec("CREATE ROLE postgres")
    end
  end
  module_function :create_postgres_role

  # This is a CI only function that will create the manageiq postgres config
  # directory at /etc/manageiq/postgresql.conf.d.
  #
  # This is fine to do on CI as it is an ephemeral VM, so it isn't going to
  # mess with state at all of a persisted machine (like creating this on
  # someone's dev box would).
  #
  # This does not add in all of the configs that you would find on an
  # appliance, however, and just defines enough to get things working (so
  # basically just 'ssl = on').
  #
  # See PostgresRunner#fix_pg_conf for how we handle this locally.
  def create_stub_manageiq_configs_on_ci
    config_dir  = File.join("", "etc", "manageiq", "postgresql.conf.d")
    config_file = File.join(config_dir, "ci.conf")

    cmds = [
      "mkdir -p #{config_dir}",
      "chmod 755 #{config_dir}",
      "chown -R postgres:postgres #{config_dir}",
      "echo 'ssl = on' > #{config_file}"
    ].join("; ")

    system("sudo /bin/bash -c \"#{cmds}\"")
  end
  module_function :create_stub_manageiq_configs_on_ci

  def with_connection
    connection_config = {
      :port   => @port || nil,
      :user   => @user || "postgres",
      :dbname => "postgres"
    }.delete_nils

    conn = PG.connect(connection_config)
    yield conn
  ensure
    conn.close if conn
  end
  module_function :with_connection
end
