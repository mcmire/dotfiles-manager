module Specs
  module Matchers
    def be_symlink_to(pathname2)
      BeSymlinkToMatcher.new(pathname2, sandbox: sandbox)
    end
    alias_method :be_a_symlink_to, :be_symlink_to

    class BeSymlinkToMatcher
      def initialize(pathname2, sandbox:)
        @pathname2 = Pathname.new(pathname2)
        @sandbox = sandbox
      end

      def matches?(pathname1)
        @pathname1 = Pathname.new(pathname1)

        pathname1.symlink? && pathname1.readlink == pathname2
      end

      def failure_message
        if pathname1.symlink?
          "Expected #{reduce_path(pathname1)} to be a symlink to " +
            "#{reduce_path(pathname2)}, but it was a symlink to " +
            "#{reduce_path(pathname1.readlink)}"
        else
          "Expected #{reduce_path(pathname1)} to be a symlink, but it was not"
        end
      end

      private

      attr_reader :pathname1, :pathname2, :sandbox

      def reduce_path(pathname)
        pathname.to_s.sub(sandbox.project_dir.to_s, "@")
      end
    end
  end
end
