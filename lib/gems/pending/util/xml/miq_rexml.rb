require 'time'
require 'rexml/document'
require_relative 'xml_utils'

class MIQRexml
  # MIQ_XML_VERSION = 1.0
  # MIQ_XML_VERSION = 1.1  # Added create_time to root in seconds for easier time conversions
  MIQ_XML_VERSION = 2.0 # Changed sub-xmls, added namespaces

  def self.load(data)
    REXML::Document.load(data)
  end

  def self.loadFile(filename)
    REXML::Document.loadFile(filename)
  end

  def self.createDoc(rootName, rootAttrs = nil, version = MIQ_XML_VERSION)
    REXML::Document.createDoc(rootName, rootAttrs, version)
  end

  def self.getChildAttrib(ele, attrib, default)
    type = nil
    ele.each_element do |e|
      type = e.text if e.attributes['name'] == attrib
      break if type
    end
    type = default if type.nil?
    type
  end

  def self.findElement(path, element)
    findElementInt(path.tr("\\", "/").split("/"), element)
  end

  def self.findRegElement(path, element)
    path_fix_up = path.tr("\\", "/").split("/")
    return XmlHash::XmhHelpers.findRegElementInt(path_fix_up, element) if element.kind_of?(Hash)
    findRegElementInt(path_fix_up, element)
  end

  def self.addObjToXML(parentEle, eleName, obj)
    en = eleName.to_s.gsub(/^((xml)|([0-9]))/, '_\1').tr(' :()<>=', '_')
    if obj.kind_of? Hash
      addHashToXML(parentEle, en, obj)
    elsif obj.kind_of? Array
      addArrayToXML(parentEle, en, obj)
    else
      e = parentEle.add_element en
      e.add_text(obj.to_s)
    end
  end

  def self.addHashToXML(parentEle, eleName, hash)
    ele = parentEle.add_element eleName
    hash.each { |k, v| addObjToXML(ele, k.to_s, v) }
  end

  def self.addArrayToXML(parentEle, eleName, array)
    array.each { |v| addObjToXML(parentEle, eleName, v) }
  end

  private

  def self.findRegElementInt(paths, ele)
    if paths.length > 0
      searchStr = paths[0].downcase
      paths = paths[1..paths.length]
      # puts "Search String: #{searchStr}"
      ele.each_element do |e|
        # puts "Current String: [#{e.name.downcase}] [#{e.attributes['keyname']}] [#{e.attributes['name']}]"
        if e.name.downcase == searchStr || (!e.attributes['keyname'].nil? && e.attributes['keyname'].downcase == searchStr) || (!e.attributes['name'].nil? && e.attributes['name'].downcase == searchStr)
          # puts "String Found: [#{e.name}] [#{e.attributes['name']}]"
          return findRegElementInt(paths, e)
        end # if
      end # do
      return nil if paths.length == 0
    else
      return ele
    end
  end

  def self.findElementInt(paths, ele)
    if paths.length > 0
      searchStr = paths[0]
      paths = paths[1..paths.length]
      # puts "Search String: #{searchStr}"
      ele.each_element do |e|
        # puts "Current String: [#{e.name.downcase}]"
        if e.name.downcase == searchStr.downcase
          # puts "String Found: [#{e.name}]"
          return findElementInt(paths, e)
        end # if
      end # do

      # Add all remaining paths and return the final one
      eNew = ele.add_element(searchStr)
      paths.each { |e| eNew = eNew.add_element(e) }
      return eNew
    else
      return ele
    end
  end
end

