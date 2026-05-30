# frozen_string_literal: true

module AIRecordFinder
  # Runtime configuration for AIRecordFinder.
  class Configuration
    DEFAULT_PROVIDER = :openai
    DEFAULT_MAX_LIMIT = 100
    DEFAULT_TIMEOUT = 15
    DEFAULT_MAX_TOKENS = 1024
    DEFAULT_ANTHROPIC_VERSION = "2023-06-01"

    # Per-provider defaults for endpoint and model. Used only when the
    # corresponding setting is not explicitly assigned.
    PROVIDER_DEFAULTS = {
      openai: {
        api_base_url: "https://api.openai.com/v1",
        model_name: "gpt-4o-mini"
      },
      anthropic: {
        api_base_url: "https://api.anthropic.com/v1",
        model_name: "claude-sonnet-4-6"
      }
    }.freeze

    # Backwards-compatible constants (OpenAI defaults).
    DEFAULT_MODEL_NAME = PROVIDER_DEFAULTS[:openai][:model_name]
    DEFAULT_API_BASE_URL = PROVIDER_DEFAULTS[:openai][:api_base_url]

    # `max_tokens` and `anthropic_version` are consumed only by the Anthropic
    # adapter; the OpenAI adapter ignores them.
    attr_accessor :api_key, :max_limit, :allowed_models, :request_timeout,
                  :temperature, :allowed_associations, :max_tokens,
                  :anthropic_version
    attr_writer :provider, :model_name, :api_base_url

    def initialize
      @api_key = @model_name = @api_base_url = nil
      @provider = DEFAULT_PROVIDER
      @max_limit = DEFAULT_MAX_LIMIT
      @allowed_models = []
      @request_timeout = DEFAULT_TIMEOUT
      @temperature = 0.0
      @allowed_associations = {}
      @max_tokens = DEFAULT_MAX_TOKENS
      @anthropic_version = DEFAULT_ANTHROPIC_VERSION
    end

    # Normalized provider symbol (e.g. :openai, :anthropic).
    def provider
      @provider.to_s.strip.downcase.to_sym
    end

    # Explicit model name, or the provider default when unset.
    def model_name
      @model_name || provider_default(:model_name)
    end

    # Explicit base URL, or the provider default when unset.
    def api_base_url
      @api_base_url || provider_default(:api_base_url)
    end

    private

    def provider_default(key)
      defaults = PROVIDER_DEFAULTS[provider] || PROVIDER_DEFAULTS[DEFAULT_PROVIDER]
      defaults.fetch(key)
    end
  end
end
