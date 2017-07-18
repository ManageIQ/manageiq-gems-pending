require 'sync'

$miq_cache_with_timeout = {}
$miq_cache_with_timeout_lock = Sync.new

class Module
  def cache_with_timeout(method, timeout = nil, &block)
    raise "no block given" if block.nil?
    raise ArgumentError, "meth must be a Symbol" unless method.respond_to?(:to_sym)

    method             = method.to_sym
    clear_cache_method = "#{method}_clear_cache".to_sym
    cached_method      = "#{method}_cached?".to_sym
    key                = "#{name}.#{method}".to_sym

    $miq_cache_with_timeout_lock.synchronize(:EX) do
      $miq_cache_with_timeout[key] = {}
    end

    # Defining class methods is done by defining instance methods on the singleton class
    singleton_class = (class << self; self; end)

    singleton_class.send(:define_method, method) do |*args|
      force_reload = args.first
      return $miq_cache_with_timeout_lock.synchronize(:EX) do
        cache = $miq_cache_with_timeout[key]

        old_timeout = cache[:timeout]
        timeout_expired = !!old_timeout && (Time.now.utc > old_timeout)
        break cache[:value] if (!force_reload && !timeout_expired && cache.key?(:value))

        new_timeout = timeout || 300 # 5 minutes
        new_timeout = new_timeout.call if new_timeout.kind_of?(Proc)
        new_timeout = Time.now.utc + new_timeout
        new_value   = block.call
        cache.clear

        cache[:timeout] = new_timeout
        cache[:value]   = new_value
      end
    end

    singleton_class.send(:define_method, clear_cache_method) do |*_args|
      $miq_cache_with_timeout_lock.synchronize(:EX) do
        $miq_cache_with_timeout[key].clear
      end
    end

    singleton_class.send(:define_method, cached_method) do |*_args|
      $miq_cache_with_timeout_lock.synchronize(:EX) do
        !$miq_cache_with_timeout[key].empty?
      end
    end
  end

  def self.clear_all_cache_with_timeout
    $miq_cache_with_timeout_lock.synchronize(:EX) do
      $miq_cache_with_timeout.each_value(&:clear)
    end
  end
end
