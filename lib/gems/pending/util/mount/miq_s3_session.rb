require 'util/mount/miq_generic_mount_session'
require 'aws-sdk'

class MiqS3Session < MiqGenericMountSession

  def initialize(log_settings)
    log_header = "MIQ(#{self.class.name}-initialize)"
    logger.debug("#{log_header} initialize: log_settings are #{log_settings}")
    super(log_settings)
    logger.debug("#{log_header} initialize: @settings are #{@settings}")
    raise "username is a required value!" if @settings[:username].nil?
    raise "password is a required value!" if @settings[:password].nil?
    raise "region is a required value!" if @settings[:region].nil?
    @s3 = s3
  end

  def s3
    @s3 ||= Aws::S3::Resource.new(region: @settings[:region], access_key_id: @settings[:username], secret_access_key: @settings[:password])
  end

  def connect
    _scheme, _userinfo, @host, _port, _registry, @mount_root, _opaque, _query, _fragment = URI.split(URI.encode(@settings[:uri]))
    @mount_path = @mount_root.split("/")[0..1].join("/")
    super
  end

  def disconnect
    return if @mnt_point.nil?
    FileUtils.rm_rf(@mnt_point) if File.exist?(@mnt_point)
  end

  def mount_root
    File.join(@mnt_point, (@mount_root.split("/") - @mount_path.split("/")))
  end

  def uri_to_local_path(remote_file)
    # Strip off the leading "s3:/" from the URI"
    log_header = "MIQ(#{self.class.name}-uri_to_local_path)"
    logger.debug("#{log_header} remote_file is [#{remote_file}]")
    file_part = remote_file.split(':')[1].split(/\//)[1..-1].join('/')
    File.join(@mnt_point, file_part)
  end

  def uri_to_object_path(remote_file)
    # Strip off the leading "s3://" and the bucket name from the URI"
    remote_file.split(':')[1].split(/\//)[3..-1].join('/')
  end

  def copy_dump_to_store(database_opts, connect_opts)
    begin
      # Strip off "s3://" prefix to get the bucket name.
      bucket_name = connect_opts[:uri].split(':')[1].split(/\//)[2]
      if (dump_bucket = s3.bucket(bucket_name)).exists?
        logger.debug("Found bucket #{bucket_name}")
      else
        logger.debug("Bucket #{bucket_name} does not exist, creating.")
        dump_bucket.create
      end
      # write dump file to s3
      logger.debug("Writing [#{database_opts[:local_file]}] to Bucket #{bucket_name}.")
      dump_bucket.object(database_opts[:object_file]).upload_file(database_opts[:local_file])
    rescue => err
      logger.error("Error copying dump from temporary location to S3 object store #{err}")
    end
  end
end
