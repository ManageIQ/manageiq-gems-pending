require 'fileutils'
require 'logger'
require 'active_support/core_ext/class/attribute_accessors'
require 'util/runcmd'
require 'util/extensions/miq-array'

module MiqApache
  # Abstract Apache Error Class
  class Error < RuntimeError; end

  ###################################################################
  #
  # http://httpd.apache.org/docs/2.2/programs/apachectl.html
  #
  ###################################################################
  class Control
    APACHE_CONTROL_LOG = '/var/www/miq/vmdb/log/apache/miq_apache.log'

    def self.restart
      ###################################################################
      # Gracefully restarts the Apache httpd daemon. If the daemon is not running, it is started.
      # This differs from a normal restart in that currently open connections are not aborted.
      # A side effect is that old log files will not be closed immediately. This means that if
      # used in a log rotation script, a substantial delay may be necessary to ensure that the
      # old log files are closed before processing them. This command automatically checks the
      # configuration files as in configtest before initiating the restart to make sure Apache
      # doesn't die.
      #
      # Command line: apachectl graceful
      ###################################################################
      #
      # FIXME: apache doesn't re-read the proxy balancer members on a graceful restart, so do a graceful stop and start
      #        system('apachectl graceful')
      # http://www.gossamer-threads.com/lists/apache/users/383770
      # https://issues.apache.org/bugzilla/show_bug.cgi?id=45950
      # https://issues.apache.org/bugzilla/show_bug.cgi?id=39811
      # https://issues.apache.org/bugzilla/show_bug.cgi?id=44736
      # https://issues.apache.org/bugzilla/show_bug.cgi?id=42621

      stop
      start
    end

    def self.start
      if ENV["CONTAINER"]
        system("/usr/sbin/httpd -DFOREGROUND &")
      else
        run_apache_cmd 'start'
      end
    end

    def self.stop
      if ENV["CONTAINER"]
        system("kill -WINCH $(pgrep -P 1 httpd)")
      else
        run_apache_cmd 'stop'
      end
    end

    def self.config_ok?
      ###################################################################
      # Run a configuration file syntax test. It parses the configuration files and either
      # reports Syntax Ok or detailed information about the particular syntax error.
      #
      # Command line: apachectl configtest
      ###################################################################
      begin
        res = MiqUtil.runcmd('apachectl configtest')
      rescue => err
        $log.warn("MIQ(MiqApache::Control.config_ok?) Configuration syntax failed with error: #{err} for result: #{res}") if $log
        false
      else
        true
      end
    end

    private

    def self.run_apache_cmd(command)
      Dir.mkdir(File.dirname(APACHE_CONTROL_LOG)) unless File.exist?(File.dirname(APACHE_CONTROL_LOG))
      begin
        cmd = "apachectl #{command}"
        res = MiqUtil.runcmd(cmd)
      rescue => err
        $log.warn("MIQ(MiqApache::Control.run_apache_cmd) Apache command #{command} with result: #{res} failed with error: #{err}") if $log
      end
    end
  end

  ###################################################################
  #
  # Control Exceptions Definition
  #
  ###################################################################
  class ControlError < Error; end

  ###################################################################
  #
  # http://httpd.apache.org/docs/2.2/configuring.html
  #
  ###################################################################
  class Conf
    RE_COMMENT = /^\s*(?:\#.*)?$/
    RE_BLOCK_DIRECTIVE_START = /^\s*<([A-Za-z][^\s>]*)\s*([^>]*)>/

    attr_reader :fname
    attr_accessor :raw_lines

    def initialize(filename = nil)
      raise ConfFileNotSpecified if filename.nil?
      raise ConfFileNotFound     unless File.file?(filename)
      @fname     = filename
      reload
    end

    def self.install_default_config(opts = {})
      File.write(opts[:member_file],    create_balancer_config(opts))
      File.write(opts[:redirects_file], create_redirects_config(opts))
    end

    def self.create_balancer_config(opts = {})
      "<Proxy balancer://#{opts[:cluster]}/ lbmethod=bybusyness>\n</Proxy>\n"
    end

    def self.create_redirects_config(opts = {})
      opts[:redirects].to_miq_a.each_with_object("") do |redirect, content|
        if redirect == "/"
          content << "RewriteRule ^/ui/service(?!/(assets|images|img|styles|js|fonts|vendor|gettext)) /ui/service/index.html [L]\n"
          content << "RewriteRule ^/self_service(.*) /ui/service$1 [R]\n"
          content << "RewriteCond \%{REQUEST_URI} !^/ws\n"
          content << "RewriteCond \%{REQUEST_URI} !^/proxy_pages\n"
          content << "RewriteCond \%{REQUEST_URI} !^/saml2\n"
          content << "RewriteCond \%{REQUEST_URI} !^/api\n"
          content << "RewriteCond \%{REQUEST_URI} !^/ansibleapi\n"
          content << "RewriteCond \%{DOCUMENT_ROOT}/\%{REQUEST_FILENAME} !-f\n"
          content << "RewriteRule ^#{redirect} balancer://#{opts[:cluster]}\%{REQUEST_URI} [P,QSA,L]\n"
        else
          content << "ProxyPass #{redirect} balancer://#{opts[:cluster]}#{redirect}\n"
        end
        # yes, we want ProxyPassReverse for both ProxyPass AND RewriteRule [P]
        content << "ProxyPassReverse #{redirect} balancer://#{opts[:cluster]}#{redirect}\n"
      end
    end

    def self.create_conf_file(filename, content)
      raise ConfFileAlreadyExists if File.exist?(filename)

      FileUtils.touch(filename)
      file = new(filename)
      file.add_content(content, :update_raw_lines => true)
      file.save
    end

    def add_content(content, options = {})
      content = content.split("\n") if content.kind_of?(String)
      lines   = content.collect { |line| line.kind_of?(Hash) ? create_directive(line) : line }

      options[:update_raw_lines] ? @raw_lines.push(lines.flatten.join("\n")) : lines
    end

    def create_directive(hash)
      raise ArgumentError, ":directive key is required" if hash[:directive].blank?

      open  = "<#{hash[:directive]} #{hash[:attribute]}".strip << ">"
      close = "</#{hash[:directive]}>"

      ["", open, add_content(hash[:configurations]), close, ""]
    end

    def reload
      @raw_lines = File.read(@fname).lines.to_a
    end

    def line_count
      @raw_lines.size
    end

    def content_lines
      # Ignore empty or commented lines
      @raw_lines.delete_if { |line| line =~ RE_COMMENT }
    end

    def block_directives
      @raw_lines.delete_if { |line| line !~ RE_BLOCK_DIRECTIVE_START }
    end

    def add_ports(ports, protocol)
      index = @raw_lines.index { |line| line =~ RE_BLOCK_DIRECTIVE_START && $1 == 'Proxy' && $2 =~ /^balancer:\/\/evmcluster[^\s]*\// }

      raise "Proxy section not found in file: #{@fname}" if index.nil?

      ports = Array(ports).sort.reverse
      ports.each do |port|
        # Temporarily disable the connection reuse for WebSockets for httpd version < 2.4.25
	# https://bugzilla.redhat.com/show_bug.cgi?id=1404354
        if protocol == 'ws'
          @raw_lines.insert(index + 1, "BalancerMember #{protocol}://0.0.0.0:#{port} disablereuse=On\n")
        else
          @raw_lines.insert(index + 1, "BalancerMember #{protocol}://0.0.0.0:#{port}\n")
        end
      end
      ports
    end

    def remove_ports(ports, protocol)
      ports = Array(ports)
      ports.each do |port|
        @raw_lines.delete_if { |line| line =~ /BalancerMember\s+#{protocol}:\/\/0\.0\.0\.0:#{port}( disablereuse=On)?$/ }
      end
      ports
    end

    def save
      backup = "#{@fname}_old"
      FileUtils.cp(@fname, backup)
      File.write(@fname, @raw_lines.join(""))
      unless Control.config_ok?
        $log.warn("MIQ(MiqApache::Conf.save) Restoring old configuration due to bad configuration!") if $log
        FileUtils.cp(backup, @fname)
        return false
      end
      true
    end
  end

  ###################################################################
  #
  # Configuration Exceptions Definition
  #
  ##################################################################
  class ConfError < Error; end
  class ConfFileAlreadyExists < ConfError; end
  class ConfFileNotSpecified < ConfError; end
  class ConfFileNotFound < ConfError; end
  class ConfFileInvalid < ConfError; end
end
