describe MiqXml do
  it "handles loaded document encoding" do
    attr_string = "string \xC2\xAE"
    doc_text = "<test><element_1 attr1='#{attr_string}'/></test>"
    xml = MiqXml.load(doc_text)
    expect(xml.root.elements[1].attributes['attr1']).to eq(attr_string)
  end

  it "handles loaded document with UTF-8 BOM" do
    attr_string = "test string"
    doc_text = "\xC3\xAF\xC2\xBB\xC2\xBF<test><element_1 attr1='#{attr_string}'/></test>"
    xml = MiqXml.load(doc_text)
    expect(xml.root.elements[1].attributes['attr1']).to eq(attr_string)

    expect(xml.to_s[0, 3]).to eq("\xC3\xAF\xC2\xBB\xC2\xBF")
    xml.write(xml_str = '', 1)
    expect(xml_str[0, 3]).to eq("\xC3\xAF\xC2\xBB\xC2\xBF")
  end

  it "add_element with control characters" do
    attr_hash = {"attr1" => "test\u000Fst\u001Fring"}
    doc = MiqXml.createDoc(nil)
    doc.add_element('element_1', attr_hash)
    expect(doc.elements[1].attributes['attr1']).to eq("teststring")
  end
end
