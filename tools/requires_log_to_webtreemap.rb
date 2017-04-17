if ARGV.length != 2
  puts "Usage: #{$0} /path/to/requires.log /path/to/webtreemap"
  puts
  puts "This tool uses webtreemap, which can be obtained from https://github.com/evmar/webtreemap"
  exit 1
end

require 'active_support/all'

requires_file, webtreemap_dir = ARGV

def parse_line(line)
  match = line.match(/^(?<indent>[0-9 ]{3})  ..  (?:\| )*(?<location>[^(]+)(?: \((?<metric>[-0-9.]+)\))?$/)
  return {} unless match
  {
    :indent   => match[:indent].to_i,
    :location => match[:location].strip,
  }.tap do |h|
    h[:metric] = match[:metric].to_f if match[:metric]
  end
end

nestings = []
current_indent = -1

File.open(requires_file) do |f|
  f.each_line do |line|
    line = parse_line(line)

    if line[:indent] > current_indent
      current_indent += 1
      nestings << []
    elsif line[:indent] < current_indent
      current_indent -= 1
      children = nestings.pop
      dot_metrics = line[:metric] - children.map { |c| c[:data]["$area"] }.sum
      children << {:name => ". (#{dot_metrics})", :data => {"$area" => dot_metrics}}
      nestings.last << {:name => "#{line[:location]} (#{line[:metric]})", :data => {"$area" => line[:metric]}, :children => children}
    elsif line[:metric]
      nestings.last << {:name => "#{line[:location]} (#{line[:metric]})", :data => {"$area" => line[:metric]}}
    end
  end
end

children = nestings.pop
result = {:name => "Total", :data => {"$area" => children.map { |c| c[:data]["$area"] }.sum}, :children => children}

webtreemap_file = File.join(webtreemap_dir, "demo/demo.json")
File.write(webtreemap_file, "var kTree=#{result.to_json}")
