require_relative './test_helper'

# Setup console logging
require 'logger'
$log = Logger.new(STDOUT)
$log.level = Logger::WARN

require_relative 'xml/tc_xml'
require_relative 'xml/tc_rexml'
require_relative 'xml/tc_nokogiri'
require_relative 'xml/tc_xmlhash_methods.rb'
require_relative 'xml/tc_encoding.rb'
