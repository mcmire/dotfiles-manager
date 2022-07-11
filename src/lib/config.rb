require "forwardable"

module DotfilesManager
  class Config
    def initialize(data)
      @data = data.transform_keys(&:to_sym)
    end

    def main
      @main ||= MainLevel.new(data.fetch(:main, {}))
    end

    def install
      @install ||= CommandLevel.new(main, data.fetch(:install, {}))
    end

    def uninstall
      @uninstall ||= CommandLevel.new(main, data.fetch(:uninstall, {}))
    end

    def to_h
      { main: main.to_h, install: install.to_h, uninstall: uninstall.to_h }
    end

    private

    class MainLevel
      def initialize(data)
        @data = default_data.merge(data.transform_keys(&:to_sym))
      end

      def dry_run?
        data.fetch(:dry_run)
      end

      def dry_run=(value)
        data[:dry_run] = value
      end

      def force?
        data.fetch(:force)
      end

      def force=(value)
        data[:force] = value
      end

      def verbose?
        data.fetch(:verbose)
      end

      def verbose=(value)
        data[:verbose] = value
      end

      def to_h
        data
      end

      private

      attr_reader :data

      def default_data
        { dry_run: false, force: false, verbose: false }
      end
    end

    class CommandLevel
      extend Forwardable

      def_delegators :main, :dry_run?, :force?, :verbose?

      def initialize(main, data)
        @main = main
        @data = data.transform_keys(&:to_sym)
      end

      def method_missing(name, *args, &block)
        if name.to_s.end_with?("=")
          data[name.to_s.sub(/=$/, "").to_sym] = args.first
        else
          data.fetch(name.to_sym) { super }
        end
      end

      def to_h
        data
      end

      private

      attr_reader :main, :data
    end

    private

    attr_reader :data
  end
end
