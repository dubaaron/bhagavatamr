#!/usr/bin/env ruby

# require 'pry'
require 'pry-byebug'

=begin
Todo:
- [ ] always remember Krishna; never forget Krishna
- [ ] some japa
- [ ] make so only one verse can be selected at a time (maybe later allow more than one through a setting?)
- [x] put output in folders
- [ ] fix input parsing
- [ ] make a one-shot command to fetch & parse
- [ ] try pulling from folio infobase files ...
  - https://github.com/imazen/folioxml
  - https://stackoverflow.com/questions/6521655/need-to-export-from-folio-to-xml-or-convert-fff-to-xml
- [x] make the weekly readings
  - [x] parse the verses into a structure
- [ ] fix html italic classes, etc
- [x] fix broken characters (i think is fixed)
- [x] parse args, get canto and chapter (and destination?)
- [x] turn off dictionary links - send req to:
  https://prabhupadabooks.com/php/data_ajax.php?action=changeSetting&encoding=unicode&dictionaryLinks=no&booksv=yes&bookss=yes&bookst=yes&booksp=yes
- [x] fetch bhagavatam html from https://prabhupadabooks.com/sb/<canto>/<chapter>?d=1
=end

require 'thor'
class BhāgavatamrCLI < Thor
  desc 'fetch BOOK CANTO CHAPTER', 'fetch and save HTML for chapter, defaults to SB 1.1'
  def fetch_chapter book = 'sb', canto = 1, chapter = 1
    Bhāgavatamr.fetch_chapter book, canto, chapter
  end

  desc 'process BOOK CANTO CHAPTER', 'process HTML for chapter, default SB 1.1'
  def process_chapter book = 'sb', canto = 1, chapter = 1
    Bhāgavatamr.process book, canto, chapter
  end



  def self.exit_on_failure?
    true
  end
end

