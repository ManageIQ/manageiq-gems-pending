shared_examples_for "xml base parser" do
  def default_test_xml
    xml_string = <<-XML
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
    XML
    xml_string.strip!
  end

  it "create document" do
    xml = @xml
    expect(xml).to be_kind_of(@xml_klass::Document)

    #    @xml_klass.load(@xml_string)
    #    expect(xml).to be_kind_of(@xml_klass::Document)
  end

  it "#each_element" do
    xml = @xml

    count = 0
    xml.each_element { |_e| count += 1 }
    expect(count).to eq(1)

    # Test each method with and without xpaths
    count = 0
    xml.root.each_element { |_e| count += 1 }
    expect(count).to eq(6)

    count = 0
    xml.root.each_element("head") { |_e| count += 1 }
    expect(count).to eq(1)

    count = 0
    xml.root.each_element("row") { |_e| count += 1 }
    expect(count).to eq(5)

    count = 0
    xml.root.elements.each { |_e| count += 1 }
    expect(count).to eq(6)
  end

  it "#has_elements?" do
    node = @xml.root
    expect(node.name.to_s).to eq('rows')
    expect(node.has_elements?).to be true

    node = node.elements[1]
    expect(node.name.to_s).to eq('head')
    expect(node.has_elements?).to be true

    node = node.elements[1]
    expect(node.name.to_s).to eq('column')
    expect(node.has_elements?).to be false
  end

  # Moving xml nodes between documents is a feature required for differencing
  it "move node" do
    xml_full = MiqXml.load(@xml_string, @xml_klass)
    xml_part = MiqXml.load("<root/>", @xml_klass)
    xml_part.root << xml_full.root.elements[2]

    count = 0
    full_ids = []
    xml_full.root.each_element { |e| count += 1; full_ids << e.attributes["id"] }
    expect(count).to eq(5)

    count = 0
    xml_part.root.each_element { |_e| count += 1 }
    expect(count).to eq(1)

    expect(xml_part.root.elements[1].attributes["id"]).to eq("8")
    expect(full_ids).to_not include("8")

    # Re-assign root document value
    doc = MiqXml.load(@xml_string, @xml_klass)
    doc.root = doc.root.elements[1].elements[1]

    expect(doc.root.name.to_s).to eq("column")
    expect(doc.root.attributes[:type]).to eq("link")
  end

  it "doc root reassignment" do
    # Re-assign root document value
    doc = MiqXml.load(@xml_string, @xml_klass)
    doc.root = doc.root.elements[1].elements[1]
    GC.start  # Required by libxml to avoid core dump

    expect(doc.root.name.to_s).to eq("column")
    expect(doc.root.attributes["type"].to_s).to eq("link")
  end

  it "root text" do
    node = @xml.root
    expect(node.text.to_s.rstrip).to eq("")
    node.text = "Hello World"
    expect(node.text.to_s.rstrip).to eq("Hello World")

    # Make sure adding text does not destroy child elements
    expect(node.has_elements?).to be true
    count = 0
    @xml.root.each_element { |_e| count += 1 }
    expect(count).to eq(6)
  end

  it "diff" do
    xml = MiqXml.newDoc(@xml_klass)
    expect(xml).to respond_to(:xmlDiff)
    expect(xml).to respond_to(:xmlPatch)

    stats = {}

    xml_old = MiqXml.load(@xml_string, @xml_klass)
    xml_new = MiqXml.load(@xml_string, @xml_klass)
    xml_diff = xml_new.xmlDiff(xml_old, stats)
    expect(stats[:adds]).to eq(0)
    expect(stats[:deletes]).to eq(0)
    expect(stats[:updates]).to eq(0)

    # Reload document and simulate a deleted node
    xml_old = MiqXml.load(@xml_string, @xml_klass)
    xml_new = MiqXml.load(@xml_string, @xml_klass)
    node = xml_new.root.elements[3]
    expect(node.attributes[:id]).to eq("7")
    node.remove!
    xml_diff = xml_new.xmlDiff(xml_old, stats)

    expect(stats[:adds]).to eq(0)
    expect(stats[:deletes]).to eq(1)
    expect(stats[:updates]).to eq(0)

    # Reload document and simulate an added node
    xml_old = MiqXml.load(@xml_string, @xml_klass)
    xml_new = MiqXml.load(@xml_string, @xml_klass)
    node = xml_new.root.add_element("added_test_element", :id => 10)
    xml_diff = xml_new.xmlDiff(xml_old, stats)
    expect(stats[:adds]).to eq(1)
    expect(stats[:deletes]).to eq(0)
    expect(stats[:updates]).to eq(0)

    # Reload document and simulate an update to a node with a changed attribute value
    xml_old = MiqXml.load(@xml_string, @xml_klass)
    xml_new = MiqXml.load(@xml_string, @xml_klass)
    node = xml_new.root.elements[1].elements[1]
    expect(node.attributes[:type]).to eq("link")
    node.add_attribute(:width, "11")
    xml_diff = xml_new.xmlDiff(xml_old, stats)
    expect(stats[:adds]).to eq(0)
    expect(stats[:deletes]).to eq(0)
    expect(stats[:updates]).to eq(1)

    # Reload document and simulate an update to a node with a new attribute
    xml_old = MiqXml.load(@xml_string, @xml_klass)
    xml_new = MiqXml.load(@xml_string, @xml_klass)
    node = xml_new.root.elements[1].elements[1]
    expect(node.attributes[:type]).to eq("link")
    node.add_attribute(:test_attr, "hello there")
    xml_diff = xml_new.xmlDiff(xml_old, stats)
    expect(stats[:adds]).to eq(0)
    expect(stats[:deletes]).to eq(0)
    expect(stats[:updates]).to eq(1)

    # Reload document and simulate an update to a node with a deleted attribute
    xml_old = MiqXml.load(@xml_string, @xml_klass)
    xml_new = MiqXml.load(@xml_string, @xml_klass)
    node = xml_new.root.elements[1].elements[1]
    expect(node.attributes[:type]).to eq("link")
    node.attributes.delete(:sort)
    node.attributes.delete("sort")
    xml_diff = xml_new.xmlDiff(xml_old, stats)
    expect(stats[:adds]).to eq(0)
    expect(stats[:deletes]).to eq(0)
    expect(stats[:updates]).to eq(1)
  end

  it "patch" do
    expect(@xml).to respond_to(:xmlDiff)
    expect(@xml).to respond_to(:xmlPatch)

    stats = {}

    # Reload document and simulate a deleted node
    xml_old = MiqXml.load(@xml_string, @xml_klass)
    xml_new = MiqXml.load(@xml_string, @xml_klass)
    node = xml_new.root.elements[3]
    expect(node.attributes[:id]).to eq("7")
    node.remove!
    xml_diff = xml_new.xmlDiff(xml_old, stats)
    expect(stats[:adds]).to eq(0)
    expect(stats[:deletes]).to eq(1)
    expect(stats[:updates]).to eq(0)

    xml_old = MiqXml.load(@xml_string, @xml_klass)
    xml_new = MiqXml.load(@xml_string, @xml_klass)
    node = xml_new.root.elements[3]
    expect(node.attributes[:id]).to eq("7")
    node.remove!
    patch_ret = xml_old.xmlPatch(xml_diff)
    expect(patch_ret[:errors]).to eq(0)

    xml_diff = xml_new.xmlDiff(xml_old, stats)
    expect(stats[:adds]).to eq(0)
    expect(stats[:deletes]).to eq(0)
    expect(stats[:updates]).to eq(0)

    # Reload document and simulate an added node
    xml_old = MiqXml.load(@xml_string, @xml_klass)
    xml_new = MiqXml.load(@xml_string, @xml_klass)
    node = xml_new.root.elements[3]
    expect(node.attributes[:id]).to eq("7")
    node.add_element("new_test_node", "attr1" => "one")
    xml_diff = xml_new.xmlDiff(xml_old, stats)
    expect(stats[:adds]).to eq(1)
    expect(stats[:deletes]).to eq(0)
    expect(stats[:updates]).to eq(0)

    xml_old = MiqXml.load(@xml_string, @xml_klass)
    xml_new = MiqXml.load(@xml_string, @xml_klass)
    node = xml_new.root.elements[3]
    expect(node.attributes[:id]).to eq("7")
    node.add_element("new_test_node", "attr1" => "one")
    patch_ret = xml_old.xmlPatch(xml_diff)
    expect(patch_ret[:errors]).to eq(0)

    xml_diff = xml_new.xmlDiff(xml_old, stats)
    expect(stats[:adds]).to eq(0)
    expect(stats[:deletes]).to eq(0)
    expect(stats[:updates]).to eq(0)

    # Reload document and simulate an updated node
    xml_old = MiqXml.load(@xml_string, @xml_klass)
    xml_new = MiqXml.load(@xml_string, @xml_klass)
    node = xml_new.root.elements[3]
    expect(node.attributes[:id]).to eq("7")
    node.add_attribute("new_test_node", "attr1" => "one")
    xml_diff = xml_new.xmlDiff(xml_old, stats)
    expect(stats[:adds]).to eq(0)
    expect(stats[:deletes]).to eq(0)
    expect(stats[:updates]).to eq(1)

    xml_old = MiqXml.load(@xml_string, @xml_klass)
    xml_new = MiqXml.load(@xml_string, @xml_klass)
    node = xml_old.root.elements[3]
    expect(node.attributes[:id]).to eq("7")
    node.add_attribute("new_test_node", "attr1" => "one")
    patch_ret = xml_old.xmlPatch(xml_diff, -1)
    expect(patch_ret[:errors]).to eq(0)

    xml_diff = xml_new.xmlDiff(xml_old, stats)
    expect(stats[:adds]).to eq(0)
    expect(stats[:deletes]).to eq(0)
    expect(stats[:updates]).to eq(0)
  end

  #  it "load file" do
  #    # TODO: Load file test
  #  end

  it "root pointer" do
    xml = MiqXml.load(@xml_string, @xml_klass)
    node = xml.elements[1].elements[1].elements[11].elements[1]
    while node
      if node.parent
        if @xml_klass == Nokogiri::XML
          expect(node).to be_kind_of(@xml_klass::Node)
        else
          expect(node).to be_kind_of(@xml_klass::Element)
        end
      else
        expect(node).to be_kind_of(@xml_klass::Document)
      end
      node = node.parent
    end
  end

  it "missing attribute" do
    # Validate that nil is return for attributes that do not exist
    e = @xml.root.elements[2]
    expect(e.attributes['id']).to eq('8')
    expect(e.attributes['none']).to be_nil
  end

  it "get element" do
    xml = @xml
    node = xml.elements[1]
    expect(node.name.to_s).to eq("rows")

    node = xml.elements[1].elements[1]
    expect(node.name.to_s).to eq("head")

    node = xml.elements[1].elements[1].elements[11].elements[1]
    expect(node.name.to_s).to eq("colwidth")

    # Test getting individual sub-elements
    node = xml.root.elements[1]
    expect(node.attributes["id"]).to be_nil

    node = xml.root.elements[1]
    expect(node.attributes["id"]).to be_nil

    node = xml.root.elements[3]
    expect(node.attributes["id"].to_s).to eq("7")

    node = xml.root.elements[6]
    expect(node.attributes["id"].to_s).to eq("5")

    expect { xml.root.elements[0] }.to raise_error(RuntimeError)

    expect(xml.root.elements[7]).to be_nil

    head = xml.root.elements[1]
    expect(head.name.to_s).to eq("head")

    count = 0
    head.each_element { |_e| count += 1 }
    expect(count).to eq(11)

    count = 0
    head.each_element("settings") { |_e| count += 1 }
    expect(count).to eq(1)

    node = xml.root.elements[3]
    node2 = xml.root.elements[4]
    copied_node = node.elements << node2
    expect(copied_node.parent.attributes["id"].to_s).to eq("7")

    # Test that node (id=6) is now inside of node id=7
    node = xml.root.elements[3]
    expect(node.attributes["id"].to_s).to eq("7")
    node2 = node.elements[11]
    expect(node2.attributes["id"].to_s).to eq("6")
  end

  it "xml encoding" do
    xml_new = @xml
    encoded_xml = MIQEncode.encode(xml_new.to_s)
    expect(encoded_xml).to be_instance_of(String)
    xml_unencoded = MiqXml.decode(encoded_xml, @xml_klass)
    expect(xml_unencoded.to_xml.to_s).to eq(xml_new.to_xml.to_s)
  end

  it "delete node" do
    delete_node_helper(@xml_klass) do |node, _root|
      node.remove!
    end

    delete_node_helper(@xml_klass) do |node, root|
      root.delete_element(node)
    end
  end

  def delete_node_helper(xml_klass)
    xml = MiqXml.load(@xml_string, @xml_klass)
    expect(xml).to be_kind_of(xml_klass::Document)

    attr_ids = []
    xml.root.elements.each { |e| attr_ids << e.attributes[:id] }
    expect(attr_ids.length).to eq(6)

    # Delete each element attached to the root node until all are removed.
    while attr_ids.length > 0
      # Get the first element
      del_node = xml.root.elements[1]

      # Yield to the method that will do the deletion
      yield(del_node, xml.root)

      removed_id = attr_ids.delete_at(0)
      expect(del_node.attributes[:id]).to eq(removed_id)

      count = 0
      xml.root.elements.each { |_e| count += 1 }
      expect(attr_ids.length).to eq(count)
    end
  end

  it "add frozen text" do
    xml = @xml
    expect(xml).to be_kind_of(@xml_klass::Document)

    frozen_text = "A&P".freeze
    xml.root.text = frozen_text
    expect(xml.root.text).to eq("A&P")
  end

  it "#write" do
    # Test writing from the document
    @xml.write(test_string = "")
    expect(test_string).to_not eq("")
    test_string = @xml.to_s
    expect(test_string).to_not eq("")

    # Test writing from an element
    @xml.root.write(test_string = "")
    expect(test_string).to_not eq("")
    test_string = @xml.root.to_s
    expect(test_string).to_not eq("")
  end
end
