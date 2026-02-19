# frozen_string_literal: true

module AIRecordFinder
  # Base error class for all gem-specific failures.
  class Error < StandardError; end

  # Raised when the given model is not an ActiveRecord model.
  class InvalidModelError < Error; end

  # Raised when AI output does not conform to the expected DSL.
  class InvalidDSL < Error; end

  # Raised when AI API responses are malformed or unusable.
  class AIResponseError < Error; end

  # Raised when a model is not explicitly whitelisted.
  class UnauthorizedModel < Error; end
end
