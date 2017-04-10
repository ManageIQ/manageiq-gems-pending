require 'util/miq-encode'

require 'active_support/inflector'
require 'more_core_extensions/core_ext/string'

class String
  def miqEncode
    MIQEncode.encode(self)
  end
end
