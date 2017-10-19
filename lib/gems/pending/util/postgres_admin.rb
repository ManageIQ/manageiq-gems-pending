require 'awesome_spawn'
require 'pathname'
require 'linux_admin'

RAILS_ROOT ||= Pathname.new(__dir__).join("../../../")

class PostgresAdmin
  def self.data_directory
    Pathname.new(ENV.fetch("APPLIANCE_PG_DATA"))
  end

  def self.mount_point
    Pathname.new(ENV.fetch("APPLIANCE_PG_MOUNT_POINT"))
  end

  def self.template_directory
    Pathname.new(ENV.fetch("APPLIANCE_TEMPLATE_DIRECTORY"))
  end

  def self.service_name
    ENV.fetch("APPLIANCE_PG_SERVICE")
  end

  def self.package_name
    ENV.fetch('APPLIANCE_PG_PACKAGE_NAME')
  end

  # Unprivileged user to run postgresql
  def self.user
    "postgres".freeze
  end

  def self.certificate_location
    RAILS_ROOT.join("certs")
  end

  def self.logical_volume_name
    "lv_pg".freeze
  end

  def self.volume_group_name
    "vg_data".freeze
  end

  def self.database_disk_filesystem
    "xfs".freeze
  end

  def self.initialized?
    !Dir[data_directory.join("*")].empty?
  end

  def self.service_running?
    LinuxAdmin::Service.new(service_name).running?
  end

  def self.local_server_in_recovery?
    data_directory.join("recovery.conf").exist?
  end

  def self.local_server_status
    if service_running?
      "running (#{local_server_in_recovery? ? "standby" : "primary"})"
    elsif initialized?
      "initialized and stopped"
    else
      "not initialized"
    end
  end

  def self.logical_volume_path
    Pathname.new("/dev").join(volume_group_name, logical_volume_name)
  end

  def self.database_size(opts)
    result = runcmd("psql", opts, :command => "SELECT pg_database_size('#{opts[:dbname]}');")
    result.match(/^\s+([0-9]+)\n/)[1].to_i
  end

  def self.prep_data_directory
    # initdb will fail if the database directory is not empty or not owned by the PostgresAdmin.user
    FileUtils.mkdir(PostgresAdmin.data_directory) unless Dir.exist?(PostgresAdmin.data_directory)
    FileUtils.chown_R(PostgresAdmin.user, PostgresAdmin.user, PostgresAdmin.data_directory)
    FileUtils.rm_rf(PostgresAdmin.data_directory.children.map(&:to_s))
  end

  def self.backup(opts)
    backup_pg_compress(opts)
  end

  def self.restore(opts)
    before_restore(opts)
    restore_pg_compress(opts)
  end

  def self.before_restore(opts)
    # Drop subscriptions, unload extension and ensure pglogical connections are closed before proceeding
    unload_pglogical_extension(opts)
  rescue AwesomeSpawn::CommandResultError
    $log.info("MIQ(#{name}.#{__method__}) Ignoring failure to remove pglogical before restore ...")
  end

  def self.unload_pglogical_extension(opts)
    runcmd("psql", opts, :command => <<-SQL)
      SELECT
        drop_subscription
      FROM
        pglogical.subscription subs,
        LATERAL pglogical.drop_subscription(subs.sub_name)
    SQL

    runcmd("psql", opts, :command => <<-SQL)
      DROP EXTENSION pglogical CASCADE
    SQL

    # Wait for pglogical manager connection to quiesce. Bail after 5 minutes
    60.times do
      output = runcmd("psql", opts, :command => <<-SQL)
        SELECT application_name
        FROM pg_stat_activity
        WHERE application_name LIKE 'pglogical manager%'
      SQL
      match = /^\((?<count>\d+) row/.match(output)
      count = match ? match[:count].to_i : 0
      break if count.zero?

      $log.info("MIQ(#{name}.#{__method__}) Waiting on #{count} pglogical connections to close...")
      sleep 5
    end
  end

  def self.backup_pg_compress(opts)
    # 3)
    # Use pg_dump's custom dump format.  If PostgreSQL was built on a system with
    # the zlib compression library installed, the custom dump format will compress
    # data as it writes it to the output file. This will produce dump file sizes
    # similar to using gzip, but it has the added advantage that tables can be restored
    # selectively. The following command dumps a database using the custom dump format:

    opts = opts.dup
    dbname = opts.delete(:dbname)
    runcmd("pg_dump", opts, :format => "c", :file => opts[:local_file], nil => dbname)
    opts[:local_file]
  end

  def self.recreate_db(opts)
    dbname = opts[:dbname]
    opts = opts.merge(:dbname => 'postgres')
    runcmd("psql", opts, :command => "DROP DATABASE IF EXISTS #{dbname}")
    runcmd("psql", opts,
           :command => "CREATE DATABASE #{dbname} WITH OWNER = #{opts[:username] || 'root'} ENCODING = 'UTF8'")
  end

  def self.restore_pg_compress(opts)
    # -1
    # --single-transaction: Execute the restore as a single transaction (that is, wrap the
    #   emitted commands in BEGIN/COMMIT). This ensures that either all the commands complete
    #   successfully, or no changes are applied. This option implies --exit-on-error.
    # -c
    # --clean
    #   Clean (drop) database objects before recreating them.
    # -C
    # --create
    #   Create the database before restoring into it. (When this option is used, the database
    #   named with -d is used only to issue the initial CREATE DATABASE command. All data
    #   is restored into the database name that appears in the archive.)
    # -e
    # --exit-on-error
    #   Exit if an error is encountered while sending SQL commands to the database. The default is to continue and to display a count of errors at the end of the restoration.
    # -O
    # --no-owner
    #   Do not output commands to set ownership of objects to match the original database.
    #   By default, pg_restore issues ALTER OWNER or SET SESSION AUTHORIZATION statements to
    #   set ownership of created schema elements. These statements will fail unless the initial
    #   connection to the database is made by a superuser (or the same user that owns all of the
    #   objects in the script). With -O, any user name can be used for the initial connection,
    #   and this user will own all the created objects.
    # -a
    # --data-only
    #   Restore only the data, not the schema (data definitions).
    # -U root -h localhost -p 5432

    # `psql -d #{opts[:dbname]} -c "DROP DATABASE #{opts[:dbname]}; CREATE DATABASE #{opts[:dbname]} WITH OWNER = root ENCODING = 'UTF8';"`

    # TODO: In order to restore, we need to drop the database if it exists, and recreate it it blank
    # An alternative is to use the -a option to only restore the data if there is not a migration/schema change
    recreate_db(opts)

    runcmd("pg_restore", opts, :verbose => nil, :exit_on_error => nil, nil => opts[:local_file])
    opts[:local_file]
  end

  GC_DEFAULTS = {
    :analyze  => false,
    :full     => false,
    :verbose  => false,
    :table    => nil,
    :dbname   => nil,
    :username => nil,
    :reindex  => false
  }

  GC_AGGRESSIVE_DEFAULTS = {
    :analyze  => true,
    :full     => true,
    :verbose  => false,
    :table    => nil,
    :dbname   => nil,
    :username => nil,
    :reindex  => true
  }

  def self.gc(options = {})
    options = (options[:aggressive] ? GC_AGGRESSIVE_DEFAULTS : GC_DEFAULTS).merge(options)

    result = vacuum(options)
    $log.info("MIQ(#{name}.#{__method__}) Output... #{result}") if result.to_s.length > 0

    if options[:reindex]
      result = reindex(options)
      $log.info("MIQ(#{name}.#{__method__}) Output... #{result}") if result.to_s.length > 0
    end
  end

  def self.vacuum(opts)
    # TODO: Add a real exception here
    raise "Vacuum requires database" unless opts[:dbname]

    args = {}
    args[:analyze] = nil if opts[:analyze]
    args[:full]    = nil if opts[:full]
    args[:verbose] = nil if opts[:verbose]
    args[:table]   = opts[:table] if opts[:table]
    runcmd("vacuumdb", opts, args)
  end

  def self.reindex(opts)
    args = {}
    args[:table] = opts[:table] if opts[:table]
    runcmd("reindexdb", opts, args)
  end

  def self.runcmd(cmd_str, opts, args)
    default_args            = {:no_password => nil}
    default_args[:dbname]   = opts[:dbname]   if opts[:dbname]
    default_args[:username] = opts[:username] if opts[:username]
    default_args[:host]     = opts[:hostname] if opts[:hostname]
    args = default_args.merge(args)

    runcmd_with_logging(cmd_str, opts, args)
  end

  def self.runcmd_with_logging(cmd_str, opts, params = {})
    $log.info("MIQ(#{name}.#{__method__}) Running command... #{AwesomeSpawn.build_command_line(cmd_str, params)}")
    AwesomeSpawn.run!(cmd_str, :params => params, :env => {
                        "PGUSER"     => opts[:username],
                        "PGPASSWORD" => opts[:password]}).output
  end
end
