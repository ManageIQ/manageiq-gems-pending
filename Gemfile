source 'https://rubygems.org'

# Specify your gem's dependencies in manageiq-gems-pending.gemspec
gemspec

# Modified gems (forked on github)
gem "handsoap", "~>0.2.5", :require => false, :git => "https://github.com/ManageIQ/handsoap.git", :tag => "v0.2.5-5"

# This is needed because some of the smart analysis tests scripts, insde the 'lib/gems/pending/MiqVm/test' directory,
# use the oVirt provider inventory classes.
gem "manageiq-providers-ovirt", :require => false, :git => "https://github.com/ManageIQ/manageiq-providers-ovirt.git", :branch => "master"

group :test do
  gem "simplecov", :require => false
  gem "codeclimate-test-reporter", "~> 1.0.0", :require => false
end
