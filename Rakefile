require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rake'
require 'rake/testtask'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = "--options #{File.expand_path(".rspec_ci", __dir__)}" if ENV['CI']
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
  Rake::Task["spec"].invoke
  Rake::Task["test"].invoke
end
