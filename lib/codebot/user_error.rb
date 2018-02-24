# frozen_string_literal: true

module Codebot
  # This class serves as a parent class for errors caused by the user entering
  # invalid data.
  class UserError < RuntimeError
    # Constructs a new user error.
    #
    # @param message [String] the error message
    def initialize(message)
      super
    end
  end
end
