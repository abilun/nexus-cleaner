require 'json'
require 'date'
require 'mixlib/cli'

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

# dir = '/mnt/sdb1/vol-01/'
Dir.chdir cli.config[:path]

Dir.glob('**/*.properties') do |filename|
  File.open(filename, 'r+') do |file|
    repo_name, creation_time, blob_name = ''
    is_deleted = false

    file.each_line do |line|
      repo_name = get_value(line) if line =~ /repo-name/
      creation_time = get_value(line).to_i / 1000 if line =~ /creationTime/
      blob_name = get_value(line) if line =~ /blob-name/
      is_deleted = true if line =~ /deleted=true/
    end

    next if is_deleted

    if data_json.key?(repo_name)
      data_json[repo_name].each do |rule|
        # check if path section exists
        next unless blob_name =~ /#{rule['path']}/
        days_before_today = sub_days(creation_time)
        file.puts('deleted=true') if days_before_today > rule['days'].to_i
      end
    end
  end
end
