module Specs
  module TextHelpers
    def colorize(&block)
      Specs::BuildColorizedDocument.call(&block)
    end
  end
end

RSpec.configure { |config| config.include Specs::TextHelpers }
