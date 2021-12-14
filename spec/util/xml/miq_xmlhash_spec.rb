require 'util/miq-xml'
require 'xmlsimple'
require_relative "./shared_examples_for_xml_base_parser"

describe XmlHash do
  context "base parser tests" do
    before do
      @xml_klass = XmlHash
      @xml_string = default_test_xml
      @xml = MiqXml.load(@xml_string, @xml_klass)
    end

    include_examples "xml base parser"

    # Unsupported tests: "#find_each", "#find_first", "#find_match", "#deep_clone"
    # TODO: Fix deletion of elements while looping over them in "node loop and move"

    it "#attributes" do
      xml = @xml
      expect(xml).to be_kind_of(@xml_klass::Document)

      node = xml.root.elements[1].elements[1]
      expect(node.attributes.key?(:type)).to be true

      attrs = xml.root.attributes.to_h
      expect(attrs).to be_kind_of(Hash)
      expect(attrs.length).to eq(0)

      attrs = node.attributes.to_h
      expect(attrs).to be_kind_of(Hash)
      expect(attrs.length).to eq(3)

      count = 0
      node.attributes.each_pair do |k, v|
        expect(k).to_not be_nil
        expect(k).to be_instance_of(Symbol)
        expect(v).to_not be_nil
        expect(v).to be_instance_of(String)
        count += 1
      end
      expect(count).to eq(3)

      count = 0
      node.attributes.to_h.each do |k, v|
        expect(k).to_not be_nil
        expect(k).to be_instance_of(Symbol)
        expect(v).to_not be_nil
        count += 1
      end
      expect(count).to eq(3)

      node.attributes.to_h.each do |k, _v|
        expect(k).to be_instance_of(Symbol)
      end

      #    node.attributes.to_h(true).each do|k,v|
      #      expect(k).to be_instance_of(Symbol)
      #    end
      #
      #    node.attributes.to_h(false).each do|k,v|
      #      expect(k).to be_instance_of(String)
      #    end

      e1 = e2 = node
      e1.attributes.each_pair do |k, v|
        expect(v.to_s != e2.attributes[k]).to be false
      end

      e1.attributes.each_key do |k|
        expect(k).to be_instance_of(Symbol)
      end
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
      # xml_new = MiqXml.createDoc(nil, nil, nil, @xml_klass)
      # TODO: This method does not return the expected empty document header
      # expect(xml_new.to_xml.to_s.gsub("\"", "'").chomp).to eq("<?xml version='1.0' encoding='UTF-8'?>")
    end

    it "create new node" do
      node = MiqXml.newNode("scan_item", @xml_klass)
      expect(node.to_xml.to_s).to eq("<scan_item/>")
      # node = MiqXml.newNode(nil, @xml_klass)
      # TODO: This method does not return the expected empty node text
      # expect(node.to_xml.to_s).to eq("</>")
    end

    it "XmlSimple" do
      simple_xml_text = <<-EOL
      <MiqAeDatastore>
        <MiqAeClass name="AUTOMATE" namespace="EVM">
          <MiqAeSchema>
            <MiqAeField name="discover" aetype="relation" default_value="" display_name="Discovery Relationships"/>
          </MiqAeSchema>
          <MiqAeInstance name="aevent">
            <MiqAeField name="discover">//evm/discover/${//workspace/aevent/type}</MiqAeField>
          </MiqAeInstance>
        </MiqAeClass>
        <MiqAeClass name="DISCOVER" namespace="EVM">
          <MiqAeSchema>
            <MiqAeField name="os" aetype="attribute" default_value=""/>
          </MiqAeSchema>
          <MiqAeInstance name="vm">
            <MiqAeField name="os">this should be a method to get the OS if it is not in the inbound object</MiqAeField>
          </MiqAeInstance>
          <MiqAeInstance name="host">
            <MiqAeField name="os" value="sometimes"/>
          </MiqAeInstance>
        </MiqAeClass>
      </MiqAeDatastore>
      EOL

      h = XmlSimple.xml_in(simple_xml_text)
      h2 = XmlHash.load(simple_xml_text).to_h(:symbols => false)
      expect(h2.inspect.length).to eq(h.inspect.length)

      xml = XmlHash.from_hash(h2, {:rootname => "MiqAeDatastore"})

      expect(xml).to respond_to(:xmlDiff)
      expect(xml).to respond_to(:xmlPatch)
      xml_old = XmlHash.load(simple_xml_text)
      stats = {}
      xml.xmlDiff(xml_old, stats)
      expect(stats[:adds]).to eq(0)
      expect(stats[:deletes]).to eq(0)
      expect(stats[:updates]).to eq(0)
    end

    it "cdata" do
      xml = MiqXml.newDoc(@xml_klass)
      xml.add_element('root')

      time = Time.now
      html_text = "<b>#{time}</b>"
      xml.root.add_cdata(html_text.gsub(",", "\\,"))

      expect(xml.to_xml.to_s).to include("![CDATA[<b>#{time}</b>]]")
      expect(xml.root.text).to eq("<b>#{time}</b>")
    end
  end
end
