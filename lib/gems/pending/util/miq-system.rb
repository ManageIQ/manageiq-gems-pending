require 'active_support/core_ext/object/blank'
require 'sys/filesystem'
require 'sys/memory'
require 'sys-uname'

class MiqSystem

  def self.cpu_usage
    # Use sys-proctable for cross-platform CPU usage if needed, or fallback to nil
    require 'sys/proctable'
    if Sys::Platform::IMPL == :linux || Sys::Platform::IMPL == :macosx
      # This is a simple average CPU usage (user+system) for the whole system
      stat = Sys::ProcTable.ps(Process.pid)
      return nil unless stat
      # This is not a perfect replacement, but gives process CPU usage
      stat.pctcpu ? (stat.pctcpu * 100).to_i : nil
    end
    nil
  end

  # Returns the number of logical processors on the system.
  #
  def self.num_cpus
    require 'etc'
    # cache it since it won't change during a process lifetime
    @num_cpus ||= Etc.nprocessors
  end

  def self.memory
    # Use sys-memory for cross-platform memory info
    mem = Sys::Memory.memory
    {
      MemTotal: mem.total_bytes,
      MemFree: mem.free_bytes,
      Buffers: mem.buffer_bytes,
      Cached: mem.cached_bytes,
      SwapTotal: mem.total_swap_bytes,
      SwapFree: mem.free_swap_bytes
    }.compact
  end

  def self.total_memory
    @total_memory ||= memory[:MemTotal]
  end

  def self.status
    # Not directly supported by sys-* gems, so return memory and cpu info
    {
      cpu_usage: cpu_usage,
      memory: memory
    }
  end

  def self.disk_usage(file = nil)
    # Use sys-filesystem for cross-platform disk usage
    require 'sys/filesystem'
    mounts = Sys::Filesystem.mounts
    stats = mounts.map do |mount|
      begin
        stat = Sys::Filesystem.stat(mount.mount_point)
        {
          filesystem: mount.name,
          type: mount.mount_type,
          total_bytes: stat.bytes_total,
          used_bytes: stat.bytes_used,
          available_bytes: stat.bytes_available,
          used_bytes_percent: stat.bytes_total > 0 ? ((stat.bytes_used.to_f / stat.bytes_total) * 100).to_i : 0,
          total_inodes: stat.files_total,
          used_inodes: stat.files_used,
          available_inodes: stat.files_available,
          used_inodes_percent: stat.files_total > 0 ? ((stat.files_used.to_f / stat.files_total) * 100).to_i : 0,
          mount_point: mount.mount_point
        }
      rescue StandardError
        nil
      end
    end.compact
    if file
      stats.select! { |s| s[:mount_point] == file || s[:filesystem] == file }
    end
    stats
  end

  def self.normalize_df_file_argument(file = nil)
    # No longer needed, kept for API compatibility
    file
  end

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

  def self.tail(filename, last)
    # Use Ruby IO for tail
    return nil unless File.file?(filename)
    lines = []
    File.open(filename) do |f|
      f.extend(File::Tail)
      f.backward(last)
      f.tail(last) { |line| lines << line }
    end
    lines
  rescue LoadError, StandardError
    # If file-tail gem is not available or error, fallback
    File.readlines(filename).last(last)
  end

  def self.retryable_io_errors
    @retryable_io_errors ||= defined?(IO::WaitReadable) ? [IO::WaitReadable] : [Errno::EAGAIN, Errno::EINTR]
  end

  def self.readfile_async(filename, maxlen = 10000)
    # Use Ruby IO for async read
    return nil unless File.exist?(filename)
    File.open(filename, 'r') { |f| f.read(maxlen) }
  end

  def self.open_browser(url)
    require 'launchy'
    Launchy.open(url)
  rescue LoadError
    # fallback to shell if Launchy not available
    require 'shellwords'
    case Sys::Platform::IMPL
    when :macosx        then `open #{url.shellescape}`
    when :linux         then `xdg-open #{url.shellescape}`
    when :mingw, :mswin then `start "#{url.gsub('"', '""')}"`
    end
  end
end

if __FILE__ == $0
  def number_to_human_size(size, precision = 1)
    size = Kernel.Float(size)
    case
    when size == (1024**0) then "1 Byte"
    when size < (1024**1) then "%d Bytes" % size
    when size < (1024**2) then "%.#{precision}f KB" % (size / (1024.0**1))
    when size < (1024**3) then "%.#{precision}f MB" % (size / (1024.0**2))
    when size < (1024**4) then "%.#{precision}f GB" % (size / (1024.0**3))
    else                      "%.#{precision}f TB" % (size / (1024.0**4))
    end.sub(".%0#{precision}d" % 0, '')    # .sub('.0', '')
  end

  result = MiqSystem.memory
  puts "Memory: #{result.inspect}"

  result = MiqSystem.disk_usage
  format_string = "%-12s %6s %12s %12s %12s %12s %12s %12s %12s %12s %12s"
  header = format(format_string,
                  "Filesystem",
                  "Type",
                  "Total",
                  "Used",
                  "Available",
                  "%Used",
                  "iTotal",
                  "iUsed",
                  "iFree",
                  "%iUsed",
                  "Mounted on")
  puts header

  result.each { |disk|
    formatted = format(format_string,
                       disk[:filesystem],
                       disk[:type],
                       number_to_human_size(disk[:total_bytes]),
                       number_to_human_size(disk[:used_bytes]),
                       number_to_human_size(disk[:available_bytes]),
                       "#{disk[:used_bytes_percent]}%",
                       disk[:total_inodes],
                       disk[:used_inodes],
                       disk[:available_inodes],
                       "#{disk[:used_inodes_percent]}%",
                       disk[:mount_point]
                      )
    puts formatted
  }

end
