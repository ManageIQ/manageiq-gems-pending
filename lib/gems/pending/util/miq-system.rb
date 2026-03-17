require 'active_support/core_ext/object/blank'
require 'sys/filesystem'
require 'sys/memory'
require 'sys-uname'
require 'sys/proctable'

class MiqSystem
  # Returns the current process's CPU usage as a percentage, or nil if unavailable.
  #
  # Example:
  #   MiqSystem.cpu_usage #=> 3
  def self.cpu_usage
    stat = Sys::ProcTable.ps(:pid => Process.pid)
    return nil unless stat
    return (stat.pctcpu * 100).to_i if stat.respond_to?(:pctcpu) && stat.pctcpu

    nil
  end

  # Returns the number of logical processors on the system.
  #
  # Example:
  #   MiqSystem.num_cpus #=> 8
  def self.num_cpus
    require 'etc'
    @num_cpus ||= Etc.nprocessors
  end

  # Returns a hash of memory statistics for the system.
  #
  # Example:
  #   MiqSystem.memory
  #   #=> { MemTotal: 16777216, MemFree: 1234567, Buffers: 12345, Cached: 67890, SwapTotal: 2097152, SwapFree: 2097152 }
  def self.memory
    mem = Sys::Memory.memory
    {
      :MemTotal  => mem.total_bytes,
      :MemFree   => mem.free_bytes,
      :Buffers   => mem.buffer_bytes,
      :Cached    => mem.cached_bytes,
      :SwapTotal => mem.total_swap_bytes,
      :SwapFree  => mem.free_swap_bytes
    }.compact
  end

  # Returns the total system memory in bytes.
  #
  # Example:
  #   MiqSystem.total_memory #=> 16777216
  def self.total_memory
    @total_memory ||= memory[:MemTotal]
  end

  # Returns a hash with CPU and memory usage for the system.
  #
  # Example:
  #   MiqSystem.status
  #   #=> { cpu_usage: 3, memory: { MemTotal: 16777216, ... } }
  def self.status
    {
      :cpu_usage => cpu_usage,
      :memory    => memory
    }
  end

  # Returns an array of disk usage statistics for each mount point.
  #
  # Example:
  #   MiqSystem.disk_usage.first
  #   #=> { filesystem: "/dev/disk1s5s1", type: "apfs", total_bytes: 499963174912, ... }
  def self.disk_usage(file = nil)
    mounts = Sys::Filesystem.mounts
    stats = mounts.filter_map do |mount|
      stat = Sys::Filesystem.stat(mount.mount_point)
      {
        :filesystem          => mount.name,
        :type                => mount.mount_type,
        :total_bytes         => stat.bytes_total,
        :used_bytes          => stat.bytes_used,
        :available_bytes     => stat.bytes_available,
        :used_bytes_percent  => stat.bytes_total > 0 ? ((stat.bytes_used.to_f / stat.bytes_total) * 100).to_i : 0,
        :total_inodes        => stat.files_total,
        :used_inodes         => stat.files_used,
        :available_inodes    => stat.files_available,
        :used_inodes_percent => stat.files_total > 0 ? ((stat.files_used.to_f / stat.files_total) * 100).to_i : 0,
        :mount_point         => mount.mount_point
      }
    rescue
      nil
    end
    if file
      stats.select! { |s| s[:mount_point] == file || s[:filesystem] == file }
    end
    stats
  end

  # Returns the system architecture as a symbol.
  #
  # Example:
  #   MiqSystem.arch #=> :x86_64
  def self.arch
    arch = Sys::Platform::ARCH
    case Sys::Platform::OS
    when :unix
      if arch == :unknown
        p = Gem::Platform.local
        arch = p.cpu.to_sym
      end
    end
    arch
  end

  # Returns the last N lines from a file as an array of strings.
  #
  # Example:
  #   MiqSystem.tail("/var/log/system.log", 2) #=> ["...line1...", "...line2..."]
  def self.tail(filename, last)
    return nil unless File.file?(filename)

    lines = []
    File.open(filename) do |f|
      f.extend(File::Tail)
      f.backward(last)
      f.tail(last) { |line| lines << line }
    end
    lines
  rescue LoadError, StandardError
    File.readlines(filename).last(last)
  end

  # Returns an array of retryable IO error classes for non-blocking IO operations.
  #
  # Example:
  #   MiqSystem.retryable_io_errors #=> [IO::WaitReadable]
  def self.retryable_io_errors
    @retryable_io_errors ||= defined?(IO::WaitReadable) ? [IO::WaitReadable] : [Errno::EAGAIN, Errno::EINTR]
  end

  # Reads up to maxlen bytes from a file in a background thread.
  # Returns a Thread (caller can call #value to get the read data) or nil if the file does not exist.
  #
  # Example:
  #   t = MiqSystem.readfile_async("/etc/hosts", 10)
  #   t.value #=> "127.0.0.1"
  def self.readfile_async(filename, maxlen = 10000)
    return nil unless File.exist?(filename)

    Thread.new do
      data = nil
      File.open(filename, 'rb') do |f|
        data = f.read_nonblock(maxlen)
      rescue *retryable_io_errors
        f.wait_readable
        retry
      rescue EOFError
        # Not sure what the data variable contains
      end
      data
    end
  end

  # Opens the given URL in the default browser.
  #
  # Example:
  #   MiqSystem.open_browser("http://example.com") #=> nil
  def self.open_browser(url)
    require 'launchy'
    Launchy.open(url)
  rescue LoadError
    require 'shellwords'
    case Sys::Platform::IMPL
    when :macosx        then `open #{url.shellescape}`
    when :linux         then `xdg-open #{url.shellescape}`
    when :mingw, :mswin then `start "#{url.gsub('"', '""')}"`
    end
  end
end
