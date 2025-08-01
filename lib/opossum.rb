# frozen_string_literal: true

require_relative "opossum/version"
require_relative "opossum/authenticator"
require_relative "opossum/user_details"
require_relative "opossum/publisher"

module Opossum
  class Error < StandardError; end
end
