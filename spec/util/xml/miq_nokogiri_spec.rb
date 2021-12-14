require 'util/miq-xml'
require 'nokogiri'

describe "miq_nokogiri" do
  def default_test_xml
    xml_string = <<-EOL
      <?xml version='1.0' encoding='UTF-8'?>
      <rows>
        <head>
          <column width='10' type='link' sort='str'>Name</column>
          <column width='10' type='ro' sort='str'>Host Name</column>
          <column width='10' type='ro' sort='str'>IP Address</column>
          <column width='10' type='ro' sort='str'>VMM Vendor</column>
          <column width='10' type='ro' sort='str'>VMM Version</column>
          <column width='10' type='ro' sort='str'>VMM Product</column>
          <column width='10' type='ro' sort='str'>Registered On</column>
          <column width='10' type='ro' sort='str'>SmartState Heartbeat</column>
          <column width='10' type='ro' sort='str'>SmartState Version</column>
          <column width='10' type='ro' sort='str'>WS Port</column>
          <settings>
            <colwidth>%</colwidth>
          </settings>
        </head>
        <row id='8'>
          <cell>esxdev001.localdomain^/host/show/8^_self</cell>
          <cell>esxdev001.localdomain</cell>
          <cell>192.168.177.49</cell>
          <cell>VMware</cell>
          <cell>3.0.2</cell>
          <cell>ESX Server</cell>
          <cell>Thu Jun 05 16:46:35 UTC 2008</cell>
          <cell></cell>
          <cell></cell>
          <cell></cell>
        </row>
        <row id='7'>
          <cell>esxdev002.localdomain^/host/show/7^_self</cell>
          <cell>esxdev002.localdomain</cell>
          <cell>192.168.177.50</cell>
          <cell>VMware</cell>
          <cell>3.0.2</cell>
          <cell>ESX Server</cell>
          <cell>Thu Jun 05 16:46:34 UTC 2008</cell>
          <cell></cell>
          <cell></cell>
          <cell></cell>
        </row>
        <row id='6'>
          <cell>JFREY-LAPTOP.manageiq.com^/host/show/6^_self</cell>
          <cell>JFREY-LAPTOP.manageiq.com</cell>
          <cell>192.168.252.143</cell>
          <cell>Unknown</cell>
          <cell></cell>
          <cell></cell>
          <cell>Wed Apr 23 19:38:44 UTC 2008</cell>
          <cell></cell>
          <cell></cell>
          <cell></cell>
        </row>
        <row id='4'>
          <cell>luke.manageiq.com^/host/show/4^_self</cell>
          <cell>luke.manageiq.com</cell>
          <cell>192.168.252.32</cell>
          <cell>VMware</cell>
          <cell>3.0.1</cell>
          <cell>ESX Server</cell>
          <cell>Tue Apr 22 15:59:19 UTC 2008</cell>
          <cell></cell>
          <cell></cell>
          <cell></cell>
        </row>
        <row id='5'>
          <cell>yoda.manageiq.com^/host/show/5^_self</cell>
          <cell>yoda.manageiq.com</cell>
          <cell>192.168.252.2</cell>
          <cell>VMware</cell>
          <cell>3.0.1</cell>
          <cell>ESX Server</cell>
          <cell>Tue Apr 22 15:59:20 UTC 2008</cell>
          <cell></cell>
          <cell></cell>
          <cell></cell>
        </row>
      </rows>
    EOL
    xml_string.strip!
  end

  before do
    @xml_klass = Nokogiri::XML
    @xml_string ||= default_test_xml
    @xml = MiqXml.load(@xml_string, :nokogiri)
  end

  it "create document" do
    xml = @xml
    expect(xml).to be_kind_of(@xml_klass::Document)

    #    @xml_klass.load(@xml_string)
    #    expect(xml).to be_kind_of(@xml_klass::Document)
  end

  it "create new doc" do
    xml_new = MiqXml.newDoc(@xml_klass)
    expect(xml_new.root).to be_nil
    xml_new.add_element('root')
    expect(xml_new.root).to_not be_nil
    expect(xml_new.root.name.to_s).to eq("root")

    new_node = xml_new.root.add_element("node1", "enabled" => true, "disabled" => false, "nothing" => nil)

    expect(MiqXml.isXmlElement?(new_node)).to be true
    expect(MiqXml.isXmlElement?(nil)).to be false

    attrs = new_node.attributes
    expect(attrs["enabled"].to_s).to eq("true")
    expect(attrs["disabled"].to_s).to eq("false")
    expect(attrs["nothing"]).to be_nil
    new_node.add_attributes("nothing" => "something")
    expect(new_node.attributes["nothing"].to_s).to eq("something")

    expect(xml_new.document).to be_kind_of(@xml_klass::Document)
    expect(xml_new.doc).to be_kind_of(@xml_klass::Document)
    expect(xml_new.root.class).to_not eq(@xml_klass::Document)
    expect(xml_new.root.doc).to be_kind_of(@xml_klass::Document)
    expect(xml_new.document).to eq(xml_new.doc)
    expect(xml_new.root.doc).to be_kind_of(@xml_klass::Document)
    expect(xml_new.root.root.class).to_not eq(@xml_klass::Document)

    # Create an empty document with the utf-8 encoding
    # During assert allow for single quotes and new line char.
    xml_new = MiqXml.createDoc(nil, nil, nil, @xml_klass)
    expect(xml_new.to_xml.to_s.tr("\"", "'").chomp).to eq("<?xml version='1.0' encoding='UTF-8'?>")
  end

  it "xml encoding" do
    xml_new = @xml
    encoded_xml = MIQEncode.encode(xml_new.to_s)
    expect(encoded_xml).to be_instance_of(String)
    xml_unencoded = MiqXml.decode(encoded_xml, @xml_klass)
    expect(xml_unencoded.to_s).to eq(xml_new.to_s)
  end

  it "#find_each" do
    xml = @xml
    row_order = %w(8 7 6 4 5)
    xml.find_each("//row") do |e|
      expect(e.attributes["id"].to_s).to eq(row_order.delete_at(0))
    end
    expect(row_order.length).to eq(0)
  end

  it "#find_first" do
    xml = @xml
    x = xml.find_first("//row")
    expect(x).to_not be_nil
    expect(x.attributes["id"].to_s).to eq("8")
  end

  it "#find_match" do
    xml = @xml
    x = xml.find_match("//row")
    expect(x).to_not be_nil
    expect(x.length).to eq(5)
    expect(x[0].attributes["id"].to_s).to eq("8")
    expect(x[3].attributes["id"].to_s).to eq("4")
  end

  it "add frozen text" do
    xml = @xml
    expect(xml).to be_kind_of(@xml_klass::Document)

    # frozen_text = "A&P".freeze
    # xml.root.text = frozen_text # Expect to not raise
    # TODO: Fix decoding of special characters
    # expect(xml.root.text).to eq("A&P")
  end

  it "root text" do
    node = @xml.root
    expect(node.node_text.to_s.rstrip).to eq("")
    node.text = "Hello World"
    expect(node.node_text.to_s.rstrip).to eq("Hello World")

    # Make sure adding text does not destroy child elements
    expect(node.has_elements?).to eq(true)
    count = 0
    @xml.root.each_element { |_e| count += 1 }
    expect(count).to eq(6)
  end

  it "cdata" do
    xml = MiqXml.newDoc(@xml_klass)
    xml.add_element('root')

    time = Time.now
    html_text = "<b>#{time}</b>"
    xml.root.add_cdata(html_text.gsub(",", "\\,"))

    expect(xml.to_s).to include("![CDATA[<b>#{time}</b>]]")
    expect(xml.root.text).to eq("<b>#{time}</b>")
  end
end
