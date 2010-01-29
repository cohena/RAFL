#!/usr/bin/env ruby -wKU

#
# RAFL_wav.rb by Aaron Cohen
#
# RAFL - Ruby Audio File Library
# A means of reading, analyzing, and generating audio files from within Ruby
#
# This library is licensed under the LGPL. See COPYING.LESSER.
#
#
# TODO:
# Fix Sine Wave Generator - experiencing significant rounding error
# BEXT writing
# Fix Peak & RMS calculation on 24 bit audio

require 'rexml/document'
include REXML

class RiffFile
  
  VALID_RIFF_TYPES = [ 'WAVE' ]
  HEADER_PACK_FORMAT = "A4V"
  AUDIO_PACK_FORMAT_16 = "s*"
  
  attr_accessor :format, :bext_meta, :ixml_meta, :raw_audio_data
  
  def initialize(file, mode)
    @file = File.open(file, mode)
    @file.binmode
    if mode == 'r'
      read_chunks if riff? && VALID_RIFF_TYPES.include?(riff_type)
    end
  end

  def close
    @file.close
  end

  def riff?
    @file.seek(0)
    riff, @file_end = read_chunk_header
    return true if riff == 'RIFF'
  end
  
  def riff_type
    if riff?
      @file.seek(8)
      @file.read(4)
    end
  end
  
  def read_chunks
    while @file.tell < @file_end
      chunk_name, chunk_length = read_chunk_header
      chunk_position = @file.tell
      identify_chunk(chunk_name, chunk_position, chunk_length)
      @file.seek(chunk_position + chunk_length)
    end
  end
  
  def read_chunk_header
    @file.read(8).unpack(HEADER_PACK_FORMAT)
  end
  
  def identify_chunk(chunk_name, chunk_position, chunk_length)
    puts "Found chunk: #{chunk_name}"
    case chunk_name
      when 'fmt' then process_fmt_chunk(chunk_position, chunk_length)
      when 'bext' then process_bext_chunk(chunk_position, chunk_length)
      when 'data' then process_data_chunk(chunk_position, chunk_length)
      when 'iXML' then process_ixml_chunk(chunk_position, chunk_length)
    end
  end
  
  def process_fmt_chunk(chunk_position, chunk_length)
    @file.seek(chunk_position)
    @format = WaveFmtChunk.new(@file.read(chunk_length))
  end
  
  def process_bext_chunk(chunk_position, chunk_length)
    @file.seek(chunk_position)
    @bext_meta = BextChunk.new(@file.read(chunk_length))
  end
  
  def process_data_chunk(chunk_position, chunk_length)
    @data_begin, @data_end = chunk_position, chunk_position + chunk_length
    #@file.seek(chunk_position)
    #@raw_audio_data = []
    #for sample in (0..total_samples)
    #  @raw_audio_data << read_sample(sample)
    #end
  end
  
  def process_ixml_chunk(chunk_position, chunk_length)
    puts "Found iXML chunk"
    @file.seek(chunk_position)
    @ixml_meta = IxmlChunk.new(@file.read(chunk_length))
  end
  
  def unpack_samples(samples, bit_depth)
    if bit_depth == 24
      #return samples.scan(/.../).map {|s| (s.reverse + 0.chr ).unpack("V")}.flatten
      return samples.scan(/.../).map {|s| (s + 0.chr).unpack("V")}.flatten
    else
      return samples.unpack(AUDIO_PACK_FORMAT_16)
    end
  end
  
  def pack_samples(samples, bit_depth)
    if bit_depth == 24
      return samples.map { |s| [s].pack("VX") }.join
    else
      return samples.pack(AUDIO_PACK_FORMAT_16)
    end
  end
  
  def read_sample(sample_number, channel) #returns an individual sample value

    @file.seek(@data_begin + (sample_number * @format.block_align) + (channel * (@format.block_align / @format.num_channels)))

    return @file.read(@format.block_align / @format.num_channels)
    
    #return sample_array
  end
  
  def simple_read #returns all sample values for entire file
    @file.seek(@data_begin)
    #@file.read(@data_end - @data_begin).unpack(@audio_pack_format)#.join.to_i
    unpack_samples(@file.read(@data_end - @data_begin), @format.bit_depth)
  end
  
  def read_samples_by_channel(channel) #returns all of the sample values for a single audio channel
    samples = []
    for sample in (0..total_samples)
      samples << read_sample(sample, channel)
    end
    #samples.collect! { |samp| sample.unpack(@audio_pack_format).join.to_i } #bug, should be samp.unpack?
    samples.collect! { |samp| unpack_samples(samp, @format.bit_depth).join.to_i }
    return samples
  end
  
  def write(channels, sample_rate, bit_depth, audio_data) #writes to audio file
    write_riff_type
    write_fmt_chunk(channels, sample_rate, bit_depth)
    write_data_chunk(audio_data)
    write_riff_header
  end
  
  def write_riff_header
    @file.seek(0)
    @file.print(["RIFF", @file_end].pack(HEADER_PACK_FORMAT))
  end
  
  def write_riff_type
    @file.seek(8)
    @file.print(["WAVE"].pack("A4"))
  end
  
  def write_fmt_chunk(num_channels, sample_rate, bit_depth)
    @file.seek(12)
    @write_format = WaveFmtChunk.new
    @write_format.audio_format = 1
    @write_format.num_channels = num_channels
    @write_format.bit_depth = bit_depth
    @write_format.set_sample_rate(sample_rate)
    
    @file.print(["fmt ", 16].pack(HEADER_PACK_FORMAT)) # the 16 here means PCM, not bit depth
    @file.print(@write_format.pack_header_data)
  end
  
  def write_data_chunk(audio_data)
    data_chunk_begin = @file.tell
    @file.seek(8, IO::SEEK_CUR)
    @data_begin = @file.tell
    
    #interleave arrays
    if audio_data.length > 1
      interleaved_audio_data = audio_data[0].zip(*audio_data[1..-1]).flatten
    else
      interleaved_audio_data = audio_data[0]
    end
    
    puts interleaved_audio_data.length
    interleaved_audio_data.each_index do |sample|
      if interleaved_audio_data[sample].nil?
        puts "Sample number #{sample.to_s} is nil"
      end
    end
    
    @file.print(pack_samples(interleaved_audio_data, @write_format.bit_depth))
    @data_end = @file.tell
    @file_end = @file.tell
    @file.seek(data_chunk_begin)
    @file.print(["data", @data_end - @data_begin].pack(HEADER_PACK_FORMAT))
  end
  
  def duration
    (@data_end - @data_begin) / @format.byte_rate  
  end
  
  def total_samples
    (@data_end - @data_begin) / @format.block_align
  end
