source "https://rubygems.org"

# Specify your gem's dependencies in manageiq-gems-pending.gemspec
gemspec

plugin "bundler-inject", "~> 1.1"
require File.join(Bundler::Plugin.index.load_paths("bundler-inject")[0], "bundler-inject") rescue nil

minimum_version =
  case ENV['TEST_RAILS_VERSION']
  when "7.0"
    "~>7.0.8"
  when "7.1"
    "~>7.1.4"
  when "7.2"
    "~>7.2.1"
  end

gem "activesupport", minimum_version
