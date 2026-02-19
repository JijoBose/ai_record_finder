# frozen_string_literal: true

require_relative "ai_record_finder/version"
require_relative "ai_record_finder/errors"
require_relative "ai_record_finder/configuration"
require_relative "ai_record_finder/client"
require_relative "ai_record_finder/schema_introspector"
require_relative "ai_record_finder/prompt_builder"
require_relative "ai_record_finder/ai_adapter"
require_relative "ai_record_finder/dsl_parser"
require_relative "ai_record_finder/query_builder"
require_relative "ai_record_finder/safety_guard"

begin
  require_relative "ai_record_finder/railtie"
rescue LoadError
  # Rails is optional outside Rails applications.
end

# Main entry point for natural-language to ActiveRecord query translation.
module AIRecordFinder
  class << self
    # @return [AIRecordFinder::Configuration]
    def configuration
      @configuration ||= Configuration.new
    end

    # @yieldparam config [AIRecordFinder::Configuration]
    def configure
      yield(configuration)
    end

    # Converts a natural-language prompt into an ActiveRecord::Relation.
    #
    # @param prompt [String]
    # @param model [Class]
    # @param ai_adapter [#call, nil] Optional injectable adapter for tests.
    # @return [ActiveRecord::Relation]
    def query(prompt:, model:, ai_adapter: nil)
      SafetyGuard.validate_model!(model: model, configuration: configuration)

      schema = SchemaIntrospector.new(model).call
      prompt_builder = PromptBuilder.new(schema: schema, max_limit: configuration.max_limit)
      adapter = ai_adapter || AIAdapter.new(client: Client.new(configuration: configuration))

      raw_dsl = adapter.call(
        system_prompt: prompt_builder.system_prompt,
        user_prompt: prompt_builder.user_prompt(prompt)
      )

      dsl = DSLParser.new(
        model: model,
        schema: schema,
        dsl: raw_dsl,
        max_limit: configuration.max_limit
      ).call

      QueryBuilder.new(model: model, dsl: dsl, configuration: configuration).call
    end

    # Resets runtime configuration. Intended for tests.
    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
