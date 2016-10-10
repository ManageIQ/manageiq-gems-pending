$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "manageiq/gems/pending/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "manageiq-gems-pending"
  s.version     = ManageIQ::Gems::Pending::VERSION
  s.authors     = ["Brandon Dunne"]
  s.email       = ["bdunne@redhat.com"]
  s.homepage    = "https://github.com/ManageIQ/manageiq-gems-pending/"
  s.summary     = "Core utility classes for ManageIQ."
  s.description = "Classes pending extraction to their own gems."
  s.license     = "Apache"

  s.files = Dir["{lib}/**/*", "LICENSE.txt", "Rakefile", "README.md"]

  s.required_ruby_version = "> 2.2.2"

  s.add_development_dependency "camcorder"
  s.add_development_dependency "coveralls"
  s.add_development_dependency "rspec",        "~>3.5.0"
  s.add_development_dependency "test-unit"
  s.add_development_dependency "timecop",      "~>0.7.3"
  s.add_development_dependency "vcr",          "~>3.0.0"
  s.add_development_dependency "webmock",      "~>1.12"
  s.add_development_dependency "xml-simple",   "~>1.1.0"
end
