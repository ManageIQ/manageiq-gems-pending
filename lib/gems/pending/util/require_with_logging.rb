puts "** Loading Require With Logging"

$req_log_path ||= File.expand_path('.')
$req_log_file ||= ENV["REQUIRE_LOG"] unless ENV["REQUIRE_LOG"].nil? || ENV["REQUIRE_LOG"] == "true"
$req_log_file ||= "requires_#{Time.now.utc.strftime("%Y%m%d%H%M%S")}.log"

$req_log ||= File.open(File.join($req_log_path, $req_log_file), "w")
# $req_log = $stdout
$req_log.sync = true

$req_depth = 0

require 'sys-proctable'

module Kernel
  private

  REQ_LOG_OPERS = {
    :enter   => '> ',  # Enter require method
    :reenter => '>2',  # Reenter of require method that rubygems does when a
    # failure occurs and it determines it may need to search
    # the Gem paths
    :fail    => '<!',  # Failure
    true     => '<+',  # Successfully required
    false    => '<-'   # Already required
  }
  REQ_LOG_TREE = "| "

  def require_with_metrics
    initial_memory = Sys::ProcTable.ps(:pid => Process.pid).rss
    initial_loaded = $LOADED_FEATURES.length

    result = yield

    memory_after = Sys::ProcTable.ps(:pid => Process.pid).rss
    loaded_after = $LOADED_FEATURES.length
    return result, (memory_after - initial_memory) / 1000, (loaded_after - initial_loaded)
  end

  def log_require(path, mode, timing = nil, memory_consumed = nil, features_loaded = nil)
    $req_depth -= 1 if mode == true || mode == false || mode == :fail
    $req_log.puts "#{$req_depth.to_s.rjust(3)}  #{REQ_LOG_OPERS[mode]}  #{REQ_LOG_TREE * $req_depth}#{path.inspect[1..-2]}#{timing.nil? ? '' : " (#{"%.6f seconds" % timing})"}#{memory_consumed.nil? ? '' : " (#{memory_consumed} KB)"}#{features_loaded.nil? ? '' : " (#{features_loaded} features loaded)"}"
    $req_depth += 1 if mode == :enter || mode == :reenter
  end

  def with_require_logging(path, mode = :enter)
    log_require(path, mode)
    t = Time.now
    begin
      ret, memory_consumed, features_loaded = require_with_metrics { yield }
    rescue Exception
      log_require(path, :fail, Time.now - t, memory_consumed, features_loaded) rescue nil
      raise
    end
    log_require(path, ret, Time.now - t, memory_consumed, features_loaded)
    ret
  end

  alias_method :rubygems_original_require, :require

  if Gem::VERSION >= '1.5.0'

    def require(path) # :doc:
      with_require_logging(path) { gem_original_require(path) }
    rescue LoadError => load_error
      if load_error.message.end_with?(path) && Gem.try_activate(path)
        return with_require_logging(path, :reenter) { gem_original_require(path) }
      end

      raise load_error
    end

  else

    def require(path) # :doc:
      with_require_logging(path) { gem_original_require(path) }
    rescue LoadError => load_error
      if load_error.message =~ /#{Regexp.escape path}\z/ &&
         spec = Gem.searcher.find(path)
        Gem.activate(spec.name, "= #{spec.version}")
        with_require_logging(path, :reenter) { gem_original_require(path) }
      else
        raise load_error
      end
    end

  end

  alias_method :original_load, :load

  def load(path, wrap = false) # :doc:
    with_require_logging(path) { original_load(path, wrap) }
  end

  public

  def benchmark_requires(name = "** BENCHMARK REQUIRES **")
    with_require_logging(name) { yield; true }
  end
end
