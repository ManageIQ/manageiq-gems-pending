require 'logger'
require 'active_support/core_ext/object/try'
require 'active_support/core_ext/numeric/bytes'
require 'active_support/core_ext/string'
require 'English'

class VMDBLogger < Logger
  MAX_LOG_LINE_LENGTH = 8.kilobytes

  def initialize(*args)
    super
    self.level = INFO

    # HACK: ActiveSupport monkey patches the standard Ruby Logger#initialize
    # method to set @formatter to a SimpleFormatter.
    #
    # The ActiveSupport Logger patches are deprecated in Rails 3.1.1 in favor of
    # ActiveSupport::BufferedLogger, so this hack may not be needed in future
    # version of Rails.
    self.formatter = Formatter.new

    # Allow for thread safe Logger level changes, similar to functionalities
    # provided by ActiveSupport::LoggerThreadSafeLevel
    @write_lock   = Mutex.new
    @local_levels = {}
  end

  # Silences the logger for the duration of the block.
  #
  # Taken from activesupport/logger_silence
  def silence(temporary_level = Logger::ERROR)
    old_local_level  = local_level
    self.local_level = temporary_level

    yield self
  ensure
    self.local_level = old_local_level
  end

  attr_reader :logdev # Expose logdev

  def logdev=(logdev)
    if @logdev
      shift_age  = @logdev.instance_variable_get(:@shift_age)
      shift_size = @logdev.instance_variable_get(:@shift_size)
      @logdev.close
    else
      shift_age  = 0
      shift_size = 1048576
    end

    @logdev = LogDevice.new(logdev, :shift_age => shift_age, :shift_size => shift_size)
  end

  def filename
    logdev.filename unless logdev.nil?
  end

  alias_method :filename=, :logdev=

  def self.contents(log, width = nil, last = 1000)
    return "" unless File.file?(log)

    if last.nil?
      contents = File.open(log, "rb", &:read).split("\n")
    else
      require 'util/miq-system'
      contents = MiqSystem.tail(log, last)
    end
    return "" if contents.nil? || contents.empty?

    results = []

    # Wrap lines at width if passed
    contents.each do |line|
      while !width.nil? && line.length > width
        # Don't return lines containing invalid UTF8 byte sequences - see vmdb_logger_test.rb
        results.push(line[0...width]) if (line[0...width].unpack("U*") rescue nil)
        line = line[width..line.length]
      end
      # Don't return lines containing invalid UTF8 byte sequences - see vmdb_logger_test.rb
      results.push(line) if line.length && (line.unpack("U*") rescue nil)
    end

    # Put back the utf-8 encoding which is the default for most rails libraries
    # after opening it as binary and getting rid of the invalid UTF8 byte sequences
    results.join("\n").force_encoding("utf-8")
  end

  def contents(width = nil, last = 1000)
    self.class.contents(filename, width, last)
  end

  def log_backtrace(err, level = :error)
    # Get the name of the method that called us unless it is a wrapped log_backtrace
    method_name = nil
    caller.each do |c|
      method_name = c[/`([^']*)'/, 1]
      break unless method_name == 'log_backtrace'
    end

    # Log the error text
    send(level, "[#{err.class.name}]: #{err.message}  Method:[#{method_name}]")

    # Log the stack trace except for some specific exceptions
    unless (Object.const_defined?(:MiqException) && err.kind_of?(MiqException::Error)) ||
           (Object.const_defined?(:MiqAeException) && err.kind_of?(MiqAeException::Error))
      send(level, err.backtrace.nil? || err.backtrace.empty? ? "Backtrace is not available" : err.backtrace.join("\n"))
    end
  end

  def self.log_hashes(logger, h, options = {})
    require 'yaml'
    require 'manageiq-password'

    level  = options[:log_level] || :info
    filter = Array(options[:filter]).flatten.compact.map(&:to_s) << "password"
    filter.uniq!

    values = YAML.dump(h.to_hash).gsub(ManageIQ::Password::REGEXP, "[FILTERED]")
    values = values.split("\n").map do |l|
      if (key = filter.detect { |f| l.include?(f) })
        l.gsub!(/#{key}.*: (.+)/) { |m| m.gsub!($1, "[FILTERED]") }
      end
      l
    end.join("\n")

    logger.send(level, "\n#{values}")
  end

  def log_hashes(h, options = {})
    self.class.log_hashes(self, h, options)
  end

  def level
    local_level || super
  end

  private

  def local_log_id
    Thread.current.object_id
  end

  def local_level
    @local_levels[local_log_id]
  end

  def local_level=(level)
    @write_lock.synchronize do
      if level
        @local_levels[local_log_id] = level
      else
        @local_levels.delete(local_log_id)
      end
    end
  end

  class Formatter < Logger::Formatter
    FORMAT = "[----] %s, [%s#%d:%x] %5s -- %s: %s\n"

    def call(severity, time, progname, msg)
      msg = prefix_task_id(msg2str(msg)).truncate(MAX_LOG_LINE_LENGTH)
      FORMAT % [severity[0..0], format_datetime(time), $PROCESS_ID, Thread.current.object_id, severity, progname, msg]
    end

    private

    def prefix_task_id(msg)
      $_miq_worker_current_msg ||= nil

      # Add task id to the message if a task is currently being worked on.
      if (task_id = (Thread.current["tracking_label"] || $_miq_worker_current_msg.try(:task_id)))
        prefix = "Q-task_id([#{task_id}])"
        msg = "#{prefix} #{msg}" unless msg.include?(prefix)
      end

      msg
    end
  end
end
