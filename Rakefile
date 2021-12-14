require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rake'
require 'rake/testtask'

RSpec::Core::RakeTask.new(:spec)
Rake::TestTask.new do |t|
  t.test_files = FileList['test/**/ts_*.rb']
end

task :default => [:spec, :test]
