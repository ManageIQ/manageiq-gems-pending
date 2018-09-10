require 'util/mount/miq_generic_mount_session'
require 'excon'

class MiqSwiftSession < MiqGenericMountSession
  def initialize(log_settings)
    super(log_settings)
    raise "username and password are required values!" if @settings[:username].nil? || @settings[:password].nil?
    _scheme, _userinfo, @host, @port, _registry, @mount_path, _opaque, query, _fragment = URI.split(URI.encode(@settings[:uri]))
    query_params(query)
    @username      = @settings[:username]
    @password      = @settings[:password]
    @container_name = @mount_path[0] == File::Separator ? @mount_path[1..-1] : @mount_path
  end

  def self.raw_disconnect(mnt_point)
    return if mnt_point.nil?
    FileUtils.rm_rf(mnt_point) if File.exist?(mnt_point)
  end

  def uri_to_local_path(remote_file)
    # Strip off the leading "swift:/" from the URI"
    File.join(@mnt_point, URI(remote_file).host, URI(remote_file).path)
  end

  def uri_to_object_path(remote_file)
    # Strip off the leading "swift://" and the container name from the URI"
    # Also remove the leading delimiter.
    URI(remote_file).path[1..-1]
  end

  def add(local_file, uri)
    begin
      container = swift.directories.get(@container_name)
    rescue Fog::Storage::OpenStack::NotFound
      logger.debug("Swift container #{@container_name} does not exist.  Creating.")
      begin
        container = swift.directories.create(:key => @container_name)
      rescue => err
        disconnect
        logger.error("Error creating Swift container #{@container_name}. #{err}")
        msg = "Error creating Swift container #{@container_name}. #{err}"
        raise err, msg, err.backtrace
      end
    rescue => err
      disconnect
      logger.error("Error getting Swift container #{@container_name}. #{err}")
      msg = "Error getting Swift container #{@container_name}. #{err}"
      raise err, msg, err.backtrace
    end
    #
    # Get the remote path, and parse out the bucket name.
    #
    object_file_with_bucket = URI.split(URI.encode(uri))[5]
    object_file = object_file_with_bucket.split(File::Separator)[2..- 1].join(File::Separator)
    #
    # write dump file to swift
    #
    logger.debug("Writing [#{local_file}] to Bucket [#{@container_name}] using object file name [#{object_file}]")
    begin
      container.files.create(:key => object_file, :body => File.open(local_file))
    rescue Excon::Errors::Unauthorized => err
      disconnect
      logger.error("Access to Swift container #{@container_name} failed due to a bad username or password. #{err}")
      msg = "Access to Swift container #{@container_name} failed due to a bad username or password. #{err}"
      raise err, msg, err.backtrace
    rescue => err
      disconnect
      logger.error("Error uploading #{local_file} to Swift container #{@container_name}. #{err}")
      msg = "Error uploading #{local_file} to Swift container #{@container_name}. #{err}"
      raise err, msg, err.backtrace
    end
  end

  private

  def swift
    require 'manageiq/providers/openstack/legacy/openstack_handle'
    extra_options = {
      :ssl_ca_file    => ::Settings.ssl.ssl_ca_file,
      :ssl_ca_path    => ::Settings.ssl.ssl_ca_path,
      :ssl_cert_store => OpenSSL::X509::Store.new
    }
    extra_options[:domain_id] = @domain_id
    extra_options[:omit_default_port] = ::Settings.ems.ems_openstack.excon.omit_default_port
    extra_options[:read_timeout]      = ::Settings.ems.ems_openstack.excon.read_timeout
    extra_options[:service] = "Compute"

    @osh ||= OpenstackHandle::Handle.new(@username, @password, @host, @port, @api_version, @security_protocol, extra_options)
    @osh.connection_options = {:instrumentor => $fog_log}
    begin
      @swift ||= @osh.swift_service
    rescue Excon::Errors::Unauthorized => err
      disconnect
      logger.error("Access to Swift host #{@host} failed due to a bad username or password. #{err}")
      msg = "Access to Swift host #{@host} failed due to a bad username or password. #{err}"
      raise err, msg, err.backtrace
    rescue => err
      disconnect
      logger.error("Error connecting to Swift host #{@host}. #{err}")
      msg = "Error connecting to Swift host #{@host}. #{err}"
      raise err, msg, err.backtrace
    end
  end

  def query_params(query_string)
    query_string.split('&').each do |query|
      query_parts = query.split('=')
      case query_parts[0]
      when 'region'
        @region = query_parts[1]
      when 'api_version'
        @api_version = query_parts[1]
      when 'domain_id'
        @domain_id = query_parts[1]
      when 'security_protocol'
        @security_protocol = query_parts[1]
      end
    end
  end
end
