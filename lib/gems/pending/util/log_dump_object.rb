require 'active_support/concern'

module LogDumpObject
  extend ActiveSupport::Concern

  module ClassMethods
    def dump_obj(obj, prefix = nil, &block)
      meth = "dump_#{obj.class.name.underscore}".to_sym

      if self.respond_to?(meth)
        return send(meth, obj, prefix, &block)
      end

      yield obj, prefix
    end

    def dump_hash(hd, prefix, &block)
      hd.each { |k, v| dump_obj(v, "#{prefix}[#{k.inspect}]", &block) }
    end

    def dump_array(ad, prefix, &block)
      ad.each_with_index { |d, i| dump_obj(d, "#{prefix}[#{i}]", &block) }
    end
  end

  def dump_obj(obj, prefix = nil, options = {})
    self.class.dump_obj(obj, prefix) do |val, prefix|
      value = val
      if options.try(:protected).try(:path).to_miq_a.any? { |filter| prefix =~ filter }
        value = "<PROTECTED>"
      end
      $log.info("#{prefix}(#{val.class}) = #{value.inspect}")
    end
  end
end