require 'colorize'
class Bhāgavatamr
  OUTPUTDIR = './output'
  CANTOS = {
    1 => '“Creation”',
    2 => '“The Cosmic Manifestation”',
    3 => '“The Status Quo”',
    4 => '“Creation of the Fourth Order”',
    5 => '“The Creative Impetus”',
    6 => '“Prescribed Duties for Mankind”',
    7 => '“The Science of God”',
    8 => '“Withdrawal of the Cosmic Creations”',
    9 => '“Liberation”',
    10 => '“The Summum Bonum”',
  }
  BOOKS = {
    'sb' => 'Śrīmad-Bhāgavatam',
    'cc' => 'Śrī Caitanya-Caritāmṛta'
  }

  def self.fetch_chapter(book = 'sb', canto = 1, chapter = 1)
    require 'net/http'
    # require 'rubygems'
    require 'mechanize'

    @@agent = Mechanize.new

    self.turn_off_links

    chapter_str = chapter
    chapter_str = "#{chapter}-1" if book == 'cc'

    chapter_url = "https://prabhupadabooks.com/#{book}/#{canto}/#{chapter_str}?d=1"

    puts "Fetching #{BOOKS[book]} Canto #{canto}, Chapter #{chapter}, from #{chapter_url}"

    all_html = get_all_pages(chapter_url)

    output_file_name = self.get_rawhtml_filepath(book, canto, chapter)
    puts "Saving to '#{output_file_name}' ..."
    require 'fileutils'
    FileUtils.mkdir_p(File.dirname(output_file_name))
    File.write(output_file_name, all_html)
    puts 'Done. Haribol!'.yellow.on_blue.bold, ''

  end


  def self.get_rawhtml_filepath book, canto, chapter
    self.get_output_path(book:, canto:, chapter:, name: 'raw.html')
  end


  def self.get_output_path(book: 'sb', canto: 1, chapter: 1, name: 'raw.html')
    # make sure canto and chapter values are padded with zeroes for good filenames
    # CC, etc, have 'adi', etc for "Canto" value
    # binding.pry
    canto = "%02d" % [canto] if self.looks_like_integer?(canto)
    chapter = "%02d" % [chapter] if self.looks_like_integer?(chapter)

    "#{OUTPUTDIR}/#{book}/#{canto}/#{chapter}_#{name}"
  end

  def self.looks_like_integer?(str)
    str.match?(/^-?\d+$/)
  end

  def self.turn_off_links
    url_to_switch_links_off = URI('https://prabhupadabooks.com/php/data_ajax.php?action=changeSetting&encoding=unicode&dictionaryLinks=no&booksv=yes&bookss=yes&bookst=yes&booksp=yes')

    puts "Setting links to 'off' ... "

    page = @@agent.get(url_to_switch_links_off)

    puts page.body.light_blue, ''
  end


  def self.get_all_pages(chapter_url, page = 1)
    # chapter_raw_html = Net::HTTP.get(chapter_url)


    # for some reason some chapters have weird URLs; this is a list of those
    special_chapter_urls = {
      'https://prabhupadabooks.com/sb/7/10?d=1' => 'https://prabhupadabooks.com/sb/7/10-1?d=1',
      'https://prabhupadabooks.com/sb/8/5?d=1' => 'https://prabhupadabooks.com/sb/8/5-1?d=1'
    }

    if special_chapter_urls[chapter_url.to_s]
      chapter_url = special_chapter_urls[chapter_url]
    end

    # do I need to pass the url to `URI(url)`?  maybe not.
    page = @@agent.get(chapter_url)


    # require 'nokogiri'
    # noko = Nokogiri::HTML File.open raw_file
    # todi: look for links to next page
    # noko = Nokogiri::HTML(page.body)

    # binding.pry

    puts '', page.body[1..1008].light_blue, '...', ''
    page.body
  end

  def self.fix_broken_ñ str
    # unfortunately, prabhupadabooks.com appears to be littered with ï¿½ where it should be ñ
    # str.gsub "ï¿½", "ñ"
    # try with HTML entity; 'ñ' didn't seem to work
    # binding.pry
    str = str.gsub '&ntilde;', '&#241;'
    str = str.gsub 'ï¿½', '&#241;'
    str = str.gsub '�', '&#241;'
    str
  end


  def self.process(book = 'sb', canto = 1, chapt_num = 1)
    raw_file = self.get_rawhtml_filepath book, canto, chapt_num
    puts "Processing HTML from #{raw_file} ...", ''

    # binding.pry
    puts "Cleaning stuff up ..."
    fixed_html = self.fix_broken_ñ(File.open(raw_file).read)
    File.write(self.get_output_path(book:, canto:, chapter: chapt_num, name: 'cleaned.html'), fixed_html)

    chapter = Chapter.new(canto, chapt_num)
    chapter.date_text_copied_from_source = File.mtime raw_file

    output = ''
    debug_output = ''
    require 'nokogiri'
    # noko = Nokogiri::HTML File.open raw_file
    noko = Nokogiri::HTML fixed_html

    chapter.fancy_number = noko.css('.chapnum').text
    chapter.title = noko.css('.Chapter-Desc').text
    output << noko.css('.breadcrumb').text << "\n" <<
      "#{chapter.fancy_number}\n" << chapter.title

    # todo: set this manually? because we know where we got it from ...
    # "Link to this page" at bottom
    if el = noko.search("p[align='center']")
      if el.text.match?("Link to this page:")
        chapter.text_source_url = el.css('a').text
      end
    end

    puts output.light_blue

    chapter.verses = {}
    this_verse = nil
    unhandled_bits = []

    we_are_in_chapter_summary = false

    # the texts are inside a td width=90% currently; start with that
    # for CC, they are in a <div class="text-box-5-percent">
    noko.css('td[width="90%"]').children.each do |el|
      output << el.content

      # strip links
      el.search('a').each { |node| node.replace(node.children) }

      # look to see what kind of element, process as necessary, etc.
      element_class = el&.attributes.dig('class')&.value
      case element_class
      when 'Textnum'
        # div.Textnum ends the chapter summary
        we_are_in_chapter_summary = false

        # start new verse
        unless this_verse.nil?
          # put previous verse onto the stack
          chapter.add_verse(this_verse)
        end
        # todo: test this regex?
        if m = el.content.match(/TEXTS? (?<range>(?<start>\d+)(?:[-–](?<end>\d+))?)/)
          verse_num = m[:start]
          this_verse = Verse.new num_start: m[:start], num_range: m[:range], num_end: m[:end]
          # todo: substitute emdash in range for regular hyphen?
          # binding.pry unless m[:end].nil?
        end

      when 'Verse-Text', 'Uvaca-line', 'Prose-Verse'
        this_verse.sanskrit_roman_lines << el.content

      when 'Synonyms'
        binding.pry if this_verse.nil?
        this_verse.synonyms_html = el.children.to_html

      when 'Translation'
        this_verse.english_translation_html << el.children.to_html
        this_verse.english_translation_text << el.text

      when 'First', 'Purport', 'After-Verse', 'Normal-Level', 'VerseRef', 'Verse', 'One'
        # todo: make sure we catch all variations; maybe write a way to check & compare text with original to make sure we're not missing anything?
        # todo: make sure verse-in-purport is handled properly ... I think it is, now, but could verify?
        if we_are_in_chapter_summary
          chapter.summary_paragraphs << el.children.to_html
        else
          this_verse.purport_html_paragraphs << el.children.to_html
        end

      when 'Thus-end'
        chapter.thus_ends_text << el.children.to_html

      when 'Search-Heading'
        # todo: extract this info somehow?
        chapter.next_prev_links_raw = el.to_html

      when 'Verse-Section', 'Synonyms-Section', 'chapnum'
        # ignore these for now; they are just headings

      when 'Chapter-Desc'
        we_are_in_chapter_summary = true

      else
        if el.text.match(/^([\s]|\\n)*$/)
          # ignore if just whitespace and literal '\n's

        ###
        # todo: fix this up for better reliability? use case-insensitive match?
        elsif el.to_html.match(/Verse-in-purp/) || el.to_html.match(/One-line-verse-in-purp/)

          # el&.children&.first.to_html ??
          text_to_add = "<blockquote>#{el.to_html}</blockquote>"
          if we_are_in_chapter_summary
            chapter.summary_paragraphs << text_to_add
          else
            this_verse.purport_html_paragraphs << text_to_add
          end

        ###
        # this pattern is indicative of being in a chapter summary, I guess?
        elsif el&.attributes.dig('style').to_s.match?('text-align : left') &&
          el&.children&.first.name == 'div' &&
          el&.children&.first&.attributes.dig('class').to_s == 'Normal-Level'

          we_are_in_chapter_summary = true
          chapter.summary_paragraphs << el&.children&.first.to_html

        else
          # binding.pry
          unhandled_bits << el.to_html
        end
      end

      # "Link to this page" at bottom
      # if el&.attributes.dig('align')&.value == 'center' && el&.name == 'p' &&
      #   el.content.match?("Link to this page:")
      #     # binding.pry
      #     chapter.text_source_url = el.css('a').text
      # end

      # todo: handle multi-page chapters
    end

    # put final verse onto the stack
    # binding.pry
    chapter.add_verse this_verse

    puts '', 'Unhandled bits:'.red, unhandled_bits, ''


    output_path = self.get_output_path(book:, canto:, chapter: chapt_num, name: 'plain.txt')
    File.write output_path, output
    puts "Wrote plaintext to #{output_path}"

    self.create_output chapter

  end


  def self.create_output chapter
    require 'slim'

    # Indent html for pretty debugging
    Slim::Engine.set_options pretty: true

    # binding.pry
    output_file = self.get_output_path(canto: chapter.canto, chapter: chapter.number, name: 'output.html')
    # binding.pry
    File.write output_file, Tilt.new('templates/chapter.slim').render(chapter)
    puts "Wrote output to #{output_file}"
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



