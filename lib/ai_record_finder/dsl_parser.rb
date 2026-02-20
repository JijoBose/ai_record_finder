# frozen_string_literal: true

module AIRecordFinder
  # Validates and normalizes the AI-generated query DSL.
  class DSLParser
    ALLOWED_TOP_LEVEL_KEYS = %w[filters limit sort joins].freeze
    ALLOWED_OPERATORS = %w[eq gt lt gte lte between in like].freeze
    ALLOWED_SORT_DIRECTIONS = %w[asc desc].freeze

    def initialize(model:, schema:, dsl:, max_limit:)
      @model = model
      @schema = schema
      @dsl = dsl
      @max_limit = max_limit
      @columns = @schema.fetch(:columns).keys
      @associations = @schema.fetch(:associations).keys
      @association_columns = @schema.fetch(:association_columns, {})
    end

    def call
      raise InvalidDSL, "DSL must be a JSON object" unless @dsl.is_a?(Hash)

      dsl = deep_stringify_keys(@dsl)
      validate_top_level_keys!(dsl)

      filters = validate_filters!(dsl.fetch("filters", []))
      limit = validate_limit!(dsl.fetch("limit", @max_limit))
      sort = validate_sort!(dsl["sort"])
      joins = validate_joins!(dsl.fetch("joins", []))

      {
        "filters" => filters,
        "limit" => limit,
        "sort" => sort,
        "joins" => joins
      }
    end

    private

    def deep_stringify_keys(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, val), memo|
          memo[key.to_s] = deep_stringify_keys(val)
        end
      when Array
        value.map { |val| deep_stringify_keys(val) }
      else
        value
      end
    end

    def validate_top_level_keys!(dsl)
      unknown = dsl.keys - ALLOWED_TOP_LEVEL_KEYS
      raise InvalidDSL, "Unknown DSL keys: #{unknown.join(', ')}" if unknown.any?
    end

    def validate_filters!(filters)
      raise InvalidDSL, "filters must be an array" unless filters.is_a?(Array)

      filters.map do |filter|
        raise InvalidDSL, "each filter must be an object" unless filter.is_a?(Hash)

        keys = filter.keys
        unknown = keys - %w[field operator value]
        raise InvalidDSL, "Unknown filter keys: #{unknown.join(', ')}" if unknown.any?

        field = filter["field"].to_s
        operator = filter["operator"].to_s
        value = filter["value"]

        validate_field!(field)
        validate_operator!(operator)
        validate_operator_value!(operator, value)

        { "field" => field, "operator" => operator, "value" => value }
      end
    end

    def validate_limit!(limit)
      raise InvalidDSL, "limit must be an integer" unless limit.is_a?(Integer)

      SafetyGuard.enforce_limit!(limit: limit, max_limit: @max_limit)
      limit
    end

    def validate_sort!(sort)
      return nil if sort.nil?
      raise InvalidDSL, "sort must be an object" unless sort.is_a?(Hash)

      unknown = sort.keys - %w[field direction]
      raise InvalidDSL, "Unknown sort keys: #{unknown.join(', ')}" if unknown.any?

      field = sort.fetch("field").to_s
      direction = sort.fetch("direction").to_s.downcase

      validate_field!(field)
      unless ALLOWED_SORT_DIRECTIONS.include?(direction)
        raise InvalidDSL, "sort direction must be asc or desc"
      end

      { "field" => field, "direction" => direction }
    end

    def validate_joins!(joins)
      raise InvalidDSL, "joins must be an array" unless joins.is_a?(Array)

      joins.map do |association|
        name = association.to_s
        unless @associations.include?(name)
          raise InvalidDSL, "Unknown association join: #{name}"
        end

        name
      end
    end

    def validate_field!(field)
      return if @columns.include?(field)
      return if valid_association_field?(field)

      raise InvalidDSL, "Unknown field: #{field}"
    end

    def valid_association_field?(field)
      association_name, column_name = field.split(".", 2)
      return false if association_name.to_s.empty? || column_name.to_s.empty?

      return false unless @associations.include?(association_name)

      association_columns = @association_columns.fetch(association_name, {}).fetch(:columns, nil) ||
                            @association_columns.fetch(association_name, {}).fetch("columns", nil)
      return false unless association_columns

      association_columns.keys.map(&:to_s).include?(column_name)
    end

    def validate_operator!(operator)
      return if ALLOWED_OPERATORS.include?(operator)

      raise InvalidDSL, "Unknown operator: #{operator}"
    end

    def validate_operator_value!(operator, value)
      case operator
      when "between"
        unless value.is_a?(Array) && value.length == 2
          raise InvalidDSL, "between operator requires exactly two values"
        end
      when "in"
        raise InvalidDSL, "in operator requires an array" unless value.is_a?(Array)
      when "like"
        raise InvalidDSL, "like operator requires a scalar value" if value.is_a?(Array) || value.is_a?(Hash)
      end
    end
  end
end
