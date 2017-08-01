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

  s.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  s.bindir        = "exe"
  s.executables   = s.files.grep(%r{^exe/}) { |f| File.basename(f) }
  s.require_paths = ["lib", "lib/gems/pending", "lib/gems/pending/util"]

  s.required_ruby_version = "> 2.2.2"

  s.add_runtime_dependency "actionpack",              ">= 5.0", "< 5.1"
  s.add_runtime_dependency "activerecord",            ">= 5.0", "< 5.1" # used by appliance_console
  s.add_runtime_dependency "activesupport",           ">= 5.0", "< 5.1"
  s.add_runtime_dependency "addressable",             "~> 2.4"
  s.add_runtime_dependency "awesome_spawn",           "~> 1.4"
  s.add_runtime_dependency "bcrypt",                  "~> 3.1.10"
  s.add_runtime_dependency "binary_struct",           "~> 2.1"
  s.add_runtime_dependency "bundler",                 ">= 1.8.4" # rails-assets requires bundler >= 1.8.4, see: https://rails-assets.org/
  s.add_runtime_dependency "highline",                "~> 1.6.21" # Needed for the appliance_console
  s.add_runtime_dependency "linux_admin",             "~> 0.20.2"
  s.add_runtime_dependency "log4r",                   "=  1.1.8"
  s.add_runtime_dependency "memoist",                 "~> 0.15.0"
  s.add_runtime_dependency "more_core_extensions",    "~> 3.3"
  s.add_runtime_dependency "net-scp",                 "~> 1.2.1"
  s.add_runtime_dependency "net-sftp",                "~> 2.1.2"
  s.add_runtime_dependency "nokogiri",                "~> 1.7.2"
  s.add_runtime_dependency "pg",                      "~> 0.18.2"
  s.add_runtime_dependency "pg-dsn_parser",           "~> 0.1.0"
  s.add_runtime_dependency "rake",                    ">= 11.0"
  s.add_runtime_dependency "sys-proctable",           "~> 1.1.3"
  s.add_runtime_dependency "sys-uname",               "~> 1.0.1"
  s.add_runtime_dependency "trollop",                 "~> 2.0"
  s.add_runtime_dependency "uuidtools",               "~> 2.1.3"
  s.add_runtime_dependency "winrm",                   "~> 2.1"
  s.add_runtime_dependency "winrm-elevated",          "~> 1.0.1"

  s.add_development_dependency "codeclimate-test-reporter", "~> 1.0.0"
  s.add_development_dependency "rspec",                     "~> 3.5.0"
  s.add_development_dependency "simplecov"
  s.add_development_dependency "test-unit"
  s.add_development_dependency "timecop",                   "~> 0.7.3"
  s.add_development_dependency "xml-simple",                "~> 1.1.0"
end
