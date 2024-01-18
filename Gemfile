source "https://rubygems.org"

# Specify your gem's dependencies in manageiq-gems-pending.gemspec
gemspec

plugin "bundler-inject", "~> 1.1"
require File.join(Bundler::Plugin.index.load_paths("bundler-inject")[0], "bundler-inject") rescue nil

minimum_version =
  case ENV['TEST_RAILS_VERSION']
  when "7.0"
    "~>7.0.8"
  else
    "~>6.1.4"
  end

gem "activesupport", minimum_version
