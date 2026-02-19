# frozen_string_literal: true

require "faraday"
require "json"

module AIRecordFinder
  # HTTP client for OpenAI-compatible chat completion APIs.
  class Client
    CHAT_COMPLETIONS_PATH = "/chat/completions"

    def initialize(configuration:)
      @configuration = configuration
      validate_configuration!
    end

    def chat_completion(system_prompt:, user_prompt:)
      response = connection.post(CHAT_COMPLETIONS_PATH) do |req|
        req.headers["Authorization"] = "Bearer #{@configuration.api_key}"
        req.headers["Content-Type"] = "application/json"
        req.body = JSON.generate(payload(system_prompt, user_prompt))
      end

      parsed = parse_body(response.body)
      extract_content(parsed)
    rescue Faraday::Error => e
      raise AIResponseError, "AI request failed: #{e.message}"
    end

    private

    def connection
      @connection ||= Faraday.new(url: @configuration.api_base_url) do |f|
        f.options.timeout = @configuration.request_timeout
        f.options.open_timeout = @configuration.request_timeout
        f.adapter Faraday.default_adapter
      end
    end

    def payload(system_prompt, user_prompt)
      {
        model: @configuration.model_name,
        temperature: @configuration.temperature,
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: user_prompt }
        ]
      }
    end

    def parse_body(body)
      JSON.parse(body)
    rescue JSON::ParserError
      raise AIResponseError, "AI response body is not valid JSON"
    end

    def extract_content(parsed)
      choices = parsed["choices"]
      return choices.first.dig("message", "content") if choices.is_a?(Array) && choices.first

      raise AIResponseError, "AI response missing choices.message.content"
    end

    def validate_configuration!
      if @configuration.api_key.to_s.strip.empty?
        raise AIResponseError, "Missing API key. Set AIRecordFinder.configure { |c| c.api_key = ... }"
      end
    end
  end
end
