source "https://rubygems.org"

# Specify your gem's dependencies in manageiq-gems-pending.gemspec
gemspec

plugin "bundler-inject", "~> 1.1"
require File.join(Bundler::Plugin.index.load_paths("bundler-inject")[0], "bundler-inject") rescue nil

gem "handsoap", "=0.2.5.5", :require => false, :source => "http://rubygems.manageiq.org"
