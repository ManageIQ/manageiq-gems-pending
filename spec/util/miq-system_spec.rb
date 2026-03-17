describe MiqSystem do
  context ".disk_usage(file)" do
    it "returns disk usage for a given mount" do
      fake_mount = double('Mount', name: '/dev/sda1', mount_type: 'ext4', mount_point: '/mnt')
      fake_stat = double('Stat',
        bytes_total: 1000,
        bytes_used: 400,
        bytes_available: 600,
        files_total: 100,
        files_used: 40,
        files_available: 60
      )
      allow(Sys::Filesystem).to receive(:mounts).and_return([fake_mount])
      allow(Sys::Filesystem).to receive(:stat).with('/mnt').and_return(fake_stat)
      result = described_class.disk_usage('/mnt')
      expect(result).to eq([
        {
          filesystem: '/dev/sda1',
          type: 'ext4',
          total_bytes: 1000,
          used_bytes: 400,
          available_bytes: 600,
          used_bytes_percent: 40,
          total_inodes: 100,
          used_inodes: 40,
          available_inodes: 60,
          used_inodes_percent: 40,
          mount_point: '/mnt'
        }
      ])
    end
  end
end
