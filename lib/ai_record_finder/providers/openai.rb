# frozen_string_literal: true

require_relative "base"

module AIRecordFinder
  module Providers
    # OpenAI (and OpenAI-compatible) Chat Completions API.
    class OpenAI < Base
      ENDPOINT_PATH = "chat/completions"

      private

      def endpoint_path
        ENDPOINT_PATH
      end

      def request_headers
        {
          "Authorization" => "Bearer #{configuration.api_key}",
          "Content-Type" => "application/json"
        }
      end

      def request_payload(system_prompt, user_prompt)
        {
          model: configuration.model_name,
          temperature: configuration.temperature,
          messages: [
            { role: "system", content: system_prompt },
            { role: "user", content: user_prompt }
          ]
        }
      end

      def extract_content(parsed)
        choices = parsed["choices"]
        if choices.is_a?(Array) && choices.first
          # content is null when the model replies with tool_calls only.
          content = choices.first.dig("message", "content")
          return content unless content.nil?
        end

        raise AIResponseError, "AI response missing choices[0].message.content"
      end
    end
  end
end
