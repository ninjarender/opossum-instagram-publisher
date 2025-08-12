# frozen_string_literal: true

require_relative "opossum/version"
require_relative "opossum/authenticator"
require_relative "opossum/user_details"
require_relative "opossum/publisher"

module Opossum
  # Custom error class for Opossum gem
  class Error < StandardError
    attr_reader :code, :subcode

    def initialize(message, code: nil, subcode: nil)
      super(message)

      @code = code
      @subcode = subcode
    end
  end
end
