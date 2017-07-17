require 'util/extensions/miq-hash'

# Subclass of String to test []= substring complex key patch
class SubString < String
  attr_accessor :sub_str
end

describe Hash do
  it '#[]= with a substring key' do
    s = SubString.new("string")
    s.sub_str = "substring"

    h = {}
    h[s] = "test"
    s2 = h.keys.first

    expect(s2).to eq(s)
    expect(s2.sub_str).to eq(s.sub_str)
  end
end
