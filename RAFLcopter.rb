#!/usr/bin/env ruby -wKU

#
# RAFLcopter.rb by Aaron Cohen
#
# A friendly demonstration front end for RAFL - Ruby Audio File Library
# 
#

require 'RAFL_wav.rb'
require 'benchmark'

$quit = false

def read_wav
  userfile = ""
  until File.file?(userfile)
    puts ""
    puts "Enter the path to a wav file:"
    userfile = gets.strip.chomp.gsub("\\ ", " ")
  end
  
  inputfile = RiffFile.new(userfile, 'r')
  
  puts ""
  puts "--- #{userfile.to_s} ---"
  puts ""
  puts "Bit Depth: #{inputfile.format.bit_depth}"
  puts "Sample Rate: #{inputfile.format.sample_rate} Hz"
  puts "Number of channels: #{inputfile.format.num_channels}"
  puts ""
  if inputfile.bext_meta != nil
    puts "Broadcast Wav Metadata:"
    puts "\tDescription: #{inputfile.bext_meta.description}"
    puts "\tCreator: #{inputfile.bext_meta.originator}"
    puts "\tCreator Reference: #{inputfile.bext_meta.originator_reference}"
    puts "\tCreation Date: #{inputfile.bext_meta.origination_date}"
    puts "\tCreation Time: #{inputfile.bext_meta.origination_time}"
    puts "\tTime location: #{inputfile.bext_meta.calc_time_offset(inputfile.format.sample_rate)}"
    puts "\tMetadata version: #{inputfile.bext_meta.version}"
  end
  puts ""
  puts "Reading sample data..."
  puts ""
  puts "Currently slow at calculating RMS on big files."
  puts "Optimizations to come."
  sample_data = inputfile.simple_read
  puts ""
  puts "#{sample_data.length / inputfile.format.num_channels} samples per channel"
  puts ""
  Benchmark.benchmark do |bench|
    bench.report {puts "Peak (dbFS): #{calc_peak(sample_data, inputfile.format)} dB"}
    bench.report {puts "RMS (dbFS): #{calc_rms(sample_data, inputfile.format)} dB"}
  end
  puts ""
  
end

def gen_white_noise_arg(length_secs, sample_rate, bit_depth)
  puts ""
  puts "Peak level for white noise? (in dBFS)"
  peak_db = gets.chomp.strip.to_f
  
  puts "Generating White Noise..."
  return generate_white_noise(length_secs, peak_db, sample_rate, bit_depth)
  
end

def gen_pink_noise_arg(length_secs, sample_rate, bit_depth)
  puts ""
  puts "Peak level for pink noise? (in dBFS)"
  peak_db = gets.chomp.strip.to_f

  puts "Generating Pink Noise..."
  return generate_pink_noise(length_secs, peak_db, sample_rate, bit_depth)
end

def gen_sine_wave_arg(length_secs, sample_rate, bit_depth)
  puts ""
  puts "Peak level for sine wave? (in dBFS)"
  puts "(Levels above 0dB wrap samples around and create interesting distortion)"
  peak_db = gets.chomp.strip.to_f

  puts ""
  puts "Frequency? (in Hz)"
  freq = gets.chomp.strip.to_i

  puts "Generating Sine Wave..."
  return generate_sine_wave(length_secs, peak_db, freq, sample_rate, bit_depth)

end

def write_wav
  audio_content_by_chan = []
  
  puts ""
  puts "Enter name of file to write to:"
  userfile = gets.chomp.strip
  
  outputfile = RiffFile.new(userfile, 'w+')
  
  puts ""
  puts "Number of channels? (surround sound supported)"
  num_channels = gets.chomp.strip.to_i
  
  puts ""
  puts "Enter Sample Rate (ex: 44100): "
  sample_rate = gets.chomp.strip.to_i
  
  puts ""
  puts "Enter Bit Depth (16 or 24)"
  bit_depth = gets.chomp.strip.to_i
  
  puts ""
  puts "How many seconds long should the audio file be?"
  length_secs = gets.chomp.strip.to_f
  
  num_channels.times do |channel|
    puts ""
    puts "For channel #{channel + 1}, what should be the content?"
    puts "1. White Noise"
    puts "2. Pink Noise"
    puts "3. Sine Wave"
    
    Benchmark.realtime do
      case gets.chomp.strip.to_i
        when 1
          audio_content_by_chan << gen_white_noise_arg(length_secs, sample_rate, bit_depth)
        when 2
          audio_content_by_chan << gen_pink_noise_arg(length_secs, sample_rate, bit_depth)
        when 3
          audio_content_by_chan << gen_sine_wave_arg(length_secs, sample_rate, bit_depth)
      end
    end
  end
  
  puts "Interleaving audio if necessary (needs optimization)..."
  Benchmark.benchmark do |bench|
    bench.report("Interleave benchmark: ") {outputfile.write(num_channels, sample_rate, bit_depth, audio_content_by_chan)}
  end
  puts "Writing to disk..."
  Benchmark.benchmark do |bench|
    bench.report("Disk write benchmark: ") {outputfile.close}
  end
  puts ""
  puts "#{userfile} complete. Feel free to open it up in another app..."
  puts "                        ....Pro Tools, maybe?"
end

def root_menu
  selected = false
  until selected == true do
    puts ""
    puts "1. Read a WAV file"
    puts "2. Write a WAV file"
    puts "3. Exit"
    puts ""
    puts "Select a number: "
    
    case gets.chomp.strip.to_i
      when 1
        read_wav
      when 2
        write_wav
      when 3
        $quit = true
        exit
      
      else
        puts ""
        puts "Just enter numbers. You trying to break this thing?"
        selected = false
    end
  end
end

system('clear')
puts ""
puts " +---------------------------------------+"
puts ""
puts "             R A F L c o p t e r"
puts ""
puts " +---------------------------------------+"
puts ""
puts "            A demo front end for"
puts "        RAFL - Ruby Audio File Libary"
sleep 5
system('clear')


puts "You are currently running under Ruby #{RUBY_VERSION}. Anything less than Ruby 1.9" if RUBY_VERSION.to_f < 1.9
puts "will be very slow. It is recommended that you limit wav file lengths to less" if RUBY_VERSION.to_f < 1.9
puts "than 5 seconds if you want processing to complete before the end of the world." if RUBY_VERSION.to_f < 1.9


until $quit == true do
  root_menu
end
