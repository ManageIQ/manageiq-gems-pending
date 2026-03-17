require 'launchy'

RSpec.describe MiqSystem do
  context ".cpu_usage" do
    it "returns nil if stat is nil" do
      allow(Sys::ProcTable).to receive(:ps).with(pid: Process.pid).and_return(nil)
      expect(described_class.cpu_usage).to be_nil
    end

    it "returns integer cpu percent if stat.pctcpu is present" do
      fake_stat = double('Stat', pctcpu: 0.42)
      allow(fake_stat).to receive(:respond_to?).with(:pctcpu).and_return(true)
      allow(Sys::ProcTable).to receive(:ps).with(pid: Process.pid).and_return(fake_stat)
      expect(described_class.cpu_usage).to eq(42)
    end

    it "returns nil if stat does not respond to pctcpu" do
      fake_stat = double('Stat')
      allow(fake_stat).to receive(:respond_to?).with(:pctcpu).and_return(false)
      allow(Sys::ProcTable).to receive(:ps).with(pid: Process.pid).and_return(fake_stat)
      expect(described_class.cpu_usage).to be_nil
    end
  end

  context ".num_cpus" do
    it "returns the number of logical processors" do
      allow(Etc).to receive(:nprocessors).and_return(8)
      expect(described_class.num_cpus).to eq(8)
    end
  end

  context ".memory" do
    it "returns memory hash from sys-memory" do
      fake_mem = double('Memory',
        total_bytes: 1000,
        free_bytes: 200,
        buffer_bytes: 100,
        cached_bytes: 50,
        total_swap_bytes: 300,
        free_swap_bytes: 150
      )
      allow(Sys::Memory).to receive(:memory).and_return(fake_mem)
      expect(described_class.memory).to eq({
        MemTotal: 1000,
        MemFree: 200,
        Buffers: 100,
        Cached: 50,
        SwapTotal: 300,
        SwapFree: 150
      })
    end
  end

  context ".total_memory" do
    it "returns total memory from memory hash" do
      allow(described_class).to receive(:memory).and_return({MemTotal: 1234})
      expect(described_class.total_memory).to eq(1234)
    end
  end

  context ".status" do
    it "returns cpu_usage and memory" do
      allow(described_class).to receive(:cpu_usage).and_return(55)
      allow(described_class).to receive(:memory).and_return({MemTotal: 100})
      expect(described_class.status).to eq({cpu_usage: 55, memory: {MemTotal: 100}})
    end
  end

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

  context ".arch" do
    it "returns arch from Sys::Platform::ARCH" do
      stub_const("Sys::Platform::ARCH", :x86_64)
      stub_const("Sys::Platform::OS", :unix)
      expect(described_class.arch).to eq(:x86_64)
    end
  end

  context ".tail" do
    it "returns last N lines from a file" do
      Tempfile.open("miqsystem-tail") do |f|
        f.puts "a"
        f.puts "b"
        f.puts "c"
        f.close
        result = described_class.tail(f.path, 2)
        expect(result.map(&:strip)).to eq(["b", "c"])
      end
    end
  end

  context ".readfile_async" do
    it "returns nil if file does not exist" do
      expect(described_class.readfile_async("/no/such/file")).to be_nil
    end
    it "returns up to maxlen bytes from file" do
      Tempfile.open("miqsystem-read") do |f|
        f.write "abcdefg"
        f.close
        expect(described_class.readfile_async(f.path, 3)).to eq("abc")
      end
    end
  end

  context ".open_browser" do
    it "calls Launchy.open with the url" do
      allow(Launchy).to receive(:open)
      described_class.open_browser("http://example.com")
      expect(Launchy).to have_received(:open).with("http://example.com")
    end
  end
end
