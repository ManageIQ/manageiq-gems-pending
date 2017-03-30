require "yaml"

module MiqApache
  DEFAULT = {
    :scl          => false,
    :package_name => "httpd",
    :service_name => "httpd",
    :root_dir     => "/",
    :base_dir     => "/etc/httpd",
    :config_dir   => "/etc/httpd/conf.d",
    :apachectl    => "apachectl"
  }.freeze

  RAILS_ROOT ||= if File.exist?("/var/www/miq/vmdb")
                   Pathname.new("/var/www/miq/vmdb")
                 elsif defined?(Rails)
                   Rails.root
                 else
                   gem_root = Gem::Specification.find_by_name("manageiq-gems-pending").gem_dir # rubocop:disable Rails/DynamicFindBy
                   Pathname.new(File.expand_path(File.join(Pathname.new(gem_root), "../manageiq")))
                 end.freeze

  def self.scl?
    config[:scl] || DEFAULT[:scl]
  end

  def self.package_name
    ENV.fetch('MIQ_APACHE_PACKAGE_NAME', config[:package_name] || DEFAULT[:package_name])
  end

  def self.service_name
    ENV.fetch('MIQ_APACHE_SERVICE_NAME', config[:service_name] || DEFAULT[:service_name])
  end

  def self.root_dir
    ENV.fetch('MIQ_APACHE_ROOT_DIR', config[:root_dir] || DEFAULT[:root_dir])
  end

  def self.base_dir
    config[:base_dir] || DEFAULT[:base_dir]
  end

  def self.config_dir
    config[:config_dir] || DEFAULT[:config_dir]
  end

  def self.apachectl
    config[:apachectl] || DEFAULT[:apachectl]
  end

  def self.config
    @_miq_apache_config ||= begin
                              config_file = RAILS_ROOT.join("config/apache.yml")
                              File.exist?(config_file) ? YAML.load_file(config_file) : {}
                            end
  end
end
