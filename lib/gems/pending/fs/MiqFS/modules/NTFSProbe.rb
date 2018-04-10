module NTFSProbe
  def self.probe(dobj)
    unless dobj.kind_of?(MiqDisk)
      $log.debug "NTFSProbe << FALSE because Disk Object class is not MiqDisk, but is '#{dobj.class}'" if $log
      return false
    end

    # Check for oem name = NTFS.
    dobj.seek(3)
    buf = dobj.read(8)
    bs  = buf.unpack('a8') if buf
    oem = bs[0].strip if bs

    ntfs = oem == 'NTFS'
    if $log
      $log.debug("NTFSProbe << TRUE") if ntfs
      $log.debug("NTFSProbe << FALSE because OEM Name is not NTFS, but is '#{oem}'") unless ntfs
    end

    ntfs
  end
end
