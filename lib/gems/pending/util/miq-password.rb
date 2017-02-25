require 'ezcrypto'
require 'openssl'
require 'base64'
require 'yaml'

class MiqPassword
  class MiqPasswordError < StandardError; end

  CURRENT_VERSION = "2"
  REGEXP = /v([0-9]+):\{([^}]*)\}/
  REGEXP_START_LINE = /^#{REGEXP}/

  attr_reader :encStr

  def initialize(str = nil)
    return unless str

    @encStr = encrypt(str)
  end

  def encrypt(str, ver = "v2", key = self.class.keys[ver])
    value = key.encrypt64(str).delete("\n") unless str.nil? || str.empty?
    "#{ver}:{#{value}}"
  end

  def decrypt(str, legacy = false)
    if str.nil? || str.empty?
      str
    else
      ver, enc = self.class.split(str)
      return "" if enc.empty?

      ver ||= "0" # if we don't know what it is, just assume legacy
      key_name = (ver == "2" && legacy) ? "alt" : "v#{ver}"

      begin
        self.class.keys[key_name].decrypt64(enc).force_encoding('UTF-8')
      rescue
        raise MiqPasswordError, "can not decrypt v#{ver}_key encrypted string"
      end
    end
  end

  def recrypt(str)
    return str if str.nil? || str.empty?
    decrypted_str =
      begin
        # if a legacy v2 key exists, give decrypt the option to use that
        decrypt(str, self.class.keys["alt"])
      rescue
        source_version = self.class.split(str).first || "0"
        if source_version == "0" # it probably wasn't encrypted
          return str
        elsif source_version == "2" # tried with an alt key, see if regular v2 key works
          decrypt(str)
        else
          raise
        end
      end
    encrypt(decrypted_str)
  end

  def self.encrypt(str)
    new.encrypt(str) if str
  end

  def self.decrypt(str)
    new.decrypt(str)
  end

  def self.encrypted?(str)
    !!split(str).first
  end

  def self.md5crypt(str)
    cmd = "openssl passwd -1 -salt \"miq\" \"#{try_decrypt(str)}\""
    `#{cmd}`.split("\n").first
  end

  def self.sysprep_crypt(str)
    Base64.encode64("#{try_decrypt(str)}AdministratorPassword".encode("UTF-16LE")).delete("\n")
  end

  def self.sanitize_string(s)
    s.gsub(REGEXP, '********')
  end

  def self.sanitize_string!(s)
    s.gsub!(REGEXP, '********')
  end

  def self.try_decrypt(str)
    encrypted?(str) ? decrypt(str) : str
  end

  def self.try_encrypt(str)
    encrypted?(str) ? str : encrypt(str)
  end

  # @returns [ver, enc]
  def self.split(encrypted_str)
    if encrypted_str.nil? || encrypted_str.empty?
      [nil, encrypted_str]
    else
      if encrypted_str =~ REGEXP_START_LINE
        [$1, $2]
      elsif legacy = extract_erb_encrypted_value(encrypted_str)
        if legacy =~ REGEXP_START_LINE
          [$1, $2]
        else
          ["0", legacy]
        end
      else
        [nil, encrypted_str]
      end
    end
  end

  def self.key_root
    @@key_root ||= ENV["KEY_ROOT"]
  end

  def self.key_root=(key_root)
    clear_keys
    @@key_root = key_root
  end

  def self.clear_keys
    @@all_keys = nil
  end

  def self.all_keys
    keys.values
  end

  def self.keys
    @@all_keys ||= {"v2" => load_v2_key}.delete_if { |_n, v| v.nil? }
  end

  def self.v2_key
    keys["v2"]
  end

  def self.load_v2_key
    load_key_file("v2_key") || begin
      key_file = File.expand_path("v2_key", key_root)
      msg = <<-EOS
#{key_file} doesn't exist!
On an appliance, it should be generated on boot by evmserverd.

If you're a developer, you can copy the #{key_file}.dev to #{key_file}.

Caution, using the developer key will allow anyone with the public developer key to decrypt the two-way
passwords in your database.
EOS
      Kernel.warn msg
    end
  end

  def self.add_legacy_key(filename, type = "alt")
    key = load_key_file(filename, type != :v0)
    keys[type.to_s] = key if key
    key
  end

  # used by tests only
  def self.v2_key=(key)
    (@@all_keys ||= {})["v2"] = key
  end

  def self.generate_symmetric(filename = nil)
    Key.new.tap { |key| store_key_file(filename, key) if filename }
  end

  protected

  def self.store_key_file(filename, key)
    File.write(filename, key.to_h.to_yaml)
  end

  def self.load_key_file(filename, recent = true)
    return filename if filename.respond_to?(:decrypt64)

    # if it is an absolute path, or relative to pwd, leave as is
    # otherwise, look in key root for it
    filename = File.expand_path(filename, key_root) unless File.exist?(filename)
    if !File.exist?(filename)
      nil
    elsif recent
      params = YAML.load_file(filename)
      Key.new(*params.values_at(:algorithm, :key, :iv))
    else
      params = YAML.load_file(filename)
      algorithm, key, iv = params.values_at(:algorithm, :key, :iv)
      Key.new(algorithm, key && Base64.encode64(key), iv && Base64.encode64(iv))
    end
  end

  def self.extract_erb_encrypted_value(value)
    return $1 if value =~ /\A<%= (?:MiqPassword|DB_PASSWORD)\.decrypt\(['"]([^'"]+)['"]\) %>\Z/
  end

  class Key
    GENERATED_KEY_SIZE = 32

    def self.generate_key(password = nil, salt = nil)
      password ||= OpenSSL::Random.random_bytes(GENERATED_KEY_SIZE)
      Base64.encode64(Digest::SHA256.digest("#{password}#{salt}")[0, GENERATED_KEY_SIZE]).chomp
    end

    def initialize(algorithm = nil, key = nil, iv = nil)
      @algorithm = algorithm || "aes-256-cbc"
      @key       = key || generate_key
      @raw_key   = Base64.decode64(@key)
      @iv        = iv
      @raw_iv    = iv && Base64.decode64(iv)
    end

    def encrypt(str)
      apply(:encrypt, str)
    end

    def encrypt64(str)
      Base64.encode64(encrypt(str)).chomp
    end

    def decrypt(str)
      apply(:decrypt, str)
    end

    def decrypt64(str)
      decrypt(Base64.decode64(str))
    end

    def to_s
      @key
    end

    def to_h
      {
        :algorithm => @algorithm,
        :key       => @key
      }.tap do |h|
        h[:iv] = @iv if @iv
      end
    end

    private

    def generate_key
      raise "key can only be generated for the aes-256-cbc algorithm" unless @algorithm == "aes-256-cbc"
      self.class.generate_key
    end

    def apply(mode, str)
      c = OpenSSL::Cipher.new(@algorithm)
      c.public_send(mode)
      c.key = @raw_key
      c.iv  = @raw_iv if @raw_iv
      c.update(str) << c.final
    end
  end
end

# Backward compatibility for the class that used to be used by Rails.
DB_PASSWORD = MiqPassword
