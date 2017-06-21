require 'pathname'
require 'fileutils'
require 'net/scp'
require 'active_support/all'
require 'util/miq-password'

module ApplianceConsole
  CERT_DIR = ENV['KEY_ROOT'] || RAILS_ROOT.join("certs")
  KEY_FILE = "#{CERT_DIR}/v2_key".freeze
  NEW_KEY_FILE = "#{KEY_FILE}.tmp".freeze

  class KeyConfiguration
    attr_accessor :host, :login, :password, :key_path, :action, :force

    def initialize(options = {})
      options.each { |k, v| public_send("#{k}=", v) }
      @action ||= :create
      @login ||= "root"
      @key_path ||= KEY_FILE
    end

    def ask_questions
      if key_exist?
        @force = agree("Overwrite existing encryption key (v2_key)? (Y/N): ")
        return false unless @force
      end

      @action = ask_for_action(@action)

      if fetch_key?
        say("")
        @host      = ask_for_ip_or_hostname("hostname for appliance with encryption key", @host)
        @login     = ask_for_string("appliance SSH login", @login)
        @password  = ask_for_password("appliance SSH password", @password)
        @key_path  = ask_for_string("path of remote encryption key", @key_path)
      end
      @action
    end

    def ask_question_loop
      loop do
        return false unless ask_questions
        return true if activate
        return false unless agree("Try again? (Y/N) ")
      end
    end

    def activate
      if !key_exist? || force
        success_get_new = get_new_key
        if success_get_new
          save_new_key
        else
          remove_new_key_if_any
          false
        end
      else
        # probably only got here via the cli
        $stderr.puts
        $stderr.puts "Only generate one encryption key (v2_key) per installation."
        $stderr.puts "Chances are you did not want to overwrite this file."
        $stderr.puts "If you do this all encrypted secrets in the database will not be readable."
        $stderr.puts "Please backup your key and run this command again with --force-key."
        $stderr.puts
        false
      end
    end

    def save_new_key
      FileUtils.mv(NEW_KEY_FILE, KEY_FILE, :force => true)
    rescue StandardError => e
      say("Failed to overwrite original key, original key kept. #{e.message}")
      return false
    end

    def remove_new_key_if_any
      FileUtils.rm(NEW_KEY_FILE) if File.exist?(NEW_KEY_FILE)
    end

    def key_exist?
      File.exist?(KEY_FILE)
    end

    def fetch_key?
      @action == :fetch
    end

    def create_key
      MiqPassword.generate_symmetric(NEW_KEY_FILE) && true
    end

    def fetch_key
      # use :verbose => 1 (or :debug for later versions) to see actual errors
      Net::SCP.start(host, login, :password => password) do |scp|
        scp.download!(key_path, NEW_KEY_FILE)
      end
      File.exist?(NEW_KEY_FILE)
    rescue => e
      say("Failed to fetch key: #{e.message}")
      false
    end

    private

    def ask_for_action(default_action)
      options = {'Create key' => :create, 'Fetch key from remote machine' => :fetch}
      ask_with_menu("Encryption Key", options, default_action, false)
    end

    def get_new_key
      fetch_key? ? fetch_key : create_key
    end
  end
end
