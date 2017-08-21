require 'util/extensions/miq-benchmark'
require 'timecop'
require 'timeout'

describe Benchmark do
  after(:each) { Timecop.return }
  after(:each) do
    # Isolate other tests
    Benchmark.delete_current_realtime if Benchmark.in_realtime_block?
  end

  it '.realtime_store' do
    timings = {}
    result = Benchmark.realtime_store(timings, :test1) do
      Timecop.travel(500)
      Benchmark.realtime_store(timings, :test2) do
        Timecop.travel(500)
        Benchmark.realtime_store(timings, :test3) do
          Timecop.travel(500)
        end
      end
      "test"
    end
    expect(result).to eq("test")
    expect(timings[:test1]).to be_within(0.5).of(1500)
    expect(timings[:test2]).to be_within(0.5).of(1000)
    expect(timings[:test3]).to be_within(0.5).of(500)
  end

  it '.realtime_store with an Exception' do
    timings = {}
    begin
      Benchmark.realtime_store(timings, :test1) do
        Timecop.travel(500)
        raise Exception
      end
    rescue Exception
      expect(timings[:test1]).to be_within(0.5).of(500)
    end
  end

  it '.realtime_block' do
    result, timings = Benchmark.realtime_block(:test1) do
      Timecop.travel(500)
      Benchmark.realtime_block(:test2) do
        Timecop.travel(500)
        Benchmark.realtime_block(:test3) do
          Timecop.travel(500)
        end
      end
      "test"
    end
    expect(result).to eq("test")
    expect(timings[:test1]).to be_within(0.5).of(1500)
    expect(timings[:test2]).to be_within(0.5).of(1000)
    expect(timings[:test3]).to be_within(0.5).of(500)
  end

  it '.in_realtime_block?' do
    expect(Benchmark.in_realtime_block?).to be_falsey
    Benchmark.realtime_block(:test1) do
      expect(Benchmark.in_realtime_block?).to be_truthy
    end
    expect(Benchmark.in_realtime_block?).to be_falsey
  end

  it "Timeout raising within .realtime_block" do
    expect(Benchmark.in_realtime_block?).to be_falsey

    places_outcomes = {}
    1000.times do |i|
      begin
        # keep entering/exiting, abort ASAP
        Timeout.timeout(1e-9) do
          loop do
            Benchmark.realtime_block(:test1) do
              Benchmark.realtime_block(:test2) do
              end
              "result"
            end
          end
        end
      rescue Timeout::Error => e
        # sortable compact stacks: realtime_block and children, outer first, strip directories, pad line numbers
        interesting_depth = e.backtrace.rindex { |s| s =~ /in `realtime_block'/ } || 5
        where = e.backtrace[0..interesting_depth].reverse
        where = where.collect { |s| s.sub(%r{/.*/}, '').sub(/\d+:/) { |linenum| '%03d:' % linenum.to_i } }
        places_outcomes[where] ||= {:cleaned => 0, :failed => 0}
        if Benchmark.in_realtime_block?
          places_outcomes[where][:failed] += 1
          Benchmark.delete_current_realtime
        else
          places_outcomes[where][:cleaned] += 1
        end
      else
        fail "impossible: escaped infinite loop without exception"
      end
    end

    places_outcomes.sort.each do |where, outcomes|
      puts "cleaned\t#{outcomes[:cleaned]}\tfailed\t#{outcomes[:failed]}\t#{where.join(' -> ')}"
    end
  end
end
