describe MiqXml do
  it "handles loaded document encoding" do
    attr_string = "string \xC2\xAE"
    doc_text = "<test><element_1 attr1='#{attr_string}'/></test>"
    xml = MiqXml.load(doc_text)
    expect(xml.root.elements[1].attributes['attr1']).to eq(attr_string)
  end

  it "handles loaded document with UTF-8 BOM" do
    bom = "\xEF\xBB\xBF".force_encoding("US-ASCII")
    attr_string = "test string"
    doc_text = "#{bom}<test><element_1 attr1='#{attr_string}'/></test>".force_encoding("US-ASCII")
    expect(doc_text.bytes[0, 3]).to eq(bom.bytes)

    xml = MiqXml.load(doc_text)
    expect(xml.root.elements[1].attributes['attr1']).to eq(attr_string)

    expect(xml.to_s.bytes[0, 3]).to_not eq(bom.bytes)
    expect(xml.to_s).to start_with("<test><element_1")

    xml.write(xml_str = '', 1)
    expect(xml_str.bytes[0, 3]).to_not eq(bom.bytes)
    expect(xml_str).to start_with("<test>\n <element_1")
  end

  it "add_element with control characters" do
    attr_hash = {"attr1" => "test\u000Fst\u001Fring"}
    doc = MiqXml.createDoc(nil)
    doc.add_element('element_1', attr_hash)
    expect(doc.elements[1].attributes['attr1']).to eq("teststring")
  end
end
