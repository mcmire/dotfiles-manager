module DotfilesManager
  class Error < ArgumentError
    attr_reader :details

    def initialize(message, details: nil)
      super(message)
      @details = details
    end
  end
end