end

class WaveFmtChunk
  
  attr_accessor :audio_format, :num_channels,
  :sample_rate, :byte_rate,
  :block_align, :bit_depth

  PACK_FMT = "vvVVvv"

  def initialize(*binary_data)
    unpack_header_data(binary_data[0]) if !binary_data.empty?
  end
  
  def unpack_header_data(binary_data)
    @audio_format, @num_channels,
    @sample_rate, @byte_rate,
    @block_align, @bit_depth = binary_data.unpack(PACK_FMT)
  end
  
  def pack_header_data
    [ @audio_format, @num_channels,
    @sample_rate, @byte_rate,
    @block_align, @bit_depth ].pack(PACK_FMT)
  end
  
  def set_sample_rate(rate)
    @byte_rate = calc_byte_rate(rate)
    @sample_rate = rate
    @block_align = calc_block_align
  end
  
  def calc_block_align
    @num_channels * (@bit_depth)
  end

  def calc_byte_rate(sample_rate, num_channels = @num_channels, bit_depth = @bit_depth)
    sample_rate * num_channels * (bit_depth / 8)
  end
    
end

class BextChunk
  
  attr_accessor :description, :originator, :originator_reference, :origination_date, :origination_time,
                :time_reference, :version, :umid, :reserved, :coding_history
  
  PACK_FMT = "A256A32A32A10A8QvB64B190A*"
  
  def initialize(*binary_data)
    unpack_bext_data(binary_data[0]) if !binary_data.empty?
  end
  
  def unpack_bext_data(binary_data)
    @description, @originator, @originator_reference, @origination_date, @origination_time,
    @time_reference, @version, @umid, @reserved, @coding_history = binary_data.unpack(PACK_FMT)
  end
  
  def calc_time_offset(sample_rate)
    time = @time_reference / sample_rate
    return [time/3600, time/60 % 60, time % 60].map{|t| t.to_s.rjust(2,'0')}.join(':')
  end