class Verse
  attr_accessor :num_start, :num_end, :num_range, :sanskrit_roman_lines,
    :synonyms_html, :english_translation_html, :english_translation_text,
    :purport_html_paragraphs

  # def initialize num_start, num_end = nil
  def initialize num_start:, num_range: nil, num_end: nil
    @num_start = num_start
    # range is the string of the start to end of the verse, e.g. '12-14' if the entry includes verses 12, 13, and 14; if it includes just a single verse (as is most often), it will just be the verse number (e.g. '12')
    @num_range = num_range.nil? ? num_start : num_range
    @num_end = num_end.nil? ? num_start : num_end
    @sanskrit_roman_lines = []
    @synonyms_html = ''
    @english_translation_html = ''
    @english_translation_text = ''
    @purport_html_paragraphs = []
    # binding.pry unless num_end.nil?
  end
end



class Chapter
  attr_accessor :canto, :number, :fancy_number, :summary, :summary_paragraphs,
    :verses, :title, :thus_ends_text,
    :date_text_copied_from_source, :text_source_url, :next_prev_links_raw

  def initialize canto = 1, number = 1
    @verses = {}
    @canto = canto
    @number = number
    @thus_ends_text = ''
    @summary = ''
    @summary_paragraphs = []
  end

  def add_verse verse
    @verses[verse.num_start] = verse unless verse.nil?
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
