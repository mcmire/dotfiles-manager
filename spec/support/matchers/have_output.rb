module Specs
  module Matchers
    def have_output(*args, &block)
      HaveOutputMatcher.new(*args, &block)
    end

    class HaveOutputMatcher
      def initialize(expected_output = nil, &block)
        if block
          @expected_output = Specs::BuildColorizedDocument.call(&block)
        else
          @expected_output = expected_output
        end
      end

      def matches?(command)
        @command = command
        command.output == expected_output
      end

      def failure_message
        "\e[31mExpected command `#{command.to_s}` to have the following output:\e[0m\n\n" +
          start_of_output + expected_output.chomp + "\n" + end_of_output +
          "\n" + "But it had the following output instead:\n\n" +
          start_of_output + command.output.chomp + "\n" + end_of_output.chomp +
          "\n\n" + "\e[1mRaw output (expected, actual):\e[0m\n\n" +
          escape_control_characters(expected_output.chomp) + "\n" +
          escape_control_characters(command.output.chomp) + "\n"
      end

      private

      attr_reader :expected_output, :command

      def start_of_output
        "\033[35;1m~~ START OF OUTPUT ~~~~~~~~~~~~~~~~~\033[0m\n"
      end

      def end_of_output
        "\033[35;1m~~ END OF OUTPUT ~~~~~~~~~~~~~~~~~~~\033[0m\n"
      end

      def escape_control_characters(text)
        text.gsub("\e", "\\e").gsub("\n", "\\n")
      end
    end
  end
end
