# frozen_string_literal: true

module AIRecordFinder
  # Extracts a safe summary of model schema that can be sent to the AI.
  class SchemaIntrospector
    def initialize(model)
      @model = model
    end

    def call
      {
        model: @model.name,
        table: @model.table_name,
        columns: columns_summary,
        associations: associations_summary,
        enums: enums_summary
      }
    end

    private

    def columns_summary
      @model.columns.each_with_object({}) do |column, memo|
        memo[column.name] = {
          type: column.type,
          null: column.null,
          default: column.default
        }
      end
    end

    def associations_summary
      @model.reflect_on_all_associations.each_with_object({}) do |association, memo|
        memo[association.name.to_s] = {
          macro: association.macro,
          class_name: association.class_name
        }
      end
    end

    def enums_summary
      return {} unless @model.respond_to?(:defined_enums)

      @model.defined_enums.transform_values(&:keys)
    end
  end
end
