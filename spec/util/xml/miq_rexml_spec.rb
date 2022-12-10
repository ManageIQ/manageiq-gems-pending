require_relative "./shared_examples_for_xml_base_parser"

describe MIQRexml do
  context "base parser tests" do
    before do
      @xml_klass = REXML
      @xml_string ||= default_test_xml
      @xml = MiqXml.load(@xml_string, @xml_klass)
    end

    include_examples "xml base parser"

    it "#find_each" do
      xml = @xml
      row_order = %w[8 7 6 4 5]
      REXML::XPath.each(xml, "//row") do |e|
        expect(e.attributes["id"]).to eq(row_order.delete_at(0))
      end
      expect(row_order.length).to eq(0)

      row_order = %w[8 7 6 4 5]
      xml.find_each("//row") do |e|
        expect(e.attributes["id"]).to eq(row_order.delete_at(0))
      end
      expect(row_order.length).to eq(0)
    end

    it "#find_first" do
      xml = @xml
      x = REXML::XPath.first(xml, "//row")
      expect(x).to_not be_nil
      expect(x.attributes["id"]).to eq("8")

      x = xml.find_first("//row")
      expect(x).to_not be_nil
      expect(x.attributes["id"]).to eq("8")
    end

    it "#find_match" do
      xml = @xml
      x = REXML::XPath.match(xml, "//row")
      expect(x).to_not be_nil
      expect(x.length).to eq(5)
      expect(x[0].attributes["id"]).to eq("8")
      expect(x[3].attributes["id"]).to eq("4")

      x = xml.find_match("//row")
      expect(x).to_not be_nil
      expect(x.length).to eq(5)
      expect(x[0].attributes["id"]).to eq("8")
      expect(x[3].attributes["id"]).to eq("4")
    end

    it "#deep_clone" do
      xml = @xml
      xml2 = xml.deep_clone
      expect(xml2.object_id).to_not eq(xml.object_id)
      xml.write(xml_str1 = '')
      xml2.write(xml_str2 = '')
      expect(xml_str2).to eq(xml_str1)
    end

    it "#attributes" do
      xml = @xml
      expect(xml).to be_kind_of(@xml_klass::Document)

      node = xml.find_first("//column")
      expect(node.attributes.key?("type")).to be true

      attrs = xml.root.attributes.to_h
      expect(attrs).to be_kind_of(Hash)
      expect(attrs.length).to eq(0)

      attrs = node.attributes.to_h
      expect(attrs).to be_kind_of(Hash)
      expect(attrs.length).to eq(3)

      count = 0
      node.attributes.each_attrib do |k, v|
        expect(k).to_not be_nil
        expect(k).to be_instance_of(String)
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

      node.attributes.to_h(true).each do |k, _v|
        expect(k).to be_instance_of(Symbol)
      end

      node.attributes.to_h(false).each do |k, _v|
        expect(k).to be_instance_of(String)
      end

      e1 = e2 = node
      e1.attributes.each_pair do |k, v|
        expect(v.to_s != e2.attributes[k]).to be false
      end

      e1.attributes.each_key do |k|
        expect(k).to be_instance_of(String)
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
      xml_new = MiqXml.createDoc(nil, nil, nil, @xml_klass)
      expect(xml_new.to_xml.to_s.tr("\"", "'").chomp).to eq("<?xml version='1.0' encoding='UTF-8'?>")
    end

    it "create new node" do
      node = MiqXml.newNode("scan_item", @xml_klass)
      expect(node.to_xml.to_s).to eq("<scan_item/>")
      node = MiqXml.newNode(nil, @xml_klass)
      expect(node.to_xml.to_s).to eq("</>")
    end

    it "node loop and move" do
      xml_full = @xml
      xml_part = MiqXml.load("<root/>", @xml_klass)

      count = 0
      xml_full.root.each_element do |e|
        xml_part.root << e
        count += 1
      end

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

  def check_element(element, value, encoded_value)
    expect(element.attributes["test_attr_str"]).to eq(value)
    x = element.attributes.get_attribute("test_attr_str")
    expect(x.to_s).to eq(encoded_value)
    expect(x.value).to eq(value)
  end

  it "properly handles html encoding" do
    xml_type = REXML
    test_string = "This ain't no way to do it & we don't know how"
    encoded_string = "This ain&apos;t no way to do it &amp; we don&apos;t know how"
    test_int = 200

    # Create an XML document
    xml = MiqXml.load("<test/>", xml_type)
    expect(xml).to be_instance_of(REXML::Document)

    # Load up all the data.  (Create a new elemenat with an attribute and text)
    xml.root.add_element("test_element", "test_attr_str" => test_string, "test_attr_int" => test_int).text = test_string
    check_element(xml.root.elements[1], test_string, encoded_string)

    # Make sure we were able to set an integer and get it back
    # Everything in xml is a string, so test base value and converted to_i value.
    expect(xml.root.elements[1].attributes["test_attr_int"]).to eq(test_int.to_s)
    expect(xml.root.elements[1].attributes["test_attr_int"].to_i).to eq(test_int)

    # This is where the encoding was messed up.  If we write the data out (to a string or file)
    # it would not encode the attributes and the encoded elements would get doubled up
    # when asking for the attribute back.
    1.upto(5) do |_i|
      data = ""
      xml.write(data, 0)
      xml = MiqXml.load(data, xml_type)
      expect(xml).to be_instance_of(REXML::Document)
      check_element(xml.root.elements[1], test_string, encoded_string)
    end
  end

  it "handles attribute encoding" do
    xml = REXML::Document.new("<test/>")
    attr_string = "string \xC2\xAE"
    xml.root.add_element("element_1", 'attr1' => attr_string)
    expect(xml.root.elements[1].attributes['attr1']).to eq(attr_string)
  end
end
