require "json"

require_relative "config"

module DotfilesManager
  class ConfigFile
    def initialize(path)
      @path = path
    end

    def read
      path.exist? ? Config.new(JSON.parse(path.read)) : Config.new({})
    end

    def write(config)
      hash = config.to_h
      path.write(JSON.pretty_generate(hash.slice(*(hash.keys - [:main]))))
    end

    private

    attr_reader :path
  end
end
