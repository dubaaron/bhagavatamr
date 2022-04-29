#!/usr/bin/env ruby

# - parse args, get canto and chapter (and destination?)
# - turn off dictionary links - send req to:
#   https://prabhupadabooks.com/php/data_ajax.php?action=changeSetting&encoding=unicode&dictionaryLinks=no&booksv=yes&bookss=yes&bookst=yes&booksp=yes
# - 
# - fetch bhagavatam html from https://prabhupadabooks.com/sb/<canto>/<chapter>?d=1

require 'thor'
class BhāgavatamrCLI < Thor
  desc 'fetch CANTO CHAPTER', 'fetch '
  def fetch_chapter canto: 1, chapter: 1
    Bhāgavatamr.fetch_chapter canto, chapter
  end
end

require 'colorize'
class Bhāgavatamr
  def self.fetch_chapter(canto = 1, chapter = 1)
    require 'net/http'
    require 'rubygems'
    require 'mechanize'
  
    @@agent = Mechanize.new

    self.turn_off_links

  
    chapter_url = URI("https://prabhupadabooks.com/sb/#{canto}/#{chapter}?d=1")
  
    puts "Fetching Śrīmad-Bhāgavatam Canto #{canto}, Chapter #{chapter}, from #{chapter_url}"
    
    # chapter_raw_html = Net::HTTP.get(chapter_url)
    page = @@agent.get(chapter_url)
  
    # require 'pry'; binding.pry
    puts '', page.body[1..1008].light_blue, '...', ''
  
    require 'fileutils'
    FileUtils.mkdir_p "./output"
  
    output_file_name = "output/%02d.%02d_raw.html" % [canto, chapter]
    puts "Saving to '#{output_file_name}' ..."
    File.write(output_file_name, page.body)
    puts 'Done. Haribol!'.yellow.on_blue.bold, ''
      
  end


  def self.turn_off_links
    url_to_switch_links_off = URI('https://prabhupadabooks.com/php/data_ajax.php?action=changeSetting&encoding=unicode&dictionaryLinks=no&booksv=yes&bookss=yes&bookst=yes&booksp=yes')
  
    puts "Setting links to 'off' ... "
  
    page = @@agent.get(url_to_switch_links_off)
  
    puts page.body.light_blue, ''
  end
end



def extract_translations_from_markdown(full_markdown_file = ARGV[0])

  puts "Attempting to open #{full_markdown_file} ..."

  File.open(full_markdown_file, 'r') do |input_file|
    input_text = input_file.read()

    regex = /TEXTS? (\d+(\D\d+)?)[\s\S]*?TRANSLATION\n\n([\S\s]*?)\n\n(PURPORT)?[\s\S]*?(?=(TEXT)|(Thus end the Bhaktivedanta))/m

    translations_only = input_text.gsub(regex, '[\1.] \3' << "\n\n");

    p translations_only;

    output_file_name = full_markdown_file + ", translations.md"
    File.open(output_file_name, 'w') do |output_file|
      output_file.puts(translations_only)
      puts "Wrote output to '#{output_file_name}'"
    end
  end
end


puts ' Jagat, Haribol! '.yellow.on_blue.bold
BhāgavatamrCLI.start(ARGV)

# if ARGV.empty?
#   fetch_chapter(canto: 3, chapter: 25)
# else
#   extract_translations_from_markdown(ARGV[0])
# end
