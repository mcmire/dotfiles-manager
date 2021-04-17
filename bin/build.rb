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
    @content ||= Read.call(infile)
  end

  class Read
    def self.call(file, already_required_files: Set.new)
      new(file, already_required_files: already_required_files).call
    end

    private_class_method :new

    def initialize(file, already_required_files:)
      @file = file
      @directory = file.dirname
      @content = ""
      @already_required_files = already_required_files
    end

    def call
      file.open { |f| f.each { |line| process_line(line) } }
      content.gsub(/\n{3,}/, "\n\n")
    end

    private

    attr_reader :file, :directory, :content, :already_required_files

    def process_line(line)
      match = line.match(/^require_relative "([^"]+)"/)

      if match
        file = expand_path(match[1])
        if already_required_files.include?(file)
          # ignore line and continue
        else
          content =
            self.class.call(
              file,
              already_required_files: already_required_files
            )
          @content += "#{content}\n"
          already_required_files << file
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
