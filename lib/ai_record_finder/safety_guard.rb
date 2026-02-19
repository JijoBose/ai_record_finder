# frozen_string_literal: true

module AIRecordFinder
  # Centralized policy checks that enforce fail-closed query safety.
  class SafetyGuard
    class << self
      def validate_model!(model:, configuration:)
        unless defined?(ActiveRecord::Base) && model.is_a?(Class) && model < ActiveRecord::Base
          raise InvalidModelError, "Model must inherit from ActiveRecord::Base"
        end

        allowed_models = Array(configuration.allowed_models)
        return if allowed_models.include?(model)

        raise UnauthorizedModel, "Model #{model.name} is not in allowed_models"
      end

      def validate_joins!(model:, joins:, configuration:)
        joins = Array(joins)
        return if joins.empty?

        allowed = Array(configuration.allowed_associations[model.name] || configuration.allowed_associations[model])
        reflection_names = model.reflect_on_all_associations.map { |association| association.name.to_s }

        joins.each do |join_name|
          join_name = join_name.to_s
          unless reflection_names.include?(join_name)
            raise InvalidDSL, "Unknown association join: #{join_name}"
          end

          unless allowed.include?(join_name)
            raise InvalidDSL, "Join not allowed by policy: #{join_name}"
          end
        end
      end

      def apply_tenant_scope(model:, relation:)
        return relation unless model.respond_to?(:current_tenant_scope)

        scope = model.current_tenant_scope
        return relation unless scope
        raise InvalidDSL, "current_tenant_scope must return an ActiveRecord::Relation" unless scope.is_a?(ActiveRecord::Relation)

        relation.merge(scope)
      end

      def enforce_limit!(limit:, max_limit:)
        return if limit.is_a?(Integer) && limit.positive? && limit <= max_limit

        raise InvalidDSL, "limit must be between 1 and #{max_limit}"
      end
    end
  end
end