end

class IxmlChunk
  
  PACK_FMT = "a*"
  
  def initialize(*binary_data)
    unpack_ixml_data(binary_data[0]) if !binary_data.empty?
  end
  
  def unpack_ixml_data(binary_data)
    @xml = Document.new(binary_data.unpack(PACK_FMT))
    puts @xml
  end
end


#####################
# Standalone methods
#####################

def calc_rms(audio_samples, format)
  #squaresum = 0
  #audio_samples.each { |value| squaresum += (value ** 2) }
  #sample_rms = Math.sqrt(squaresum / audio_samples.length)
  sample_rms = Math.sqrt((audio_samples.inject { |sum, item| sum + (item ** 2) }) / audio_samples.length)
  
  calc_dbfs(sample_rms, format.bit_depth)
end

def calc_peak(audio_samples, format)
  calc_dbfs(audio_samples.max.to_f, format.bit_depth)
end

def calc_dbfs(sample_value, bit_depth)
  range = (2 ** bit_depth) / 2
  (20*Math.log10(sample_value.to_f / range)).round_to(2)
end

def calc_sample_value(dbfs_value, bit_depth)
  range = (2 ** bit_depth / 2)
  (range * Math::E ** (1/20.0 * dbfs_value * (Math.log(2) + Math.log(5)))) - 1
end

def generate_white_noise(length_secs, peak_db, sample_rate, bit_depth)
  num_samples = (length_secs * sample_rate).to_i
  peak_samples = calc_sample_value(peak_db, bit_depth)
  output = []
  num_samples.times do
    output << (rand(65536) - 32768) * peak_samples
  end
  return output
end

def generate_pink_noise(length_secs, peak_db, sample_rate, bit_depth)
  num_samples = (length_secs * sample_rate).to_i
  peak_samples = calc_sample_value(peak_db, bit_depth)
  output = []
  amplitude_scaling = [3.8024, 2.9694, 2.5970, 3.0870, 3.4006]
  update_probability = [0.00198, 0.01280, 0.04900, 0.17000, 0.68200]
  probability_sum = [0.00198, 0.01478, 0.06378, 0.23378, 0.91578]
  
  contributed_values = [0, 0, 0, 0, 0]
  
  num_samples.times do
    
    ur1 = rand
    5.times do |stage|
      if ur1 <= probability_sum[stage]
        ur2 = rand
        contributed_values[stage] = 2 * (ur2 - 0.5) * amplitude_scaling[stage]
        break
      end
    end
    
    sample = contributed_values.inject(0){|sum,item| sum + item}
    
    output << sample
  end
  
  scale_amount = peak_samples / output.max
  output.map! { |item| (item * scale_amount).round_to(0).to_i }
  
  return output
end

def generate_sine_wave(length_secs, peak_db, freq, sample_rate, bit_depth) #defective...drifts over time - rounding error?
  peak_samples = calc_sample_value(peak_db, bit_depth)
  output = []
  period = 1.0 / freq
  angular_freq = (2 * Math::PI) / period
  
  time = 0
  while time <= length_secs do
    output << (Math.sin(angular_freq * time) * peak_samples).round_to(0).to_i
    time += (1.0 / sample_rate)
  end
  return output.slice(0..-2) #kludge...need to pick this apart to find extra sample
end


class Float
  def round_to(x)
    (self * 10**x).round.to_f / 10**x
  end

  def ceil_to(x)
    (self * 10**x).ceil.to_f / 10**x
  end

  def floor_to(x)
    (self * 10**x).floor.to_f / 10**x
  end
end