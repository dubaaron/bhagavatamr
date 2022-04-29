#!/usr/bin/env ruby

# - parse args, get canto and chapter (and destination?)
# - turn off dictionary links - send req to:
#   https://prabhupadabooks.com/php/data_ajax.php?action=changeSetting&encoding=unicode&dictionaryLinks=no&booksv=yes&bookss=yes&bookst=yes&booksp=yes
# - 
# - fetch bhagavatam html from https://prabhupadabooks.com/sb/<canto>/<chapter>?d=1

require 'thor'
class BhāgavatamrCLI < Thor
  desc 'fetch CANTO CHAPTER', 'fetch and save HTML for chapter, defaults to 01.01'
  def fetch_chapter canto: 1, chapter: 1
    Bhāgavatamr.fetch_chapter canto, chapter
  end

  desc 'process CANTO CHAPTER', 'process HTML for chapter, default 01.01'
  def process_chapter canto: 1, chapter: 1
    Bhāgavatamr.process canto, chapter
  end
end

require 'colorize'
class Bhāgavatamr
  OUTPUTDIR = './output'
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
    FileUtils.mkdir_p OUTPUTDIR
  
    output_file_name = self.get_rawhtml_filepath
    puts "Saving to '#{output_file_name}' ..."
    File.write(output_file_name, page.body)
    puts 'Done. Haribol!'.yellow.on_blue.bold, ''
      
  end

  def self.get_rawhtml_filepath canto = 1, chapter = 1
    "#{OUTPUTDIR}/%02d.%02d_raw.html" % [canto, chapter]
  end

  def self.turn_off_links
    url_to_switch_links_off = URI('https://prabhupadabooks.com/php/data_ajax.php?action=changeSetting&encoding=unicode&dictionaryLinks=no&booksv=yes&bookss=yes&bookst=yes&booksp=yes')
  
    puts "Setting links to 'off' ... "
  
    page = @@agent.get(url_to_switch_links_off)
  
    puts page.body.light_blue, ''
  end


  def self.process canto = 1, chapter = 1
    file = self.get_rawhtml_filepath canto, chapter
    # require 'pry'; binding.pry
    puts "Processing HTML from #{file} ...", ''

    require 'nokogiri'
    noko = Nokogiri::HTML File.open file
    puts noko.css('.breadcrumb').text
    puts noko.css('.chapnum').text
    puts noko.css('.Chapter-Desc').text

    # the texts are inside a td width=90% currently; start with that
    noko.css('td[width="90%"]').children.each do |el|
      puts el.content[0..108]
      # look to see what kind of element, process as necessary, etc.
    end

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
