#!/usr/bin/env ruby -wKU

#
# RAFLticket.rb by Aaron Cohen
#
# An iXML and BEXT/BWF Metadata dumper for WAVE files
# 
#

require 'Pathname'
require 'RAFL_wav.rb'

puts "\nWelcome to RAFLticket.\n\nTo process multiple files at once, add them as arguments\nwhen running this script.\n\n"

def process(path)
  puts "Dumping data for #{Pathname.new(path).basename}..."

  inputfile = RiffFile.new(path, 'r')
  outputpath = path.chomp(File.extname(path)) + ".txt"
  outputfile = File.new(outputpath, 'w+')

  outputfile <<       [
                      "File Name: #{Pathname.new(path).basename}",
                      "Length: #{Pathname.new(path).size} bytes",
                      "Chunks found: #{inputfile.found_chunks.join(', ')}",
                      "Num Channels: #{inputfile.format.num_channels}",
                      "Bit Depth: #{inputfile.format.bit_depth}",
                      "Sample Rate: #{inputfile.format.sample_rate}",
                      "\n------------\n\n"
                      ].join("\n")

  if inputfile.bext_meta != nil
    outputfile <<     [
                      "BEXT / BWF Information:",
                      "Description: #{inputfile.bext_meta.description}",
                      "Originating App: #{inputfile.bext_meta.originator}",
                      "Originator Reference: #{inputfile.bext_meta.originator_reference}",
                      "Origination Date: #{inputfile.bext_meta.origination_date}",
                      "Origination Time: #{inputfile.bext_meta.origination_time}",
                      "Time Reference (samples): #{inputfile.bext_meta.time_reference}",
                      "Time Reference (time):    #{inputfile.bext_meta.calc_time_offset(inputfile.format.sample_rate)}",
                      "Metadata Version: #{inputfile.bext_meta.version}",
                      "UMID: #{inputfile.bext_meta.umid}",
                      "Reserved Data: #{inputfile.bext_meta.reserved}",
                      "Coding History: #{inputfile.bext_meta.coding_history}",
                      "\n------------\n\n"
                      ].join("\n")
  end
  
  if inputfile.ixml_meta != nil
    outputfile << "iXML:\n------------\n\n"
    
    ixml = inputfile.ixml_meta.raw_xml
    ixml.write(outputfile, 4)
  end

  outputfile.close
  puts "The metadata has been dumped to #{outputpath}."
end


if ARGV.empty?
  puts "Please enter the path of a WAV file whose metadata you wish to dump:"
  userfile = gets.strip.chomp.gsub("\\ ", " ")
  if Pathname.new(userfile).exist?
    process(userfile)
  else
    puts "Couldn't find file."
  end
else
  ARGV.each do |file|
    process(file)
  end
end