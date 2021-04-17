module DotfilesManager
  module MessageHelpers
    COLOR_CODES = { bold: 1, red: 31, green: 32, yellow: 33, blue: 34 }

    def success(text)
      puts_in(:green, text)
    end

    def warning(text)
      puts_in(:yellow, text)
    end

    def info(text)
      puts_in(:bold, text)
    end

    def error(text)
      puts_in(:red, text)
    end

    private

    def puts_in(color, text)
      puts colorize(color, text)
    end

    def colorize(color, text)
      code =
        COLOR_CODES.fetch(color) do
          raise KeyError.new("Unrecognized color #{color.inspect}")
        end

      "\033[#{code}m#{text}\033[0m"
    end
  end
end
