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
      @joins = requested_joins
      SafetyGuard.validate_joins!(model: @model, joins: @joins, configuration: @configuration)

      relation = @model.all
      relation = SafetyGuard.apply_tenant_scope(model: @model, relation: relation)
      relation = apply_joins(relation)
      relation = apply_filters(relation)
      relation = apply_sort(relation)
      relation.limit(@dsl["limit"])
    end

    private

    def apply_joins(relation)
      @joins.reduce(relation) do |current_relation, association_name|
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
      attribute = resolve_attribute(field)

      case operator
      when "eq"
        relation.where(attribute.eq(value))
      when "gt"
        relation.where(attribute.gt(value))
      when "lt"
        relation.where(attribute.lt(value))
      when "gte"
        relation.where(attribute.gteq(value))
      when "lte"
        relation.where(attribute.lteq(value))
      when "between"
        relation.where(attribute.between(value[0]..value[1]))
      when "in"
        relation.where(attribute.in(value))
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
      attribute = resolve_attribute(field)
      relation.reorder(direction == "asc" ? attribute.asc : attribute.desc)
    end

    def requested_joins
      explicit = Array(@dsl["joins"]).map(&:to_s)
      from_filters = @dsl.fetch("filters", []).map { |filter| association_for_field(filter.fetch("field")) }.compact
      from_sort = [association_for_field(@dsl.dig("sort", "field"))].compact

      (explicit + from_filters + from_sort).uniq
    end

    def association_for_field(field)
      return nil unless field.to_s.include?(".")

      field.to_s.split(".", 2).first
    end

    def resolve_attribute(field)
      field_name = field.to_s
      return @arel_table[field_name] unless field_name.include?(".")

      association_name, column_name = field_name.split(".", 2)
      reflection = @model.reflect_on_association(association_name.to_sym)
      raise InvalidDSL, "Unknown association join: #{association_name}" unless reflection

      reflection.klass.arel_table[column_name]
    end
  end
end
