begin
  require 'rspec/core'
  require 'rspec/core/rake_task'
rescue LoadError
else
  desc "Run all specs in spec directory"
  RSpec::Core::RakeTask.new do |t|
    # from: vmdb's EvmTestHelper.init_rspec_task
    rspec_opts = ['--options', "\"#{ManageIQ::Gems::Pending.root.join(".rspec_ci")}\""] + (rspec_opts || []) if ENV['CI']
    t.rspec_opts = rspec_opts
    t.verbose = false
    t.pattern = './spec{,/*/**}/*_spec.rb'
  end
end

require 'rake'
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.test_files = FileList['test/ts_*.rb'] - ['test/ts_mdfs.rb', 'test/ts_metadata.rb']
end

namespace :test do
  Rake::TestTask.new(:extract)  { |t| t.test_files = ['test/ts_extract.rb'] }
  Rake::TestTask.new(:metadata) { |t| t.test_files = ['test/ts_metadata.rb'] }
  Rake::TestTask.new(:miq_disk) { |t| t.test_files = ['test/ts_mdfs.rb'] }
end

task :default do
  Rake::Task["spec"].invoke
  Rake::Task["test"].invoke
end
