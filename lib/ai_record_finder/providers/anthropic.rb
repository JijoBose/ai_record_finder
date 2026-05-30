# frozen_string_literal: true

require_relative "base"

module AIRecordFinder
  module Providers
    # Anthropic native Messages API (https://api.anthropic.com/v1/messages).
    #
    # Differs from OpenAI: x-api-key auth + anthropic-version header, a
    # top-level `system` prompt, a required `max_tokens`, and a response whose
    # text lives in a `content` array of typed blocks rather than `choices`.
    class Anthropic < Base
      ENDPOINT_PATH = "messages"

      private

      def endpoint_path
        ENDPOINT_PATH
      end

      def request_headers
        {
          "x-api-key" => configuration.api_key,
          "anthropic-version" => configuration.anthropic_version,
          "Content-Type" => "application/json"
        }
      end

      def request_payload(system_prompt, user_prompt)
        {
          model: configuration.model_name,
          max_tokens: configuration.max_tokens,
          temperature: configuration.temperature,
          system: system_prompt,
          messages: [
            { role: "user", content: user_prompt }
          ]
        }
      end

      def extract_content(parsed)
        blocks = parsed["content"]
        if blocks.is_a?(Array)
          text_block = blocks.find { |block| block.is_a?(Hash) && block["type"] == "text" }
          return text_block["text"] if text_block && !text_block["text"].nil?
        end

        raise AIResponseError, "AI response missing content text block"
      end
    end
  end
end
