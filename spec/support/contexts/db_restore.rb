require 'more_core_extensions/core_ext/hash'

# Some config settings in the helper class are class methods instead of
# constants to allow them to be lazy loaded, instead of loaded right away,
# allowing the PostgresRunner to boot up `postgres` and set it's values if
# necessary.
class RestoreHelper
  SPEC_DIR      = File.expand_path(File.join("..", ".."), __dir__)
  LIB_DIR       = File.expand_path(File.join("..", "lib"), SPEC_DIR)
  PG_DUMPFILE   = File.join(SPEC_DIR, "util", "data", "pg_dump.gz")
  PG_BACKUPFILE = File.join(SPEC_DIR, "util", "data", "pg_backup.tar.gz")

  def self.pg_port
    @pg_port ||= defined?(PostgresRunner) ? PostgresRunner.port : nil
  end

  def self.default_restore_dump_opts
    @default_restore_dump_opts ||= {
      :local_file => PG_DUMPFILE,
      :username   => "root",
      :password   => "smartvm",
      :hostname   => "localhost",
      :port       => pg_port
    }.delete_blanks
  end

  def self.restore_backup_opts
    { :local_file => PG_BACKUPFILE }
  end
end

# Required that you define `db_name` yourself in your specs
shared_context "Database Restore Validation Helpers" do
  let(:connection_info) do
    {
      :host     => "localhost",
      :port     => RestoreHelper.pg_port,
      :user     => "root",
      :password => "smartvm",
      :dbname   => dbname
    }.delete_blanks
  end

  def author_count
    get_count("SELECT COUNT(id) FROM authors")
  end

  def book_count
    get_count("SELECT COUNT(id) FROM books")
  end

  def get_count(sql)
    conn = PG.connect(connection_info)
    conn.set_client_encoding("utf8")
    conn.exec(sql).getvalue(0, 0).to_i
  ensure
    conn.close if conn
  end

  def set_spec_env_for_postgres_admin_basebackup_restore
    if defined?(PostgresRunner)
      PostgresRunner.set_env # can be reset by other specs
      allow(PostgresAdmin).to receive(:user).and_return(PostgresRunner.user)
      allow(PostgresAdmin).to receive(:group).and_return(PostgresRunner.group)
      allow(LinuxAdmin::Service).to receive(:new).with(PostgresAdmin.service_name)
                                                 .and_return(PostgresRunner)
    elsif ENV["CI"]
      # Travis uses upstart for our current 'trusty' instance, so this will
      # just be stubbed like the above, so the sevice name is just something
      # that we can recognize.  See:
      #
      #   https://github.com/travis-ci/travis-build/blob/4f580b2/lib/travis/build/bash/travis_setup_postgresql.bash#L26-L27
      #   https://github.com/travis-ci/travis-cookbooks/blob/46a8e7fd/cookbooks/travis_postgresql/templates/ubuntu/9.5/postgresql.conf.erb#L41-L45
      #
      ENV["APPLIANCE_PG_DATA"]    = "/var/lib/postgresql/9.5/main"
      ENV["APPLIANCE_PG_SERVICE"] = "ci_pg_instance"

      allow(LinuxAdmin::Service).to receive(:new).with(PostgresAdmin.service_name)
                                                 .and_return(CiPostgresRunner)
    end
  end
end
