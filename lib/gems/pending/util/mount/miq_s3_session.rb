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
    @s3 ||= Aws::S3::Resource.new(:region => @settings[:region], :access_key_id => @settings[:username], :secret_access_key => @settings[:password])
  end

  def connect
    @host       = URI(uri).host
    @mount_path = URI(uri).path
    super
  end

  def disconnect
    return if @mnt_point.nil?
    FileUtils.rm_rf(@mnt_point) if File.exist?(@mnt_point)
  end

  def uri_to_local_path(remote_file)
    # Strip off the leading "s3:/" from the URI"
    File.join(@mnt_point, URI(remote_file).host, URI(remote_file).path)
  end

  def uri_to_object_path(remote_file)
    # Strip off the leading "s3://" and the bucket name from the URI"
    # Also remove the leading delimiter.
    URI(remote_file).path[1..-1]
  end

  def add(local_file, uri, object_file)
    bucket_name = URI(uri).host
    if (dump_bucket = s3.bucket(bucket_name)).exists?
      logger.debug("Found bucket #{bucket_name}")
    else
      logger.debug("Bucket #{bucket_name} does not exist, creating.")
      dump_bucket.create
    end
    # write dump file to s3
    logger.debug("Writing [#{local_file}] to Bucket [#{bucket_name}] using object file name [#{object_file}]")
    begin
      dump_bucket.object(object_file).upload_file(local_file)
    rescue Aws::S3::Errors::AccessDenied => err
      disconnect
      logger.error("Access to S3 bucket #{bucket_name} restricted.  Try a different name. #{err}")
      msg = "Access to S3 bucket #{bucket_name} restricted.  Try a different name. #{err}"
      raise err, msg, err.backtrace
    rescue => err
      disconnect
      logger.error("Error uploading #{local_file} to S3 bucket #{bucket_name}. #{err}")
      msg = "Error uploading #{local_file} to S3 bucket #{bucket_name}. #{err}"
      raise err, msg, err.backtrace
    end
  end
end
