# frozen_string_literal: true

require_relative "providers/base"
require_relative "providers/openai"
require_relative "providers/anthropic"

module AIRecordFinder
  # Provider strategy registry. Maps a configured provider symbol to the
  # concrete transport that speaks that vendor's chat API.
  module Providers
    REGISTRY = {
      openai: OpenAI,
      anthropic: Anthropic
    }.freeze

    # @param configuration [AIRecordFinder::Configuration]
    # @param connection [Faraday::Connection, nil] injectable transport (tests)
    # @return [AIRecordFinder::Providers::Base]
    def self.build(configuration:, connection: nil)
      provider_class = REGISTRY[configuration.provider]
      unless provider_class
        raise ConfigurationError,
              "Unknown provider #{configuration.provider.inspect}. " \
              "Supported providers: #{REGISTRY.keys.join(", ")}"
      end

      provider_class.new(configuration: configuration, connection: connection)
    end

    def self.supported
      REGISTRY.keys
    end
  end
end
