require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rake'
require 'rake/testtask'

desc "Run RSpec code examples (skip postgres required ones)"
RSpec::Core::RakeTask.new(:spec)

# In CI, as part of the .rspec_ci, load a helper that sets the configuration
# setting to allow the postgres specs to run.
desc "Run RSpec code examples (assumes ci dependencies)"
RSpec::Core::RakeTask.new("spec:ci") do |t|
  t.rspec_opts = "--options #{File.expand_path(".rspec_ci", __dir__)}"
end

desc "Run RSpec code examples (with local postgres dependencies)"
RSpec::Core::RakeTask.new("spec:dev") do |t|
  # Load the PostgresRunner helper to facilitate a clean postgres environment
  # for testing locally (not necessary for CI), and enables the postgres test
  # via the helper.
  pg_runner = File.join("spec", "postgres_runner_helper.rb")
  t.rspec_opts = "-r #{File.expand_path(pg_runner, __dir__)}"
end

task :default do
  Rake::Task["spec#{':ci' if ENV['CI']}"].invoke
  Rake::Task["test"].invoke
end
