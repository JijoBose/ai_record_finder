# frozen_string_literal: true

module AIRecordFinder
  # Builds an ActiveRecord::Relation from validated DSL.
  class QueryBuilder
    def initialize(model:, dsl:, configuration:)
      @model = model
      @dsl = dsl
      @configuration = configuration
      @arel_table = model.arel_table
    end

    def call
      SafetyGuard.validate_joins!(model: @model, joins: @dsl["joins"], configuration: @configuration)

      relation = @model.all
      relation = SafetyGuard.apply_tenant_scope(model: @model, relation: relation)
      relation = apply_joins(relation)
      relation = apply_filters(relation)
      relation = apply_sort(relation)
      relation.limit(@dsl["limit"])
    end

    private

    def apply_joins(relation)
      Array(@dsl["joins"]).reduce(relation) do |current_relation, association_name|
        current_relation.left_joins(association_name.to_sym)
      end
    end

    def apply_filters(relation)
      @dsl.fetch("filters", []).reduce(relation) do |current_relation, filter|
        field = filter.fetch("field")
        operator = filter.fetch("operator")
        value = filter["value"]

        apply_filter(current_relation, field, operator, value)
      end
    end

    def apply_filter(relation, field, operator, value)
      attribute = @arel_table[field]

      case operator
      when "eq"
        relation.where(field => value)
      when "gt"
        relation.where(attribute.gt(value))
      when "lt"
        relation.where(attribute.lt(value))
      when "gte"
        relation.where(attribute.gteq(value))
      when "lte"
        relation.where(attribute.lteq(value))
      when "between"
        relation.where(field => value[0]..value[1])
      when "in"
        relation.where(field => value)
      when "like"
        pattern = "%#{ActiveRecord::Base.sanitize_sql_like(value.to_s)}%"
        relation.where(attribute.matches(pattern))
      else
        raise InvalidDSL, "Unsupported operator: #{operator}"
      end
    end

    def apply_sort(relation)
      sort = @dsl["sort"]
      return relation unless sort

      field = sort.fetch("field")
      direction = sort.fetch("direction")
      relation.reorder(field => direction.to_sym)
    end
  end
end
