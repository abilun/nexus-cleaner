require 'json'
require 'date'
require 'mixlib/cli'
require 'benchmark'

def get_value(string)
  /(?<==).*$/.match(string).to_s
end

def sub_days(creation_time)
  (Date.today - Time.at(creation_time).to_date).to_i
end

# CLI arguments class
class CLI
  include Mixlib::CLI

  option :rules,
         short: '-r RULES',
         long: '--rules RULES',
         default: 'rules.json',
         description: 'The list of rules to use'

  option :path,
         short: '-p PATH',
         long: '--path PATH',
         required: true,
         description: 'Directory to process'

  option :dry_run,
         short: '-d',
         long: '--dry-run',
         boolean: true,
         default: false,
         description: 'Shows processed files without real execution'

  option :help,
         short: '-h',
         long: '--help',
         description: 'Show this message',
         on: :tail,
         boolean: true,
         show_options: true,
         exit: 0
end

cli = CLI.new
cli.parse_options

data_json = JSON.parse(File.read(cli.config[:rules]))
processed_files = 0

Dir.chdir cli.config[:path]

# Iterate over all .properties files
time = Benchmark.realtime do
  Dir.glob('content/**/*.properties') do |filename|
    File.open(filename, 'r+') do |file|
      repo_name, creation_time, blob_name = ''
      is_deleted = false

      file.each_line do |line|
        is_deleted = true if line =~ /deleted=true/
        repo_name = get_value(line) if line =~ /repo-name/
        creation_time = get_value(line).to_i / 1000 if line =~ /creationTime/
        blob_name = get_value(line) if line =~ /blob-name/
      end

      next if is_deleted

      # If file is matching path and days conditions, then mark it as deleted
      if data_json.key?(repo_name)
        data_json[repo_name].each do |rule|
          next unless blob_name =~ /#{rule['path']}/
          days_before_today = sub_days(creation_time)
          next unless days_before_today > rule['days'].to_i
          processed_files += 1
          if !cli.config[:dry_run]
            file.puts('deleted=true')
          else
            puts "Filename: #{File.expand_path(filename)}"
            puts "Repo: #{repo_name}"
            puts "Blob path: #{blob_name}"
            puts "Matched mask: #{rule['path']}"
            puts "Days by rule: #{rule['days']}"
            puts "Created days before: #{days_before_today}"
            puts '-' * 25
          end
        end
      end
    end
  end
end

puts "Elapsed time: #{time.round(5)}"
puts "Processed files: #{processed_files}"

if processed_files > 0 && !cli.config[:dry_run]
  File.open("#{cli.config[:path]}/metadata.properties", 'a+') do |file|
    index_line = 'rebuildDeletedBlobIndex=true'
    file.puts(index_line) unless file.grep(/#{index_line}/).any?
  end
end
