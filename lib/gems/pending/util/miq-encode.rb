require 'zlib'

class MIQEncode
  def self.encode(data, compress = true)
    return [Zlib::Deflate.deflate(data)].pack("m") if compress
    [data].pack("m")
  end

  def self.decode(data, compressed = true)
    return Zlib::Inflate.inflate(data.unpack("m")[0]) if compressed
    data.unpack("m")[0]
  end
end
