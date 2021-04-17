require_relative "error"
require_relative "command"

module DotfilesManager
  class InstallCommand < Command
    def print_help
      puts <<-TEXT
#{colorize :blue, "## DESCRIPTION"}

The 'install' command will create symlinks in your home folder based on the
contents of the src/ directory. It will iterate over the files there and do one
of a few things depending on what it encounters:

* If it encounters a file, it will create a symlink in your home folder that
  points to this file (with the file renamed so as to begin with a dot).
  EXAMPLE: src/tmux.conf creates a symlink at ~/.tmux.conf.
* If it encounters a directory, it will recurse the directory and create
  symlinks inside of your home directory according to the previous rule (with
  the directory renamed so as to begin with a dot).
  EXAMPLE: src/rbenv is iterated over to find src/rbenv/default-gems.
  src/rbenv/default-gems then creates a symlink at ~/.rbenv/default-gems.

There are some exceptions to this:

* If it encounters a file anywhere called __install__.sh, it will treat that
  file as an executable and run it. (It assumes you have chmod'd this file
  correctly and that this script has a shebang.)
* If it encounters a file anywhere that ends in .__no-link__, it will copy this
  file to your home directory instead of creating a symlink.
  EXAMPLE: src/gitconfig.__no-link__ creates a file (not a symlink) at
  ~/.gitconfig.
* If it encounters a directory anywhere that has a .no-recurse file, it will
  NOT recurse the directory; instead, it will create a symlink for the
  directory.
  EXAMPLE: src/zsh, because it contains a .no-recurse file, creates a symlink at
  ~/.zsh.

No files will be overwritten unless you specify --force.

Finally, if you want to know what this command will do before running it for
real, and especially if this is the first time you're running it, use the
--dry-run option. For further output, use the --verbose option.

#{colorize :blue, "## USAGE"}

#{colorize :bold, "$0 $COMMAND [FIRST_TIME_OPTIONS] [OTHER_OPTIONS]"}

where FIRST_TIME_OPTIONS are one or more of:

--git-name NAME
  The name that you'll use to author Git commits.
--git-email EMAIL
  The email that you'll use to author Git commits.

and OTHER_OPTIONS are one or more of:

--dry-run, --noop, -n
  Don't actually change the filesystem.
--force, -f
  Usually dotfiles that already exist are not overwritten. This bypasses that.
--verbose, -V
  Show every command that is run when it is run.
--help, -h
  You're looking at it ;)
      TEXT
    end

    def process_entry(source)
      destination = build_destination_for(source)

      # TODO: Have this be JSON or TOML
      if source.basename.to_s == "__overrides__.cfg"
        announce(:config, :read, source: source)
        read_config_file(source)
        # TODO: Have this be whatever
      elsif source.basename.to_s == "__install__.sh"
        # TODO: Should this be 'script' or something?
        announce(:command, :run, source: source)
        run_install_script(source)
      else
        # TODO: This is actually switched
        link_file_with_announcement(source, destination)
      end
    end

    def process_non_link(source)
      destination = build_destination_for(source.sub(/\.__no-link__$/, ""))

      if destination.exist? || destination.symlink?
        if config.force?
          announce(
            :non_link,
            :overwrite,
            source: source,
            destination: destination
          )
          copy_file(source, destination)
        else
          # Is 'entry' correct here? My guess is that we don't know what kind of
          # file it is
          announce(:entry, :exists, source: source, destination: destination)
        end
      else
        # TODO: Change this to 'copy' 'file'
        announce(:non_link, :create, source: source, destination: destination)
        copy_file(source, destination)
      end
    end

    def print_result
      if config.dry_run?
        puts
        info "Don't worry — no files were created!"
      else
        puts

        # TODO: Update this message to only appear if no changes were made?
        success "All files are installed, you're good!"
        puts "(Not the output you expect? Run --force to force-update skipped files.)"
      end
    end

    protected

    def command_name
      :install
    end

    def determine_action_color!(action)
      case action
      when :create, :run, :read
        :green
      when :overwrite
        :red
      when :exists, :same, :unknown
        :blue
      else
        raise Error.new(
                "Could not determine color for action #{action.inspect}."
              )
      end
    end

    def action_width
      8
    end

    def subaction_width
      8
    end

    def _announce(subaction:, prefix:, source: nil, destination: nil)
      if source
        if destination
          # TODO: This is backwards
          puts "#{prefix} #{source} --> #{destination}"
        else
          puts "#{prefix} #{source}"
        end
      else
        puts "#{prefix} #{destination}"
      end
    end

    private

    attr_reader :config

    # TODO: If any of the designated source files here are inside of the
    # source dir, then symlinks will also be created for them elsewhere
    def read_config_file(file)
      JSON
        .parse(file.read)
        .fetch("symlinks")
        .each do |symlink_path, target_path|
          symlink = DotfilesManager.source_dir.join(symlink_path)
          target = Pathname.new(target_path.gsub("~/", ENV["HOME"] + "/"))
          link_file_with_announcement(symlink, target)
        end
    end

    def run_install_script(file)
      env = config.to_h.transform_keys { |k| k.to_s.upcase }

      if config.verbose?
        inspect_command(env, file.to_s)
      end

      if !config.dry_run?
        if !system(env, file.to_s, out: "/dev/null", err: "/dev/null")
          raise Error.new(
                  "#{format_source_path(file)} failed with exit code #{$?}.",
                  details:
                    "Take a closer look at this file. Perhaps you're using set -e " +
                      "and some command is failing?"
                )
        end
      end
    end

    def link_file_with_announcement(symlink, target)
      if target.exist? || target.symlink?
        if config.force?
          announce(:link, :overwrite, source: symlink, destination: target)
          link_file(symlink, target)
        else
          announce(:link, :exists, source: symlink, destination: target)
        end
      else
        announce(:link, :create, source: symlink, destination: target)
        link_file(symlink, target)
      end
    end

    def link_file(symlink, target)
      if config.verbose?
        puts "Making directory #{target.dirname}..."

        if config.force?
          puts "Removing #{target}..."
        end

        puts "Symlinking #{symlink} to #{target}..."
      end

      if !config.dry_run?
        target.parent.mkpath

        if config.force?
          FileUtils.rm_rf(target)
        end

        target.make_symlink(symlink)
      end
    end

    def copy_file(source, destination)
      if config.verbose?
        puts "Making directory #{destination.dirname}..."

        if config.force?
          puts "Removing #{destination}..."
        end

        puts "Copying #{source} to #{target}..."
      end

      if !config.dry_run?
        destination.parent.mkpath

        if config.force?
          FileUtils.rm_rf(destination)
        end

        FileUtils.cp(source, destination)
      end
    end
  end
end
