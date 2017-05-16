describe MiqApache::Control do
  it "should run_apache_cmd with start when calling start" do
    expect(MiqApache::Control).to receive(:run_apache_cmd).with('start')
    MiqApache::Control.start
  end

  it "should run_apache_cmd with graceful-stop and start when calling restart with graceful true" do
    expect(MiqApache::Control).to receive(:run_apache_cmd).with('stop')
    expect(MiqApache::Control).to receive(:run_apache_cmd).with('start')
    MiqApache::Control.restart(true)
  end

  it "should run_apache_cmd with restart when calling restart with graceful false" do
    expect(MiqApache::Control).to receive(:run_apache_cmd).with('restart')
    MiqApache::Control.restart(false)
  end

  it "should run_apache_cmd with graceful-stop when calling stop with graceful true" do
    expect(MiqApache::Control).to receive(:run_apache_cmd).with('stop')
    MiqApache::Control.stop(true)
  end

  it "should run_apache_cmd with stop when calling stop with graceful false" do
    expect(MiqApache::Control).to receive(:run_apache_cmd).with('stop')
    MiqApache::Control.stop(false)
  end

  it "config_ok? is true if nothing raised" do
    allow(MiqUtil).to receive(:runcmd)
    expect(described_class.config_ok?).to be_truthy
  end

  it "config_ok? is false when error was raised" do
    allow(MiqUtil).to receive(:runcmd).and_raise(StandardError)
    expect(described_class.config_ok?).to be_falsey
  end

  it "should make the apache control log's directory if missing when calling run_apache_cmd" do
    allow(File).to receive(:exist?).and_return(false)
    expect(Dir).to receive(:mkdir).with(File.dirname(MiqApache::Control::APACHE_CONTROL_LOG))
    allow(MiqUtil).to receive(:runcmd)
    MiqApache::Control.run_apache_cmd("start")
  end

  it "should not make the apache control log's directory if it exists when calling run_apache_cmd" do
    allow(File).to receive(:exist?).and_return(true)
    expect(Dir).to receive(:mkdir).with(File.dirname(MiqApache::Control::APACHE_CONTROL_LOG)).never
    allow(MiqUtil).to receive(:runcmd)
    MiqApache::Control.run_apache_cmd("start")
  end

  it "should build cmdline when calling run_apache_cmd with start" do
    cmd = "start"
    allow(File).to receive(:exist?).and_return(true)
    $log = Logger.new(STDOUT) unless $log
    allow($log).to receive(:debug?).and_return(false)
    expect(MiqUtil).to receive(:runcmd).with("apachectl #{cmd}")
    MiqApache::Control.run_apache_cmd("start")
  end

  it "should build cmdline when calling run_apache_cmd with start in debug mode if $log is debug" do
    cmd = "start"
    allow(File).to receive(:exist?).and_return(true)
    $log = Logger.new(STDOUT) unless $log
    allow($log).to receive(:debug?).and_return(true)
    expect(MiqUtil).to receive(:runcmd).with("apachectl #{cmd}")
    MiqApache::Control.run_apache_cmd("start")
  end

  it "should log a warning when calling run_apache_cmd with start that raises an error" do
    cmd = "start"
    allow(File).to receive(:exist?).and_return(true)
    $log = Logger.new(STDOUT) unless $log
    allow($log).to receive(:debug?).and_return(false)
    allow(MiqUtil).to receive(:runcmd).and_raise("warn")
    expect($log).to receive(:warn)
    MiqApache::Control.run_apache_cmd("start")
  end
end
