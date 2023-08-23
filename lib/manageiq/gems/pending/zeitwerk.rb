require "zeitwerk"
loader = Zeitwerk::Loader.for_gem_extension(ManageIQ::Gems::Pending)
loader.ignore(__FILE__)

# For straight requires from here
lib = File.expand_path("#{__dir__}../../../../")
loader.push_dir("#{lib}/gems/pending/util")

# This tells the loader to not expect Mount or ObjectStorage namespaces...
loader.collapse("#{lib}/gems/pending/util/mount")
loader.collapse("#{lib}/gems/pending/util/object_storage")
loader.collapse("#{lib}/gems/pending/util/win32")
loader.collapse("#{lib}/gems/pending/util/xml")

# These files skip zeitwerk and must be required manually
##### TODO: check for requires outside of this gem to these files and util/ in requires
loader.ignore("#{lib}/gems/pending/util/miq-extensions.rb")       # loader file, no class
loader.ignore("#{lib}/gems/pending/util/require_with_logging.rb") # file has no class ;-)
loader.ignore("#{lib}/gems/pending/util/xml/miq_nokogiri.rb")     # monkey patch, so no class
loader.ignore("#{lib}/gems/pending/util/xml/xml_utils.rb")        # multiple classes in one file

# These inflectors teach zeitwerk our naming convention here
loader.inflector.inflect(
  "version" => "VERSION" # TODO: why is this needed, for_gem_extension is supposed to do this
)

# These inflectors are teaching zeitwerk when we fail at conventions.
# It expects downcased and underscored file names (not hyphens).
# TODO: These could be fixed but require changing client code to use the new constant.
loader.inflector.inflect(
  "miq-encode"      => "MIQEncode",
  "miq-exception"   => "MiqException",
  "miq-hash_struct" => "MiqHashStruct",
  "miq-ipmi"        => "MiqIPMI",
  "miq-powershell"  => "MiqPowerShell",
  "miq-process"     => "MiqProcess",
  "miq-system"      => "MiqSystem",
  "miq-wmi"         => "WMIHelper", # WAT
  "miq-wmi-linux"   => "WmiLinux",
  "miq-wmi-mswin"   => "WmiMswin",
  "miq-xml"         => "MiqXml",
  "miq_rexml"       => "MIQRexml",
  "xml_diff"        => "MiqXmlDiff",
  "xml_patch"       => "MiqXmlPatch"
)

loader.setup

# TODO: consider turning on eager_load and only disable really slow/fat requires
# loader.eager_load
