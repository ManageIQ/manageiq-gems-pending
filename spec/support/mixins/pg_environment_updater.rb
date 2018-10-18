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
