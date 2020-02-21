require 'util/miq-process'

describe MiqProcess do
  context ".command_line" do
    it "exited process" do
      allow(Sys::ProcTable).to receive(:ps).and_return nil
      expect(described_class.command_line(123)).to eq ""
    end

    it "no permissions to proctable info" do
      allow(Sys::ProcTable).to receive(:ps).and_return(double(:cmdline => nil))
      expect(described_class.command_line(123)).to eq ""
    end

    it "normal case" do
      expect(described_class.command_line(Process.pid)).not_to be_empty
    end
  end

  context ".get_active_process_by_name" do
    before do
      proc_list = [
        double("ProcessStruct", :name => "gvim", :pid => 101),
        double("ProcessStruct", :name => "ruby", :pid => 201),
        double("ProcessStruct", :name => "ruby", :pid => 202),
        double("ProcessStruct", :name => "notepad.exe", :pid => 301)
      ]
      allow(Sys::ProcTable).to receive(:ps).and_return(proc_list)
    end

    it "returns the expected processes if found" do
      expect(described_class.get_active_process_by_name('gvim')).to eql([101])
      expect(described_class.get_active_process_by_name('ruby')).to eql([201, 202])
    end

    it "returns an empty array if not found" do
      expect(described_class.get_active_process_by_name('bogus')).to eql([])
    end

    it "finds the name even without an .exe extension" do
      expect(described_class.get_active_process_by_name('notepad')).to eql([301])
      expect(described_class.get_active_process_by_name('notepad.exe')).to eql([301])
    end
  end
end
