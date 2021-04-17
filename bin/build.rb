#!/usr/bin/env ruby

require "pathname"
require "set"

class Build
  def self.call(outfile:)
    new(outfile: outfile).call
  end

  private_class_method :new

  def initialize(outfile:)
    @outfile = outfile
    @infile = Pathname.new("../src/manage.rb").expand_path(__dir__)
  end

  def call
    outfile.write(content)
    outfile.chmod(0777)
  end

  private

  attr_reader :outfile, :infile

  def content
    read_result.content.sub(
      "#!/usr/bin/env ruby\n",
      "#!/usr/bin/env ruby\n\n" + require_lines.join
    )
  end

  def require_lines
    read_result.required_files.map { |path| %(require "#{path}"\n) }
  end

  def read_result
    @read_result ||= Read.call(infile)
  end

  class Read
    def self.call(file, already_relative_required_files: Set.new)
      new(
        file,
        already_relative_required_files: already_relative_required_files
      ).call
    end

    private_class_method :new

    def initialize(file, already_relative_required_files:)
      @file = file
      @directory = file.dirname
      @content = ""
      @already_relative_required_files = already_relative_required_files
      @required_files = []
    end

    def call
      process_file
      ReadResult.new(
        content: cleaned_up_content,
        required_files: required_files
      )
    end

    private

    attr_reader(
      :file,
      :directory,
      :content,
      :already_relative_required_files,
      :required_files
    )

    def process_file
      file.open { |f| f.each { |line| process_line(line) } }
    end

    def process_line(line)
      require_match = line.match(/^require "([^"]+)"/)
      require_relative_match = line.match(/^require_relative "([^"]+)"/)

      if require_match
        required_files << require_match[1]
      elsif require_relative_match
        file = expand_path(require_relative_match[1])
        if already_relative_required_files.include?(file)
          # ignore line and continue
        else
          read_result =
            self.class.call(
              file,
              already_relative_required_files: already_relative_required_files
            )
          @required_files += read_result.required_files
          @content += "#{read_result.content}\n"
          already_relative_required_files << file
        end
      else
        @content += line
      end
    end

    def expand_path(path)
      Pathname.new(path_with_extension(path)).expand_path(directory)
    end

    def path_with_extension(path)
      path.end_with?(".rb") ? path : "#{path}.rb"
    end

    def cleaned_up_content
      content
        .gsub(/\n{3,}/, "\n\n")
        .gsub(/end\s+module DotfilesManager/, "\n\n")
    end

    class ReadResult
      attr_reader :content, :required_files

      def initialize(content:, required_files:)
        @content = content
        @required_files = required_files
      end
    end
  end
end

if File.expand_path($0) == File.expand_path(__FILE__)
  outfile =
    if ARGV.empty?
      Pathname.new("../exe/manage").expand_path(__dir__)
    else
      Pathname.new(ARGV.first).expand_path(Dir.pwd)
    end

  Build.call(outfile: outfile)
end
