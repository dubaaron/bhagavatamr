#!/usr/bin/env ruby

require 'pry'

=begin
Todo:
- [ ] always remember Krishna; never forget Krishna
- [ ] some japa
- [ ] make the weekly readings
- [ ] fix html italic classes, etc
- [ ] fix broken characters
- [x] parse args, get canto and chapter (and destination?)
- [x] turn off dictionary links - send req to:
  https://prabhupadabooks.com/php/data_ajax.php?action=changeSetting&encoding=unicode&dictionaryLinks=no&booksv=yes&bookss=yes&bookst=yes&booksp=yes
- [x] fetch bhagavatam html from https://prabhupadabooks.com/sb/<canto>/<chapter>?d=1
=end

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
    self.get_output_path 'raw.html', canto: canto, chapter: chapter
  end


  def self.get_output_path name = 'raw.html', canto: 1, chapter: 1
    "#{OUTPUTDIR}/%02d.%02d_#{name}" % [canto, chapter]
  end


  def self.turn_off_links
    url_to_switch_links_off = URI('https://prabhupadabooks.com/php/data_ajax.php?action=changeSetting&encoding=unicode&dictionaryLinks=no&booksv=yes&bookss=yes&bookst=yes&booksp=yes')
  
    puts "Setting links to 'off' ... "
  
    page = @@agent.get(url_to_switch_links_off)
  
    puts page.body.light_blue, ''
  end


  def self.fix_broken_ñ str
    # unfortunately, prabhupadabooks.com appears to be littered with ï¿½ where it should be ñ
    # str.gsub "ï¿½", "ñ"
    # try with HTML entity; 'ñ' didn't seem to work
    str.gsub '&ntilde;', '&#241;'
    str.gsub 'ï¿½', '&#241;'
  end


  def self.process canto = 1, chapter = 1
    raw_file = self.get_rawhtml_filepath canto, chapter
    # require 'pry'; binding.pry
    puts "Processing HTML from #{raw_file} ...", ''

    # binding.pry
    puts "Cleaning stuff up ..."
    fixed_html = self.fix_broken_ñ File.open(raw_file).read
    File.write(self.get_output_path('cleaned.html', canto: canto, chapter: chapter), fixed_html)


    output = ''
    debug_output = ''
    require 'nokogiri'
    # noko = Nokogiri::HTML File.open raw_file
    noko = Nokogiri::HTML fixed_html
    output << noko.css('.breadcrumb').text << "\n"
    output << noko.css('.chapnum').text << "\n"
    output << noko.css('.Chapter-Desc').text << "\n"

    puts output.light_blue

    verses = {}
    this_verse = nil
    # the texts are inside a td width=90% currently; start with that
    noko.css('td[width="90%"]').children.each do |el|
      output << el.content
      # look to see what kind of element, process as necessary, etc.
      case el&.attributes.dig('class')&.value
      when 'Textnum'
        # start new verse
        unless this_verse.nil?
          # put previous verse onto the stack
          verses[this_verse.verse_num_start] = this_verse
        end
        # todo: test this regex?
        if m = el.content.match(/TEXT (?<range>(?<start>\d+)(?:-(?<end>\d+))?)/)
          verse_num = m[:start]
          this_verse = Verse.new verse_num, m[:end]
          binding.pry unless m[:end].nil?
          # binding.pry
        end
        # binding.pry
      
      when 'Verse-Text'
        this_verse.sanskrit_roman_lines << el.content
      
      when 'Synonyms'
        this_verse.synonyms_html = el.children.to_html
      
      when 'Translation'
        this_verse.english_translation_html << el.children.to_html
      when 'First', 'Purport'
      # if Element.new(el).class_is 'First' || Element.new(el).class_is 'Purport'
        this_verse.purport_html_paragraphs << el.children.to_html
      end
    end

    # put final verse onto the stack
    verses[this_verse.verse_num_start] = this_verse


    output_path = self.get_output_path 'processing', canto: canto, chapter: chapter
    File.write output_path, output

    puts "Written to #{output_path}"
  end


end


class Verse
  attr_accessor :verse_num_start, :verse_num_end, :sanskrit_roman_lines, 
    :synonyms_html, :english_translation_html, :purport_html_paragraphs

  def initialize verse_num_start, verse_num_end = nil
    @verse_num_start = verse_num_start
    @verse_num_end = verse_num_end.nil? ? verse_num_start : verse_num_end
    @sanskrit_roman_lines = []
    @synonyms_html = ''
    @english_translation_html = ''
    @purport_html_paragraphs = []
  end
end


class Element
  def initialize element
    @el = element
  end

  def class_is classname
    return true if @el&.attributes.dig('class')&.value == classname
    false
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
puts ' 1. Always Remember Kṛṣṇa, 2. Never forget Kṛṣṇa 🙏❤  '.blue.on_yellow.bold
BhāgavatamrCLI.start(ARGV)

puts ' 1. Always Remember Kṛṣṇa, 2. Never forget Kṛṣṇa 🙏❤  '.blue.on_yellow.bold
# if ARGV.empty?
#   fetch_chapter(canto: 3, chapter: 25)
# else
#   extract_translations_from_markdown(ARGV[0])
# end
