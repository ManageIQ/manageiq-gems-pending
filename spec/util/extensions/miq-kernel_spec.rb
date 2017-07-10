require 'util/extensions/miq-kernel'

describe Kernel do
  it ".require_relative" do
    expect(Kernel.respond_to?(:require_relative)).to be_truthy
  end
end
