source "https://rubygems.org"

# Specify your gem's dependencies in manageiq-gems-pending.gemspec
gemspec

plugin "bundler-inject", "~> 1.1"
require File.join(Bundler::Plugin.index.load_paths("bundler-inject")[0], "bundler-inject") rescue nil

minimum_version =
  case ENV['TEST_RAILS_VERSION']
  when "7.2"
    "~>7.2.3"
  when "8.0"
    "~>8.0.5"
  else
    "~>8.0.5"
  end

gem "activesupport", minimum_version

# security fixes for indirect dependencies
gem "concurrent-ruby", ">=1.3.7"  # CVE-2026-54904 https://github.com/ruby-concurrency/concurrent-ruby/security/advisories/GHSA-h8w8-99g7-qmvj
gem "json",            ">=2.19.9" # CVE-2026-54696 https://github.com/ruby/json/security/advisories/GHSA-x2f5-4prf-w687
