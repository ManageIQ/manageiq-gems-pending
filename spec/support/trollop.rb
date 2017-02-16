require 'active_support/core_ext/string/strip'
require 'trollop'

class TrollopEducateSpecError < StandardError; end
class TrollopDieSpecError < StandardError; end

RSpec.configure do |config|
  config.before(:each) do
    err_string = <<-EOF.strip_heredoc
      Don't allow methods that exit the calling process to be executed in specs.
      If you were testing that we call Trollop.educate or Trollop.die, expect that a TrollopEducateSpecError or TrollopDieSpecError be raised instead
    EOF
    allow(Trollop).to receive(:educate).and_raise(TrollopEducateSpecError.new(err_string))
    allow(Trollop).to receive(:die).and_raise(TrollopDieSpecError.new(err_string))
  end
end
