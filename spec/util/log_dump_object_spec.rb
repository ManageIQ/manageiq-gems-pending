require 'util/log_dump_object'
require 'util/extensions/miq-array'

describe LogDumpObject do
  before do
    @test_object = Class.new do
      include LogDumpObject
    end.new
  end

  describe '#dump_obj' do
    it "calls .dump_obj" do
      expect(@test_object.class).to receive(:dump_obj)
      @test_object.dump_obj({:param_1 => 1})
    end

    it 'hides passwords' do
      @test_object.dump_obj(
        {:my_password => "secret"},
        "my choices: ",
        :protected => {:path => /[Pp]assword/}
      ) do |obj, prefix|
        expect(obj).to eq("secret")
        expect(prefix).to eq("my choices: [:my_password]")
        expect($log).to receive(:info).with(/ = <PROTECTED>/)
      end
    end
  end

  describe '.dump_obj' do
    it 'accepts a hash' do
      expect(@test_object.class).to receive(:dump_hash)
      @test_object.class.dump_obj({:param_1 => 1}) {}
    end

    it 'accepts an array' do
      expect(@test_object.class).to receive(:dump_array)
      @test_object.class.dump_obj(%w(1 2 3)) {}
    end
  end
end
