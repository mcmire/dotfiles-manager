module Specs
  module CommandHelpers
    def run!(*command, env: {})
      Specs::RunCommand.call(
        *command,
        env: {
          "DOTFILES_HOME" => sandbox.dotfiles_home.to_s,
          **env
        },
        chdir: sandbox.dotfiles.to_s
      )
    end
  end
end

RSpec.configure { |config| config.include Specs::CommandHelpers }
