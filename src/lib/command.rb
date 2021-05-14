require "shellwords"

require_relative "message_helpers"

module DotfilesManager
  class Command
    include MessageHelpers

    def initialize(config)
      @config = config
    end

    def parse_args(args)
      future_name = nil
      future_value = nil

      args.each do |arg|
        case arg
        when /^--(.+)$/
          if future_name
            if future_value == nil
              config.public_send("#{future_name}=", true)
            else
              config.public_send("#{future_name}=", future_value)
            end
            future_name = nil
            future_value = nil
          end
          future_name = $1.gsub("-", "_")
        else
          if future_name
            if future_value == nil
              future_value = arg
            elsif future_value.is_a?(Array)
              future_value << arg
            else
              future_value = [future_value, arg]
            end
          else
            raise Error.new(
                    "Unknown argument #{args[i].inspect} given.",
                    details: "Please run #{$0} #{command_name} --help for usage."
                  )
          end
        end
      end

      if future_name
        if future_value == nil
          config.public_send("#{future_name}=", true)
        else
          config.public_send("#{future_name}=", future_value)
        end
      end
    end

    def print_help
      raise NotImplementedError
    end

    def process_entry(entry)
      raise NotImplementedError
    end

    def process_non_link(entry)
      raise NotImplementedError
    end

    def print_result
      raise NotImplementedError
    end

    protected

    def command_name
      raise NotImplementedError
    end

    def build_destination_for(source)
      path = source.relative_path_from(DotfilesManager.source_dir)
      DotfilesManager.dotfiles_home.join(".#{path}")
    end

    def announce(subaction, action, source: nil, destination: nil)
      if source
        formatted_source_path = format_source_path(source)
      end

      if destination
        formatted_destination_path =
          format_destination_path(destination, directory: source&.directory?)
      end

      color = determine_action_color!(action)

      prefix =
        format_announcement_prefix(
          color: color,
          action: action,
          action_width: action_width,
          subaction: subaction,
          subaction_width: subaction_width
        )

      _announce(
        subaction: subaction,
        prefix: prefix,
        source: formatted_source_path,
        destination: formatted_destination_path
      )
    end

    def determine_action_color!(action)
      raise NotImplementedError
    end

    def action_width
      raise NotImplementedError
    end

    def subaction_width
      raise NotImplementedError
    end

    def _announce(subaction:, prefix:, **rest)
      raise NotImplementedError
    end

    private

    def format_source_path(source)
      path =
        "$DOTFILES/" +
          source.relative_path_from(DotfilesManager.project_dir).to_s

      source.directory? ? "#{path}/" : path
    end

    def format_destination_path(destination, directory:)
      path =
        "~/" +
          destination.relative_path_from(DotfilesManager.dotfiles_home).to_s
      directory ? "#{path}/" : path
    end

    def format_announcement_prefix(
      color:,
      action:,
      action_width:,
      subaction:,
      subaction_width:
    )
      colorized_action = colorize(color, "%#{action_width}s" % action)
      colorized_subaction =
        colorize(:yellow, "%#{subaction_width}s" % subaction)
      "#{colorized_action} #{colorized_subaction}"
    end

    def files_have_same_content?(file1, file2)
      file1.read == file2.read
    end
  end
end
