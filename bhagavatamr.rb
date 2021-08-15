puts "Jagat, Haribol!"

# open file

if ARGV.empty?
    puts "Need input file"
    exit
end

# turn off dictionary links:
# https://prabhupadabooks.com/php/data_ajax.php?action=changeSetting&encoding=unicode&dictionaryLinks=no&booksv=yes&bookss=yes&bookst=yes&booksp=yes

file_to_open = ARGV[0]

puts "Attempting to open #{file_to_open} ..."

File.open(file_to_open, 'r') do |input_file|
    input_text = input_file.read()

    regex = /TEXTS? (\d+(\D\d+)?)[\s\S]*?TRANSLATION\n\n([\S\s]*?)\n\n(PURPORT)?[\s\S]*?(?=(TEXT)|(Thus end the Bhaktivedanta))/m

    translations_only = input_text.gsub(regex, '[\1.] \3' << "\n\n");

    p translations_only;

    output_file_name = file_to_open + ", translations.md"
    File.open(output_file_name, 'w') do |output_file|
        output_file.puts(translations_only)
        puts "Wrote output to '#{output_file_name}'"
    end
end
