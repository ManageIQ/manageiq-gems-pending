require "appliance_console/internal_database_configuration"

describe ApplianceConsole::InternalDatabaseConfiguration do
  before do
    @old_key_root = MiqPassword.key_root
    MiqPassword.key_root = ManageIQ::Gems::Pending.root.join("spec/support")
    @config = described_class.new
  end

  after do
    MiqPassword.key_root = @old_key_root
  end

  context ".new" do
    it "set defaults automatically" do
      expect(@config.host).to eq('localhost')
      expect(@config.username).to eq("root")
      expect(@config.database).to eq("vmdb_production")
      expect(@config.run_as_evm_server).to be true
    end
  end

  context "postgresql service" do
    it "#start_postgres (private)" do
      allow(LinuxAdmin::Service).to receive(:new).and_return(double(:service).as_null_object)
      allow(PostgresAdmin).to receive_messages(:service_name => 'postgresql')
      expect(@config).to receive(:block_until_postgres_accepts_connections)
      @config.send(:start_postgres)
    end
  end

  it "#choose_disk" do
    expect(@config).to receive(:ask_for_disk)
    @config.choose_disk
  end

  context "#check_disk_is_mount_point" do
    it "not raise error if disk is given" do
      expect(@config).to receive(:disk).and_return("/x")
      @config.check_disk_is_mount_point
    end

    it "not raise error if no disk given but mount point for database is really a mount point" do
      expect(@config).to receive(:disk).and_return(nil)
      expect(@config).to receive(:pg_mount_point?).and_return(true)
      @config.check_disk_is_mount_point
    end

    it "raise error if no disk given and not a mount point" do
      expect(@config).to receive(:disk).and_return(nil)
      expect(@config).to receive(:pg_mount_point?).and_return(false)
      expect { @config.check_disk_is_mount_point }.to raise_error(RuntimeError, "The disk for database must be a mount point")
    end
  end

  it ".postgresql_template" do
    allow(PostgresAdmin).to receive_messages(:data_directory     => Pathname.new("/var/lib/pgsql/data"))
    allow(PostgresAdmin).to receive_messages(:template_directory => Pathname.new("/opt/manageiq/manageiq-appliance/TEMPLATE"))
    expect(described_class.postgresql_template.to_s).to end_with("TEMPLATE/var/lib/pgsql/data")
  end

  describe "#post_activation" do
    it "doesnt start evm if run_as_evm_server is false" do
      @config.run_as_evm_server = false
      expect(@config).not_to receive(:start_evm)
      @config.post_activation
    end

    it "starts evm if run_as_evm_server is true" do
      @config.run_as_evm_server = true
      expect(@config).to receive(:start_evm)
      @config.post_activation
    end
  end
end
