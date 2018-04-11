module ReFSProbe
  FS_SIGNATURE = [0x00, 0x00, 0x00, 0x52, 0x65, 0x46, 0x53, 0x00].freeze # ...ReFS.

  def self.probe(dobj)
    return false unless dobj.kind_of?(MiqDisk)

    dobj.seek(0, IO::SEEK_SET)
    buf   = dobj.read(FS_SIGNATURE.size)
    magic = buf.unpack('C*') if buf

    # Check for ReFS signature
    raise "ReFS is Not Supported" if magic == FS_SIGNATURE

    # No ReFS
    false
  end
end
