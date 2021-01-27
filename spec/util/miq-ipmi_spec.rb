require "util/miq-ipmi"

describe MiqIPMI do
  subject { described_class.new }

  def command_result(output = "")
    double(AwesomeSpawn::CommandResult, :output => output)
  end

  it "#chassis_status" do
    allow(described_class).to receive(:is_2_0_available?).and_return(true)
    response = <<-EOF
System Power         : off
Power Overload       : false
Power Interlock      : inactive
Main Power Fault     : false
Power Control Fault  : false
Power Restore Policy : previous
Last Power Event     : command
Chassis Intrusion    : inactive
Front-Panel Lockout  : inactive
Drive Fault          : false
Cooling/Fan Fault    : false
Sleep Button Disable : not allowed
Diag Button Disable  : allowed
Reset Button Disable : not allowed
Power Button Disable : allowed
Sleep Button Disabled: false
Diag Button Disabled : true
Reset Button Disabled: false
Power Button Disabled: false
EOF

    result = {
      "System Power"          => "off",
      "Power Overload"        => "false",
      "Power Interlock"       => "inactive",
      "Main Power Fault"      => "false",
      "Power Control Fault"   => "false",
      "Power Restore Policy"  => "previous",
      "Last Power Event"      => "command",
      "Chassis Intrusion"     => "inactive",
      "Front-Panel Lockout"   => "inactive",
      "Drive Fault"           => "false",
      "Cooling/Fan Fault"     => "false",
      "Sleep Button Disable"  => "not allowed",
      "Diag Button Disable"   => "allowed",
      "Reset Button Disable"  => "not allowed",
      "Power Button Disable"  => "allowed",
      "Sleep Button Disabled" => "false",
      "Diag Button Disabled"  => "true",
      "Reset Button Disabled" => "false",
      "Power Button Disabled" => "false"
    }

    expected_args = {:I => "lanplus", :H => nil,  :U => nil,  :E => "chassis", nil => ["status"]}
    expect(AwesomeSpawn).to receive(:run!).with("ipmitool", a_hash_including(:params => expected_args)).twice.and_return(command_result(response))
    expect(subject.chassis_status).to eq(result)
  end

  context "version 1.5" do
    before { allow(described_class).to receive(:is_2_0_available?).and_return(false) }
    before { allow_any_instance_of(MiqIPMI).to receive(:chassis_status).and_return({}) }

    it "#interface_mode" do
      expect(subject.interface_mode).to eq("lan")
    end

    it "#run_command" do
      expect(AwesomeSpawn).to receive(:run!).with("ipmitool", a_hash_including(:params => a_hash_including(:I => "lan"))).and_return(command_result)
      subject.run_command("chassis power status")
    end
  end

  context "version 2.0" do
    before { allow(described_class).to receive(:is_2_0_available?).and_return(true) }
    before { allow_any_instance_of(MiqIPMI).to receive(:chassis_status).and_return({}) }

    context "Power Ops" do
      it { expect(subject).to be_connected }

      it "#power_state" do
        expected_args = {:I => "lanplus", :H => nil, :U => nil, :E => "chassis", nil => ["power", "status"]}
        allow(AwesomeSpawn).to receive(:run!).with("ipmitool", a_hash_including(:params => expected_args)).and_return(command_result("Chassis Power is off"))
        expect(subject.power_state).to eq("off")
      end

      it "#power_on" do
        expected_args = {:I => "lanplus", :H => nil, :U => nil, :E => "chassis", nil => ["power", "on"]}
        allow(AwesomeSpawn).to receive(:run!).with("ipmitool", a_hash_including(:params => expected_args)).and_return(command_result("Chassis Power Control: Up/On"))
        expect(subject.power_on).to eq("Chassis Power Control: Up/On")
      end

      it "#power_off" do
        expected_args = {:I => "lanplus", :H => nil, :U => nil, :E => "chassis", nil => ["power", "off"]}
        allow(AwesomeSpawn).to receive(:run!).with("ipmitool", a_hash_including(:params => expected_args)).and_return(command_result("Chassis Power Control: Down/Off"))
        expect(subject.power_off).to eq("Chassis Power Control: Down/Off")
      end

      context "#power_reset" do
        it "currently off" do
          allow(subject).to receive(:power_state).and_return("off")
          expect(subject).to receive(:run_command).with("chassis", "power", "on").and_return("Chassis Power Control: Up/On")
          expect(subject.power_reset).to eq("Chassis Power Control: Up/On")
        end

        it "currently on" do
          allow(subject).to receive(:power_state).and_return("on")
          expect(subject).to receive(:run_command).with("chassis", "power", "reset").and_return("Chassis Power Control: Reset")
          expect(subject.power_reset).to eq("Chassis Power Control: Reset")
        end
      end
    end

    context "management card" do
      let(:mc_info_response) do
        <<-EOR
Device ID                 : 32
Device Revision           : 1
Firmware Revision         : 1.57
IPMI Version              : 2.0
Manufacturer ID           : 674
Manufacturer Name         : DELL Inc
Product ID                : 256 (0x0100)
Product Name              : Unknown (0x100)
Device Available          : yes
Provides Device SDRs      : yes
Additional Device Support :
    Sensor Device
    SDR Repository Device
    SEL Device
    FRU Inventory Device
    IPMB Event Receiver
    Bridge
    Chassis Device
Aux Firmware Rev Info     :
    0x00
    0x04
    0x39
    0x00
EOR
      end

      it "#mc_info" do
        expected_args = {:I => "lanplus", :H => nil, :U => nil, :E => "mc", nil => ["info"]}
        allow(AwesomeSpawn).to receive(:run!).with("ipmitool", a_hash_including(:params => expected_args)).and_return(command_result(mc_info_response))
        expect(subject.mc_info).to eq(
          "Device Available"     => "yes",
          "Device ID"            => "32",
          "Device Revision"      => "1",
          "Firmware Revision"    => "1.57",
          "IPMI Version"         => "2.0",
          "Manufacturer ID"      => "674",
          "Manufacturer Name"    => "DELL Inc",
          "Product ID"           => "256 (0x0100)",
          "Product Name"         => "Unknown (0x100)",
          "Provides Device SDRs" => ["yes", "Additional Device Support :", "Sensor Device", "SDR Repository Device", "SEL Device", "FRU Inventory Device", "IPMB Event Receiver", "Bridge", "Chassis Device", "Aux Firmware Rev Info     :", "0x00", "0x04", "0x39", "0x00"]
        )
      end

      it "#manufacturer" do
        expected_args = {:I => "lanplus", :H => nil, :U => nil, :E => "mc", nil => ["info"]}
        allow(AwesomeSpawn).to receive(:run!).with("ipmitool", a_hash_including(:params => expected_args)).and_return(command_result(mc_info_response))
        expect(subject.manufacturer).to eq("DELL Inc")
      end
    end

    it "#interface_mode" do
      expect(subject.interface_mode).to eq("lanplus")
    end

    it "#run_command" do
      expect(AwesomeSpawn).to receive(:run!).with("ipmitool", a_hash_including(:params => a_hash_including(:I => "lanplus"))).and_return(command_result)
      subject.run_command("chassis power status")
    end
  end
end
