require "etc"
require "tmpdir"
require "socket"
require "fileutils"
require "singleton"

require_relative 'support/mixins/pg_environment_updater'

# This class is in charge of booting additional instance of postgres that can
# be used for validating features of PostgresAdmin.
#
# It makes use of `pg_ctl` to init, start and stop the instance, in is built so
# that it can be used as a stub for LinuxAdmin as well.  While this is a
# singleton, this really should only booted at the beginning of the suite, and
# shutdown and cleaned up prior to exiting.
class PostgresRunner
  include Singleton
  include FileUtils
  include PgEnvironmentUpdater

  attr_accessor :db_dir, :port

  def self.start
    instance.start
  end

  def self.stop
    instance.stop
  end

  def self.running?
    instance.running?
  end

  def self.port
    instance.port
  end

  def self.set_env
    instance.set_env
  end

  def self.destroy
    instance.stop
    instance.clean
  end

  def self.user
    Etc.getlogin
  end

  def self.group
    Etc.getgrgid(Etc.getpwnam(Etc.getlogin).gid).name
  end

  def initialize
    initdb
    set_env
    set_port
    start
    create_root_role
    create_postgres_role
  end

  def start
    return if running?
    fix_pg_conf
    system("#{pg_ctl} start -D #{db_dir} -wo '-p #{port}'", :out => File::NULL)
  end

  def stop
    return unless running?
    system("#{pg_ctl} stop -D #{db_dir} -wm fast", :out => File::NULL)
  end

  def clean
    remove_entry(db_dir)
  end

  def running?
    return false unless db_dir
    # avoiding a shellout by just checking the existance of the pg_ctl pid file
    #
    # see `man pg_ctl` in the FILES section for the description of this file
    File.exist?(pid_file)
  end

  def set_env
    @user = self.class.user # used by PgEnvironmentUpdater
    ENV["APPLIANCE_PG_DATA"]    = db_dir
    ENV["APPLIANCE_PG_SERVICE"] = "local_pg_instance"
  end

  private

  def set_port
    @port = TCPServer.open("127.0.0.1", 0) { |sock| sock.addr[1] }
  end

  def pid_file
    File.join(db_dir, "postmaster.pid")
  end

  def initdb
    dirname = Dir::Tmpname.make_tmpname("postgres_admin", "data")
    @db_dir = File.expand_path(dirname, __dir__)

    system("#{pg_ctl} init -D #{db_dir} -o '-A trust'", :out => File::NULL)
  end

  # TODO:  NickLaMuro: Maybe just don't get a backup from the appliance?
  #
  # Unsure if it is better to have a slightly "different from prod" backup, or
  # to fix this backup so it works locally with the appliance config.
  def fix_pg_conf
    conf_file = File.join(db_dir, 'postgresql.conf')
    conf      = File.read conf_file
    conf.gsub!("include_dir = '/etc/manageiq/postgresql.conf.d'", "ssl = on")
    File.write(conf_file, conf)
  end

  # Form of `which` from https://stackoverflow.com/a/5471032
  def pg_ctl
    @pg_ctl ||= begin
                  exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
                  ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
                    exts.each do |ext|
                      exe = File.join(path, "pg_ctl#{ext}")
                      return exe if File.executable?(exe) && !File.directory?(exe)
                    end
                  end
                  raise "No `pg_ctl` executable found!"
                end
  end
end

RSpec.configure do |config|
  config.add_setting :with_postgres_specs, :default => true

  config.before(:suite) { PostgresRunner.start   }
  config.after(:suite)  { PostgresRunner.destroy }
end
