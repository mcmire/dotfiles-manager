require_relative "globals"
require_relative "message_helpers"
require_relative "config_file"
require_relative "install_command"
require_relative "uninstall_command"
require_relative "error"

module DotfilesManager
  class Main
    def self.call(args)
      new(args).call
    end

    include MessageHelpers

    private_class_method :new

    def initialize(args)
      @args = args
      @config_file = ConfigFile.new(DotfilesManager.config_file_path)
      @command = nil
    end

    def call
      if !DotfilesManager.dotfiles_home.exist?
        raise Error.new(
                "Dotfiles home does not seem to exist: #{DotfilesManager.dotfiles_home}"
              )
      end

      read_config_file
      parse_args
      if !config.main.dry_run?
        write_config_file
      end
      if config.main.dry_run?
        info "Running in dry-run mode."
        puts
      end
      recurse(DotfilesManager.source_dir)
      command.print_result
    rescue Error => error
      error error.message
      puts error.details
      exit 1
    end

    private

    attr_reader :args, :config_file, :config, :command

    def read_config_file
      @config = config_file.read
    end

    def write_config_file
      config_file.write(config)
    end

    def parse_args
      if args.empty?
        raise Error.new(
                "Missing command.",
                details: "Please run #{$0} --help for usage."
              )
      end

      args.each do |arg|
        case arg
        when "--help"
          print_help
          exit
        when "install"
          @command = InstallCommand.new(config.install)
          break
        when "uninstall"
          @command = UninstallCommand.new(config.uninstall)
          break
        else
          raise Error.new(
                  "Unknown command #{arg.inspect}",
                  details: "Please run #{$0} --help for usage."
                )
        end
      end

      rest = []
      args[1..-1].each do |arg|
        case arg
        when "--dry-run", "--noop", "-n"
          config.main.dry_run = true
        when "--force", "-f"
          config.main.force = true
        when "--verbose", "-V"
          config.main.verbose = true
        when "--help", "-h", "-?"
          command.print_help
          exit
        else
          rest << arg
        end
      end

      command.parse_args(rest)
    end

    def print_help
      puts <<-TEXT
#{colorize :bold, "## DESCRIPTION"}

This script will either create symlinks in your home directory based on the
contents of src/ or delete previously installed symlinks.

#{colorize :bold, "## USAGE"}

The main way to call this script is by saying one of:

    #{$0} install
    #{$0} uninstall

If you want to know what either of these commands do, say:

    #{$0} install --help
    #{$0} uninstall --help
      TEXT
    end

    def recurse(directory)
      # Process overrides
      if directory == DotfilesManager.source_dir &&
           directory.join("__overrides__.cfg").exist?
        process_entry(directory.join("__overrides__.cfg"))
      end

      # Process files
      directory.children.each do |child|
        if child.file? &&
             !%w[__install__.sh __overrides__.cfg].include?(child.basename.to_s)
          process_entry(directory.join(child))
        end
      end

      # Process __install__.sh
      if directory.join("__install__.sh").exist? &&
           directory.join("__install__.sh").executable?
        process_entry(directory.join("__install__.sh"))
      end

      # Process subdirectories
      directory.children.each do |child|
        if child.directory?
          process_entry(child)
        end
      end
    end

    def process_entry(entry)
      if entry.directory? && !entry.join(".no-recurse").exist?
        recurse(entry)
      elsif entry.basename.to_s.end_with?(".__no-link__")
        command.process_non_link(entry)
      else
        command.process_entry(entry)
      end
    end
  end
end
