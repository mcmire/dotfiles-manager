module Specs
  module Matchers
    def be_same_file_as(pathname2)
      BeSameFileAsMatcher.new(pathname2, sandbox: sandbox)
    end

    class BeSameFileAsMatcher
      def initialize(pathname2, sandbox:)
        @pathname2 = Pathname.new(pathname2)
        @sandbox = sandbox
      end

      def matches?(pathname1)
        @pathname1 = Pathname.new(pathname1)

        FileUtils.identical?(pathname1, pathname2)
      end

      def failure_message
        "Expected #{reduce_path(pathname1)} to be the same file as " +
          "#{reduce_path(pathname2)}, but it was not."
      end

      private

      attr_reader :pathname1, :pathname2, :sandbox

      def reduce_path(pathname)
        pathname.to_s.sub(sandbox.project_dir.to_s, "@")
      end
    end
  end
end
