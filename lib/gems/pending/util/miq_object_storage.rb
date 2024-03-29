require 'net/protocol'

class MiqObjectStorage < MiqFileStorage::Interface
  attr_accessor :settings
  attr_writer   :logger

  DEFAULT_CHUNKSIZE = Net::BufferedIO::BUFSIZE

  def initialize(settings)
    raise "URI missing" unless settings.key?(:uri)
    @settings = settings.dup
  end

  def logger
    @logger ||= $log.nil? ? :: Logger.new(STDOUT) : $log
  end

  private

  DONE_READING = "".freeze
  def read_single_chunk(chunksize = DEFAULT_CHUNKSIZE)
    @buf_left ||= byte_count
    return DONE_READING.dup unless @buf_left.nil? || @buf_left.positive?
    cur_readsize = if @buf_left.nil? || @buf_left - chunksize >= 0
                     chunksize
                   else
                     @buf_left
                   end
    buf = source_input.read(cur_readsize)
    @buf_left -= chunksize if @buf_left
    buf.to_s
  end

  def write_single_split_file_for(file_io)
    loop do
      input_data = read_single_chunk
      break if input_data.empty?
      file_io.write(input_data)
    end
    clear_split_vars
  end

  def write_chunk_proc(destination)
    # We use a `proc` here instead of `lambda` because we are only concerned
    # about the first argument, and other arguments (additional ones added by
    # Excon's response_call signature, for example) are unneeded.
    #
    # `lambda do` will do argument checking, while `proc do` won't.
    proc do |chunk|
      destination.write(chunk.force_encoding(destination.external_encoding))
    end
  end

  def clear_split_vars
    @buf_left = nil
  end
end
