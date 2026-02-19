# frozen_string_literal: true

require "json"

module AIRecordFinder
  # Builds strict prompts so the AI emits only the expected JSON DSL.
  class PromptBuilder
    ALLOWED_OPERATORS = %w[eq gt lt gte lte between in like].freeze

    def initialize(schema:, max_limit:)
      @schema = schema
      @max_limit = max_limit
    end

    def system_prompt
      <<~PROMPT
        You convert user requests into a strict query JSON DSL for ActiveRecord.
        Output rules:
        - Return ONLY JSON. No markdown, no code fences, no commentary.
        - Never output SQL, pseudo-SQL, or Ruby code.
        - Do not include keys not listed below.
        - Use only the provided schema fields.
        - Limit must be an integer between 1 and #{@max_limit}.
        - Operators allowed: #{ALLOWED_OPERATORS.join(', ')}

        JSON format:
        {
          "filters": [
            { "field": "status", "operator": "eq", "value": "unpaid" }
          ],
          "limit": 50,
          "sort": { "field": "created_at", "direction": "desc" }
        }

        Field constraints:
        - Allowed fields are exactly these columns: #{@schema[:columns].keys.sort.join(', ')}
        - Allowed sort directions: asc, desc
        - For operator "between", value must be an array of two values
        - For operator "in", value must be an array

        Schema summary:
        #{JSON.pretty_generate(@schema)}
      PROMPT
    end

    def user_prompt(natural_language_prompt)
      natural_language_prompt.to_s.strip
    end
  end
end
