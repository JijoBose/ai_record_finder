# frozen_string_literal: true

module AIRecordFinder
  # Runtime configuration for AIRecordFinder.
  class Configuration
    DEFAULT_MODEL_NAME = "gpt-4o-mini"
    DEFAULT_API_BASE_URL = "https://api.openai.com/v1"
    DEFAULT_MAX_LIMIT = 100
    DEFAULT_TIMEOUT = 15

    attr_accessor :api_key, :model_name, :max_limit, :allowed_models,
                  :api_base_url, :request_timeout, :temperature,
                  :allowed_associations

    def initialize
      @api_key = nil
      @model_name = DEFAULT_MODEL_NAME
      @max_limit = DEFAULT_MAX_LIMIT
      @allowed_models = []
      @api_base_url = DEFAULT_API_BASE_URL
      @request_timeout = DEFAULT_TIMEOUT
      @temperature = 0.0
      @allowed_associations = {}
    end
  end
end
