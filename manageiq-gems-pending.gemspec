# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'manageiq/gems/pending/version'

Gem::Specification.new do |s|
  s.name          = "manageiq-gems-pending"
  s.version       = ManageIQ::Gems::Pending::VERSION
  s.authors       = ["ManageIQ Developers"]

  s.summary       = "Core utility classes for ManageIQ."
  s.description   = "Classes pending extraction to their own gems."
  s.homepage      = "https://github.com/ManageIQ/manageiq-gems-pending/"
  s.license       = "Apache-2.0"
  s.metadata      = {
    "homepage_uri"          => s.homepage,
    "source_code_uri"       => "https://github.com/ManageIQ/manageiq-gems-pending",
    "changelog_uri"         => "https://github.com/ManageIQ/manageiq-gems-pending/blob/master/CHANGELOG.md",
    "rubygems_mfa_required" => "true"
  }

  s.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  s.bindir        = "exe"
  s.executables   = s.files.grep(%r{^exe/}) { |f| File.basename(f) }
  s.require_paths = ["lib", "lib/gems/pending", "lib/gems/pending/util"]

  s.required_ruby_version = "> 2.4"

  s.add_runtime_dependency "activesupport",           ">=6.0"
  s.add_runtime_dependency "awesome_spawn",           "~> 1.5"
  s.add_runtime_dependency "aws-sdk-s3",              "~> 1.0"
  s.add_runtime_dependency "bundler",                 "~> 2.1", ">= 2.1.4", "!= 2.2.10"
  s.add_runtime_dependency "fog-openstack",           "~> 1.0"
  s.add_runtime_dependency "more_core_extensions",    "~> 4.5"
  s.add_runtime_dependency "net-ftp",                 "~> 0.1.2"
  s.add_runtime_dependency "nokogiri",                "~> 1.14", ">= 1.14.3"
  s.add_runtime_dependency "rexml",                   ">= 3.3.6"
  s.add_runtime_dependency "sys-proctable",           "~> 1.2.5"
  s.add_runtime_dependency "sys-uname",               "~> 1.2.1"
  s.add_runtime_dependency "win32ole",                "~> 1.8.8" # this gem was extracted in ruby 3 - required if we use wmi on windows
  s.add_runtime_dependency "zeitwerk",                "~> 2.6", ">= 2.6.8"

  s.add_development_dependency "ftpd",                      "~> 2.1.0"
  s.add_development_dependency "manageiq-style",            ">= 1.5.4"

  s.add_development_dependency "rack",                      "~> 3.1.16" # this ensures manageiq-style's rack requirement is safe
  s.add_development_dependency "rake",                      ">= 12.3.3"
  s.add_development_dependency "rspec",                     "~> 3.13"
  s.add_development_dependency "simplecov",                 ">= 0.21.2"
  s.add_development_dependency "timecop",                   "~> 0.9.1"
  s.add_development_dependency "xml-simple",                "~> 1.1.0"
end
