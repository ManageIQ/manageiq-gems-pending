require 'awesome_spawn'
require 'pathname'
require 'linux_admin'

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

  def self.group
    user
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
    FileUtils.chown_R(PostgresAdmin.user, PostgresAdmin.group, PostgresAdmin.data_directory)
    FileUtils.rm_rf(PostgresAdmin.data_directory.children.map(&:to_s))
  end

  PG_DUMP_MAGIC = "PGDMP".force_encoding(Encoding::BINARY).freeze
  def self.pg_dump_file?(file)
    File.open(file, "rb") { |f| f.readpartial(5) } == PG_DUMP_MAGIC
  end

  BASE_BACKUP_MAGIC = "\037\213".force_encoding(Encoding::BINARY).freeze # just the first 2 bits of gzip magic
  def self.base_backup_file?(file)
    File.open(file, "rb") { |f| f.readpartial(2) } == BASE_BACKUP_MAGIC
  end

  def self.backup(opts)
    backup_pg_compress(opts)
  end

  def self.restore(opts)
    file        = opts[:local_file]
    backup_type = opts.delete(:backup_type)

    case
    when backup_type == :pgdump     then restore_pg_dump(opts)
    when backup_type == :basebackup then restore_pg_basebackup(file)
    when pg_dump_file?(file)        then restore_pg_dump(opts)
    when base_backup_file?(file)    then restore_pg_basebackup(file)
    else
      raise "#{file} is not a database backup"
    end
  end

  def self.restore_pg_basebackup(file)
    pg_service = LinuxAdmin::Service.new(service_name)

    pg_service.stop
    prep_data_directory

    require 'zlib'
    require 'archive/tar/minitar'

    tgz = Zlib::GzipReader.new(File.open(file, 'rb'))
    Archive::Tar::Minitar.unpack(tgz, data_directory.to_s)
    FileUtils.chown_R(PostgresAdmin.user, PostgresAdmin.group, PostgresAdmin.data_directory)

    pg_service.start
    file
  end

  def self.backup_pg_dump(opts)
    opts = opts.dup
    dbname = opts.delete(:dbname)

    args = combine_command_args(opts, :format => "c", :file => opts[:local_file], nil => dbname)
    args = handle_multi_value_pg_dump_args!(opts, args)

    runcmd_with_logging("pg_dump", opts, args)
    opts[:local_file]
  end

  def self.backup_pg_compress(opts)
    opts = opts.dup

    # discard dbname as pg_basebackup does not connect to a specific database
    opts.delete(:dbname)

    path = Pathname.new(opts.delete(:local_file))
    FileUtils.mkdir_p(path.dirname)

    # Build commandline from AwesomeSpawn
    args = {:z => nil, :format => "t", :xlog_method => "fetch", :pgdata => "-"}
    cmd  = AwesomeSpawn.build_command_line("pg_basebackup", combine_command_args(opts, args))
    $log.info("MIQ(#{name}.#{__method__}) Running command... #{cmd}")

    # Run command in a separate thread
    read, write    = IO.pipe
    error_path     = Dir::Tmpname.create("") { |tmpname| tmpname }
    process_thread = Process.detach(Kernel.spawn(pg_env(opts), cmd, :out => write, :err => error_path))
    stream_reader  = Thread.new { IO.copy_stream(read, path) } # Copy output to path
    write.close

    # Wait for them to finish
    process_status = process_thread.value
    stream_reader.join
    read.close

    handle_error(cmd, process_status.exitstatus, error_path)
    path.to_s
  end

  def self.recreate_db(opts)
    dbname = opts[:dbname]
    opts = opts.merge(:dbname => 'postgres')
    runcmd("psql", opts, :command => "DROP DATABASE IF EXISTS #{dbname}")
    runcmd("psql", opts,
           :command => "CREATE DATABASE #{dbname} WITH OWNER = #{opts[:username] || 'root'} ENCODING = 'UTF8'")
  end

  def self.restore_pg_dump(opts)
    recreate_db(opts)
    args = { :verbose => nil, :exit_on_error => nil }

    if File.pipe?(opts[:local_file])
      cmd_args   = combine_command_args(opts, args)
      cmd        = AwesomeSpawn.build_command_line("pg_restore", cmd_args)
      error_path = Dir::Tmpname.create("") { |tmpname| tmpname }
      spawn_args = { :err => error_path, :in => [opts[:local_file].to_s, "rb"] }

      $log.info("MIQ(#{name}.#{__method__}) Running command... #{cmd}")
      process_thread = Process.detach(Kernel.spawn(pg_env(opts), cmd, spawn_args))
      process_status = process_thread.value

      handle_error(cmd, process_status.exitstatus, error_path)
    else
      args[nil] = opts[:local_file]
      runcmd("pg_restore", opts, args)
    end
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
    runcmd_with_logging(cmd_str, opts, combine_command_args(opts, args))
  end

  def self.runcmd_with_logging(cmd_str, opts, params = {})
    $log.info("MIQ(#{name}.#{__method__}) Running command... #{AwesomeSpawn.build_command_line(cmd_str, params)}")
    AwesomeSpawn.run!(cmd_str, :params => params, :env => pg_env(opts)).output
  end

  private_class_method def self.combine_command_args(opts, args)
    default_args            = {:no_password => nil}
    default_args[:dbname]   = opts[:dbname]   if opts[:dbname]
    default_args[:username] = opts[:username] if opts[:username]
    default_args[:host]     = opts[:hostname] if opts[:hostname]
    default_args[:port]     = opts[:port]     if opts[:port]
    default_args.merge(args)
  end

  private_class_method def self.pg_env(opts)
    {
      "PGUSER"     => opts[:username],
      "PGPASSWORD" => opts[:password]
    }.delete_blanks
  end
  # rubocop:disable Style/SymbolArray
  PG_DUMP_MULTI_VALUE_ARGS = [
    :t, :table,  :T, :exclude_table,  :"exclude-table", :exclude_table_data, :"exclude-table-data",
    :n, :schema, :N, :exclude_schema, :"exclude-schema"
  ].freeze
  # rubocop:enable Style/SymbolArray
  #
  # NOTE:  Potentially mutates opts hash (args becomes new array and not
  # mutated by this method)
  private_class_method def self.handle_multi_value_pg_dump_args!(opts, args)
    if opts.keys.any? { |key| PG_DUMP_MULTI_VALUE_ARGS.include?(key) }
      args = args.to_a
      PG_DUMP_MULTI_VALUE_ARGS.each do |table_key|
        next unless opts.key?(table_key)
        table_val = opts.delete(table_key)
        args += Array.wrap(table_val).map! { |v| [table_key, v] }
      end
    end
    args
  end

  private_class_method def self.handle_error(cmd, exit_status, error_path)
    if exit_status != 0
      result = AwesomeSpawn::CommandResult.new(cmd, "", File.read(error_path), exit_status)
      message = AwesomeSpawn::CommandResultError.default_message(cmd, exit_status)
      $log.error("AwesomeSpawn: #{message}")
      $log.error("AwesomeSpawn: #{result.error}")
      raise AwesomeSpawn::CommandResultError.new(message, result)
    end
  ensure
    File.delete(error_path) if File.exist?(error_path)
  end
end
