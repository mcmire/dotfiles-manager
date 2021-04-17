require "forwardable"

require_relative "../../bin/build.rb"
require_relative "../../bin/setup_sandbox.rb"

module Specs
  module SandboxHelpers
    extend Forwardable

    def_delegators :sandbox, :dotfiles, :dotfiles_home, :source_dir

    def sandbox
      @sandbox ||= TestSandbox.new
    end

    def sandbox_dir
      sandbox.root_dir
    end
  end
end

RSpec.configure do |config|
  config.include Specs::SandboxHelpers

  config.before do
    sandbox.provision
    Build.call(outfile: dotfiles.join("bin/manage"))
  end
end
