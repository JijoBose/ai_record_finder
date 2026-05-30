# frozen_string_literal: true

require_relative "providers"

module AIRecordFinder
  # Transport facade. Selects the provider configured via
  # `configuration.provider` and delegates chat completion to it.
  #
  # Kept as a stable entry point so callers (and AIAdapter) depend on a single
  # `#chat_completion(system_prompt:, user_prompt:)` interface regardless of
  # whether the backing provider is OpenAI, Anthropic, or another vendor.
  class Client
    def initialize(configuration:, connection: nil)
      @provider = Providers.build(configuration: configuration, connection: connection)
    end

    def chat_completion(system_prompt:, user_prompt:)
      @provider.chat_completion(system_prompt: system_prompt, user_prompt: user_prompt)
    end
  end
end