module REXML
  class Attributes
    def to_h(use_symbols = true)
      ret = {}
      each { |name, value| ret[use_symbols ? name.to_sym : name] = value }
      ret
    end

    alias_method :each_attrib, :each

    alias_method :bracket_orig, :[]

    def [](name)
      # Support symbols
      bracket_orig(name.to_s)
    end
  end

  class Attribute
    def initialize(first, second = nil, parent = nil)
      @normalized = @unnormalized = @element = nil
      if first.kind_of? Attribute
        self.name = first.expanded_name
        @value = first.value
        # This line is to support REXML shipped with version 1.8.6 patch 111 and above
        @unnormalized = first.value
        if second.kind_of? Element
          @element = second
        else
          @element = first.element
        end
      elsif first.kind_of? String
        @element = parent if parent.kind_of? Element
        self.name = first
        # This is the old method that does not handle HTML encoded strings properly
        # @value = second.to_s
        begin
          @value = Text.unnormalize(second.to_s, nil)
        rescue => err
          if err.class == ::Encoding::CompatibilityError
            second_utf8 = second.to_s.dup.force_encoding('UTF-8').encode('UTF-8', :invalid => :replace, :undef => :replace, :replace => '')
            @value = Text.unnormalize(second_utf8)
          else
            $log.error "Encoding error: #{second_utf8}" if $log
          end
        end
        # This line is to support REXML shipped with version 1.8.6 patch 111 and above
        @normalized = second.to_s
      else
        raise "illegal argument #{first.class.name} to Attribute constructor"
      end
    end
  end

  #
  class Element
    def get_path
      p = parent
      head = nil
      until p.name.empty?
        # Create a "shallow copy" of the current element (does not copy child elements)
        newEle = p.shallow_copy(false)

        if head.nil?
          head = newEle
        else
          newEle << head
          head = newEle
        end

        p = p.parent
      end
      head
    end

    def shallow_copy(include_text = true)
      newEle = REXML::Element.new(self)
      newEle.text = text if include_text
      newEle
    end

    def remove!
      parent.delete(self)
    end

    def find_first(xpath, ns = nil)
      REXML::XPath.first(self, xpath, ns)
    end

    def find_each(name, &blk)
      REXML::XPath.each(self, name, &blk)
    end

    def find_match(name, &blk)
      REXML::XPath.match(self, name, &blk)
    end

    alias_method :doc, :document

    def new_cdata(text)
      REXML::CData.new(text)
    end

    def add_cdata(text)
      self << REXML::CData.new(text.to_s)
    end

    def to_xml
      self
    end

    # Override add_element and add_attribute(s) so we can pass symbols
    alias_method :add_element_orig, :add_element
    def add_element(element, attrs = nil)
      return add_element_orig(element) if element.kind_of?(REXML::Element)
      attrs.delete_if { |_k, v| v.nil? } unless attrs.nil?
      add_element_orig(element.to_s, XmlHelpers.validate_attrs(attrs))
    end

    alias_method :add_attribute_orig, :add_attribute
    def add_attribute(key, value)
      value_utf8 = value.to_s.dup.force_encoding('UTF-8').encode('UTF-8', :invalid => :replace, :undef => :replace, :replace => '') unless value.nil?
      add_attribute_orig(key.to_s, value_utf8) unless value_utf8.nil?
    end

    alias_method :add_attributes_orig, :add_attributes
    def add_attributes(attr_hash)
      return unless attr_hash
      attr_hash.each_pair { |k, v| add_attribute(k, v) }
    end

    def key_type
      String
    end

    def self.newNode(data = nil)
      new(data)
    end

    # The write method on the Element class was deprecated largely because not everyone was
    # happy with the default format.  (Note: It is not deprecated on the Document class.)
    # See Sean E. Russell's post here: http://www.ruby-forum.com/topic/139143
    alias_method :write_orig, :write
    def write(output = $stdout, indent = -1, transitive = false, ie_hack = false)
      return write_orig(output, indent, transitive, ie_hack) unless defined?(REXML::Formatters)
      formatter = if indent > -1
                    if transitive
                      REXML::Formatters::Transitive.new(indent, ie_hack)
                    else
                      REXML::Formatters::Pretty.new(indent, ie_hack)
                    end
                  else
                    REXML::Formatters::Default.new(ie_hack)
                  end
      formatter.write(self, output)
    end
  end

  class Document
    include MiqXmlDiff
    include MiqXmlPatch

    # MIQ_XML_VERSION = 1.0
    # MIQ_XML_VERSION = 1.1  # Added create_time to root in seconds for easier time conversions
    MIQ_XML_VERSION = 2.0 # Changed sub-xmls, added namespaces

    alias_method :initialize_orig, :initialize

    def initialize(args)
      initialize_orig(args)
    end

    def extendXmlDiff; end

    def self.load(data)
      REXML::Document.new(data)
    end

    def self.loadFile(filename)
      f = nil
      f = File.open(filename, "r")
      load(f)
    ensure
      f.close if f
    end

    def self.createDoc(rootName, rootAttrs = nil, version = MIQ_XML_VERSION)
      xml = rootName.kind_of?(Symbol) ? REXML::Document.new("<#{rootName}/>") : REXML::Document.new(rootName)
      xml << XMLDecl.new(1.0, "UTF-8")
      if xml.root
        xml.root.add_attributes(
          "version"      => version,
          "created_on"   => Time.now.to_i,
          "display_time" => Time.now.getutc.iso8601,
        # TODO: Namespaces are causing an error during find_first below,
        #        namely during MIQExtract and the extraction of product keys
        #           "xmlns" => "http://www.manageiq.com/xsd",
        #           "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
        #           "xsi:schemaLocation" => "http://www.manageiq.com/xsd",
        )
        xml.root.add_attributes(rootAttrs) if rootAttrs
      end
      xml
    end

    def self.newDoc
      REXML::Document.new(nil)
    end

    def self.decode(encodedText)
      return REXML::Document.new(MIQEncode.decode(encodedText)) if encodedText
      REXML::Document.new("")
    end

    def find_first(xpath, ns = nil)
      REXML::XPath.first(self, xpath, ns)
    end

    def find_each(name, &blk)
      REXML::XPath.each(self, name, &blk)
    end

    def deep_clone
      write(buf = '', -1, true)
      self.class.load(buf)
    end

    def self.newNode(data = nil)
      REXML::Element.new(data)
    end

    def root=(element)
      elements[1] = element
    end

    def to_xml
      self
    end
  end
end
