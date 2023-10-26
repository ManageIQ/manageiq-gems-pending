require 'sys-uname'

class WMIHelper
  WMI_ROOT_NAMESPACE = "root\\cimv2" unless defined?(WMI_ROOT_NAMESPACE)

  platform = Sys::Platform::IMPL
  case platform
  when :linux
    include WmiLinux
  when :mswin
    include WmiMswin
  end

  def initialize(server = nil, username = nil, password = nil, namespace = WMI_ROOT_NAMESPACE)
    @server = server
    @username = username
    @password = password
    @namespace = namespace
  end

  def self.connectServer(server = nil, username = nil, password = nil, namespace = WMI_ROOT_NAMESPACE)
    wmi = WMIHelper.new(server, username, password, namespace)
    wmi.connectServer

    return wmi unless block_given?

    yield(wmi)
    wmi.release
  end

  def self.verify_credentials(server = nil, username = nil, password = nil, namespace = WMI_ROOT_NAMESPACE)
    wmi = nil
    wmi = WMIHelper.new(server, username, password, namespace)
    wmi.verify_credentials
  ensure
    wmi.release unless wmi.nil?
  end

  def collector(method, *args)
    items = []
    send(method, *args).each { |item| items << yield(item) }
    items
  end

  def collect(wmiQuery, &blk)
    collector(:run_query, wmiQuery, &blk)
  end

  def collect_associators(obj, assocClass = {}, &blk)
    collector(:associators_of, obj, assocClass, &blk)
  end

  def collect_references(obj, resultClass = {}, &blk)
    collector(:references_of, obj, resultClass, &blk)
  end

  def collect_objects(wmiQuery)
    collect(wmiQuery) { |o| o }
  end

  def collect_first(wmiQuery)
    collect(wmiQuery) { |o| o }.first
  end
end
