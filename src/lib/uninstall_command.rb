require_relative "error"
require_relative "command"

module DotfilesManager
  class UninstallCommand < Command
    def print_help
      puts <<-TEXT
#{colorize :blue, "## DESCRIPTION"}

The 'uninstall' command will remove symlinks in your home folder based on the
contents of the src/ directory. It will iterate over the files there and do one
of a few things depending on what it encounters:

* If it encounters a file, it will remove the corresponding symlink from your
  home directory if it points to this file.
  EXAMPLE: src/tmux.conf removes a symlink at ~/.tmux.conf if the symlink points
  to this file.
* If it encounters a directory, it will recurse the directory and remove
  symlinks inside of your home directory according to the previous rule (with
  the directory renamed so as to begin with a dot).
  EXAMPLE: src/rbenv is iterated over to find src/rbenv/default-gems.
  src/rbenv/default-gems removes a symlink at ~/.rbenv/default-gems if the
  symlink points to this file.

There are some exceptions to this:

* If it encounters a file anywhere that ends in .__no-link__, it will remove the
  corresponding file from your home directory if it has the same content.
  EXAMPLE: src/gitconfig.__no-link__ removes a file at ~/.gitconfig if both
  files are the same.
* If it encounters a directory anywhere that has a .no-recurse file, it will
  NOT recurse the directory; it will remove the symlink for the directory if it
  points to the source directory.
  EXAMPLE: src/zsh, because it contains a .no-recurse file, removes a symlink at
  ~/.zsh.

No files that do not point to or match a corresponding file in src/ will be
removed unless you specify --force.

Finally, if you want to know what this command will do before running it for
real, and especially if this is the first time you're running it, use the
--dry-run option. For further output, use the --verbose option.

#{colorize :blue, "## USAGE"}

#{colorize :bold, "$0 $COMMAND [OPTIONS]"}

where OPTIONS are:

--dry-run, --noop, -n
  Don't actually change the filesystem.
--force, -f
  Usually symlinks that do not point to files in src/ and files that end in
  .__no-link__ that do not match the file they were copied from are not removed.
  This bypasses that.
--verbose, -V
  Show every command that is run when it is run.
--help, -h
  You're looking at it ;)
      TEXT
    end

    def process_entry(source)
      destination = build_destination_for(source)

      if destination.symlink?
        announce(:link, :delete, source: source, destination: destination)
        remove_file(destination)
      elsif destination.exists?
        if config.force?
          announce(:entry, :purge, source: source)
          remove_file(destination)
        else
          announce(:entry, :unlinked, destination: destination)
        end
      end
    end

    def process_non_link(file)
      source = file.sub(/\.__no-link__$/, "")
      destination = build_destination_for(source)

      if destination.exist?
        if files_have_same_content?(source, destination) || config.force?
          announce(:non_link, :delete, source: source, destination: destination)
          remove_file(destination)
        else
          announce(
            :non_link,
            :different,
            source: source,
            destination: destination
          )
        end
      else
        announce(:non_link, :absent, source: source, destination: destination)
      end
    end

    def print_result
      if config.dry_run?
        puts
        info "Don't worry — no files were created!"
      else
        puts
        success "All files have been removed, you're good!"
        puts "(Not the output you expect? Run --force to force-remove skipped files.)"
      end
    end

    protected

    def command_name
      :uninstall
    end

    def determine_action_color!(action)
      case action
      when :delete, :purge, :overwrite
        :red
      when :absent, :different, :unlinked, :unrecognized, :unknown
        :blue
      else
        raise Error.new(
                "Could not determine color for action #{action.inspect}."
              )
      end
    end

    def action_width
      12
    end

    def subaction_width
      8
    end

    def _announce(subaction:, prefix:, source: nil, destination:)
      if source
        # TODO: This is backwards
        puts "#{prefix} #{destination} <-- #{source}"
      else
        puts "#{prefix} #{destination}"
      end
    end

    private

    def remove_file(file)
      if config.verbose?
        puts "Removing #{file}..."
      end

      if !config.dry_run?
        file.delete
      end
    end
  end
end
