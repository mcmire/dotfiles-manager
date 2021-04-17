require "open3"

module Specs
  class RunCommand
    def self.call(*command, **options)
      new(*command, **options).call
    end

    private_class_method :new

    def initialize(*command, env: {}, **options)
      @command = command
      @env = env
      @options = options
    end

    def call
      input, output, wait_thr, *rest = Open3.popen2e(env, *command, **options)
      input.close
      exit_status = wait_thr.value

      if exit_status.success?
        Command.new(
          string: stringified_command,
          output: output.read,
          exit_status: exit_status
        )
      else
        raise CommandFailedError.new(
                "Command failed: #{stringified_command}\n\n#{output.read}"
              )
      end
    end

    private

    attr_reader :command, :env, :options

    def stringified_command
      Shellwords.join(command)
    end

    class CommandFailedError < StandardError
    end

    class Command
      attr_reader :output, :exit_status

      def initialize(string:, output:, exit_status:)
        @string = string
        @output = output
        @exit_status = exit_status
      end

      def success?
        exit_status.success?
      end

      def to_s
        string
      end

      private

      attr_reader :string
    end
  end
end
