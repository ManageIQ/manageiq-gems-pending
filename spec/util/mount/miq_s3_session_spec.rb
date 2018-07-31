require "util/mount/miq_s3_session"

describe MiqS3Session do
  before(:each) do
    @uri = "s3://tmp/abc/def"
    @session = described_class.new(:uri => @uri, :username => 'user', :password => 'pass', :region => 'region')
    @session.connect
  end

  after(:each) do
    @session.disconnect
  end

  it "#connect returns a string pointing to the mount point" do
    allow(described_class).to receive(:raw_disconnect)
    @session.logger = Logger.new("/dev/null")
    @session.disconnect

    result = @session.connect
    expect(result).to     be_kind_of(String)
    expect(result).to_not be_blank
  end

  it "#mount_share is unique" do
    expect(@session.mount_share).to_not eq(described_class.new(:uri => @uri, :username => 'user', :password => 'pass', :region => 'region').mount_share)
  end

  it ".runcmd will retry with sudo if needed" do
    cmd = "mount X Y"
    expect(described_class).to receive(:`).once.with("#{cmd} 2>&1")
    expect(described_class).to receive(:`).with("sudo #{cmd} 2>&1")
    expect($CHILD_STATUS).to receive(:exitstatus).once.and_return(1)

    described_class.runcmd(cmd)
  end

  it "#@mnt_point starts with '/tmp/miq_'" do
    result = @session.mnt_point
    expect(result).to start_with("/tmp/miq_")
  end

  it "#uri_to_local_path returns a new local path" do
    result = @session.uri_to_local_path(@uri)
    expect(result).to match(/^\/tmp\/miq_.*\/tmp\/abc\/def$/)
  end

  it "#uri_to_object_path returns a new object path" do
    result = @session.uri_to_object_path(@uri)
    expect(result).to eq("abc/def")
  end
end
