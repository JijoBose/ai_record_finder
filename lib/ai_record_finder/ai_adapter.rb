# frozen_string_literal: true

require "json"

module AIRecordFinder
  # Converts natural language + schema prompt into parsed DSL JSON.
  class AIAdapter
    def initialize(client:)
      @client = client
    end

    def call(system_prompt:, user_prompt:)
      raw_content = @client.chat_completion(system_prompt: system_prompt, user_prompt: user_prompt)
      parse_json(extract_json(raw_content))
    rescue AIResponseError
      raise
    rescue StandardError => e
      raise AIResponseError, "Failed to parse AI response: #{e.message}"
    end

    private

    def extract_json(raw_content)
      content = raw_content.to_s.strip

      if content.start_with?("```")
        content = content.gsub(/\A```(?:json)?\s*/i, "").gsub(/\s*```\z/, "")
      end

      first_brace = content.index("{")
      last_brace = content.rindex("}")
      raise AIResponseError, "No JSON object found in AI response" unless first_brace && last_brace

      content[first_brace..last_brace]
    end

    def parse_json(json_string)
      parsed = JSON.parse(json_string)
      raise AIResponseError, "AI response must be a JSON object" unless parsed.is_a?(Hash)

      parsed
    rescue JSON::ParserError
      raise AIResponseError, "AI returned invalid JSON"
    end
  end
end
