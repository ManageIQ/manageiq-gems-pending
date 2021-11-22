require "simplecov"
SimpleCov.start { command_name "spec" }

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'manageiq-gems-pending'

# Initialize the global logger that might be expected
require 'logger'
$log ||= Logger.new("/dev/null")
# $log ||= Logger.new(STDOUT)
# $log.level = Logger::DEBUG

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir[File.expand_path(File.join(__dir__, 'support/**/*.rb'))].each { |f| require f }

# A bunch of tests rely on ActiveSupport helper methods
require 'active_support/all'

RSpec.configure do |config|
  config.after(:each) do
    Module.clear_all_cache_with_timeout if Module.respond_to?(:clear_all_cache_with_timeout)
  end

  if ENV["CI"]
    config.after(:suite) do
      require_relative "coverage_helper"
    end
  end

  config.backtrace_exclusion_patterns -= [%r{/lib\d*/ruby/}, %r{/gems/}]
  config.backtrace_exclusion_patterns << %r{/lib\d*/ruby/[0-9]}
  config.backtrace_exclusion_patterns << %r{/gems/[0-9][^/]+/gems/}
end
