module Specs
  class BuildColorizedDocument
    def self.call(&block)
      ColorizedDocument.new.tap(&block).to_s
    end

    class ColorizedDocument
      def initialize(&block)
        @string = ""
      end

      def line(&block)
        string << ColorizedLine.new.tap(&block).to_s
      end

      def newline
        plain_line
      end

      def to_s
        string
      end

      def method_missing(name_with_underscore, text = "")
        name = name_with_underscore.to_s.sub(/^_+/, "")
        match = name.match(/^(.+)_line$/)

        if match
          string << (Colorize.call(match[1].to_sym, "#{text}") + "\n")
        else
          string << Colorize.call(name.to_sym, "#{text}")
        end
      end

      def respond_to_missing?(*)
        true
      end

      private

      attr_reader :string
    end

    class ColorizedLine
      def initialize(&block)
        @string = ""
      end

      def to_s
        "#{string}\n"
      end

      def method_missing(name_with_underscore, text)
        name = name_with_underscore.to_s.sub(/^_+/, "")
        string << Colorize.call(name.to_sym, text)
      end

      def respond_to_missing?(*)
        true
      end

      private

      attr_reader :string
    end

    class Colorize
      COLOR_CODES = { bold: 1, red: 31, green: 32, yellow: 33, blue: 34 }

      def self.call(color, text)
        if color == :plain
          text
        else
          code =
            COLOR_CODES.fetch(color) do
              raise KeyError.new("Unrecognized color #{color.inspect}")
            end
          "\033[#{code}m#{text}\033[0m"
        end
      end
    end
  end
end
