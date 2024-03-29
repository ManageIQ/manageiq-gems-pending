describe MiqLoggerProcessor do
  MLP_DATA_DIR = File.expand_path(File.join(File.dirname(__FILE__), 'data'))

  EXPECTED_LINE_PARTS = [
    [
      "[----] I, [2011-02-07T17:30:59.744697 #14909:15aee2c37f0c]  INFO -- evm: MIQ(SQLServer.apply_connection_config) trans_isolation_level: [], lock_timeout: []\n",
      "2011-02-07T17:30:59.744697",
      "14909",
      "15aee2c37f0c",
      "INFO",
      "evm",
      nil,
      "SQLServer.apply_connection_config",
      "MIQ(SQLServer.apply_connection_config) trans_isolation_level: [], lock_timeout: []",
    ],
    [
      "[----] I, [2011-02-07T17:31:59.744697 #14909:15aee2c37f0c]  INFO -- development: MIQ(SQLServer.apply_connection_config) trans_isolation_level: [], lock_timeout: []\n",
      "2011-02-07T17:31:59.744697",
      "14909",
      "15aee2c37f0c",
      "INFO",
      "development",
      nil,
      "SQLServer.apply_connection_config",
      "MIQ(SQLServer.apply_connection_config) trans_isolation_level: [], lock_timeout: []",
    ],
    [
      "[----] I, [2011-02-07T17:32:59.744697 #14909:15aee2c37f0c]  INFO -- : MIQ(SQLServer.apply_connection_config) trans_isolation_level: [], lock_timeout: []\n",
      "2011-02-07T17:32:59.744697",
      "14909",
      "15aee2c37f0c",
      "INFO",
      nil,
      nil,
      "SQLServer.apply_connection_config",
      "MIQ(SQLServer.apply_connection_config) trans_isolation_level: [], lock_timeout: []",
    ],
    [
      "[----] I, [2011-02-07T17:31:05.282104 #4909:03941abd4fe]  INFO -- evm: MIQ(EmsRefreshWorker) ID [108482], PID [14909], GUID [0461c4a4-32e0-11e0-89ad-0050569a00bb], Zone [WB], Active Roles\n",
      "2011-02-07T17:31:05.282104",
      "4909",
      "03941abd4fe",
      "INFO",
      "evm",
      nil,
      "EmsRefreshWorker",
      "MIQ(EmsRefreshWorker) ID [108482], PID [14909], GUID [0461c4a4-32e0-11e0-89ad-0050569a00bb], Zone [WB], Active Roles",
    ],
    [
      "[----] I, [2011-02-07T17:31:05.282996 #14909:15aee2c37f0c]  INFO -- evm:   :cpu_usage_threshold: 100\nthis\nis a\nmultiline\n",
      "2011-02-07T17:31:05.282996",
      "14909",
      "15aee2c37f0c",
      "INFO",
      "evm",
      nil,
      nil,
      "  :cpu_usage_threshold: 100\nthis\nis a\nmultiline",
    ],
    [
      "[----] I, [2011-02-07T07:49:16.719656 #23130:15c945a976fc]  INFO -- evm: Q-task_id([1753657a-3288-11e0-bd88-0050569a00ba]) MIQ(MiqQueue.get)        Message id: [18261690] stale, retrying...\n",
      "2011-02-07T07:49:16.719656",
      "23130",
      "15c945a976fc",
      "INFO",
      "evm",
      "1753657a-3288-11e0-bd88-0050569a00ba",
      "MiqQueue.get",
      "MIQ(MiqQueue.get)        Message id: [18261690] stale, retrying...",
    ],
    [
      "[----] I, [2011-02-07T10:41:37.668866 #29614:15a82de14700]  INFO -- evm: Q-task_id([job_dispatcher]) MIQ(MiqQueue.get)        Message id: [18261690] stale, retrying...\n",
      "2011-02-07T10:41:37.668866",
      "29614",
      "15a82de14700",
      "INFO",
      "evm",
      "job_dispatcher",
      "MiqQueue.get",
      "MIQ(MiqQueue.get)        Message id: [18261690] stale, retrying...",
    ],
    [
      "[1234] I, [2011-02-07T17:30:59.744697 #14909:15aee2c37f0c]  INFO -- evm: MIQ(SQLServer.apply_connection_config) trans_isolation_level: [], lock_timeout: []\n",
      "2011-02-07T17:30:59.744697",
      "14909",
      "15aee2c37f0c",
      "INFO",
      "evm",
      nil,
      "SQLServer.apply_connection_config",
      "MIQ(SQLServer.apply_connection_config) trans_isolation_level: [], lock_timeout: []",
    ],
  ]

  EXPECTED_RAW_LINES = EXPECTED_LINE_PARTS.collect(&:first)
  EXPECTED_CSV_ARRAY = [
    [
      "time",
      "capture_state",
      "db_find_prev_perfs",
      "db_find_storage_files",
      "init_attrs",
      "process_perfs",
      "process_perfs_tag",
      "unaccounted",
      "total_time"
    ],
    [
      "2016-02-02T03:41:04.538793",
      "0.05266451835632324",
      "32.21144223213196",
      "0.49041008949279785",
      "1.371647834777832",
      "11.871733665466309",
      "0.05523490905761719",
      "4.358347177505493",
      "50.41148042678833"],
    [
      "2016-02-02T03:41:12.710256",
      "0.05573296546936035",
      "32.547961473464966",
      "0.6642637252807617",
      "2.038071393966675",
      "19.853408575057983",
      "0.05427432060241699",
      "4.256502151489258",
      "59.47021460533142"
    ]
  ]

  before(:each) do
    @lp = MiqLoggerProcessor.new(File.join(MLP_DATA_DIR, 'miq_logger_processor.log'))
  end

  context "reading raw lines" do
    before(:each) { @lines = @lp.to_a }

    it "will read the correct number of lines" do
      expect(@lines.length).to eq(EXPECTED_RAW_LINES.length)
    end

    it "will read the correct number of lines when called twice" do
      @lines = @lp.to_a
      expect(@lines.length).to eq(EXPECTED_RAW_LINES.length)
    end

    it "will read regular lines correctly" do
      expect(@lines[0]).to eq(EXPECTED_RAW_LINES[0])
    end

    it "will read lines with shortened pid/tid correctly" do
      expect(@lines[1]).to eq(EXPECTED_RAW_LINES[1])
    end

    it "will read multi-line lines correctly" do
      expect(@lines[2]).to eq(EXPECTED_RAW_LINES[2])
    end

    it "will read Q-task_id lines correctly" do
      expect(@lines[3]).to eq(EXPECTED_RAW_LINES[3])
    end

    it "will read Q-task_id lines that do not have GUIDs correctly" do
      expect(@lines[4]).to eq(EXPECTED_RAW_LINES[4])
    end

    it "will extract the fully qualified method name when available" do
      expect(@lines[5]).to eq(EXPECTED_RAW_LINES[5])
    end

    it "will read lines with a numeric starting message correctly" do
      expect(@lines[6]).to eq(EXPECTED_RAW_LINES[6])
    end
  end

  shared_examples_for "all line processors" do
    it "will read regular lines correctly" do
      expect(@lines[0]).to eq(EXPECTED_LINE_PARTS[0])
    end

    it "will read lines with shortened pid/tid correctly" do
      expect(@lines[1]).to eq(EXPECTED_LINE_PARTS[1])
    end

    it "will read multi-line lines correctly" do
      expect(@lines[2]).to eq(EXPECTED_LINE_PARTS[2])
    end

    it "will read Q-task_id lines correctly" do
      expect(@lines[3]).to eq(EXPECTED_LINE_PARTS[3])
    end

    it "will read Q-task_id lines that do not have GUIDs correctly" do
      expect(@lines[4]).to eq(EXPECTED_LINE_PARTS[4])
    end

    it "will read lines with a numeric starting message correctly" do
      expect(@lines[5]).to eq(EXPECTED_LINE_PARTS[5])
    end
  end

  [:split, :to_a, :parts].each do |method_name|
    context "calling #{method_name} on successive lines" do
      before(:each) do
        @lines = @lp.collect { |line| [line, *line.send(method_name)] }
      end

      it_should_behave_like "all line processors"
    end
  end

  context "calling instance methods on successive lines" do
    before(:each) do
      @lines = @lp.collect { |line| [line, *MiqLoggerLine::PARTS.collect { |p| line.send(p) }] }
    end

    it_should_behave_like "all line processors"
  end

  it "calling read_csv" do
    filename = File.join(MLP_DATA_DIR, 'miq_logger_processor.csv')
    expect(MiqLoggerProcessor.read_csv(filename)).to eql(EXPECTED_CSV_ARRAY)
  end
end
