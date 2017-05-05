require 'uuidtools'

module MiqUUID
  REGEX_FORMAT = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/

  def self.clean_guid(guid)
    return nil if guid.nil?
    g = guid.to_s.downcase
    return nil if g.strip.empty?
    return g if g.length == 36 && g =~ REGEX_FORMAT
    g.delete!('^0-9a-f')
    g.sub!(/^([0-9a-f]{8})([0-9a-f]{4})([0-9a-f]{4})([0-9a-f]{4})([0-9a-f]{12})$/, '\1-\2-\3-\4-\5')
  end
end
