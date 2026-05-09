# frozen_string_literal: true

module Lifeplan
  module Forecast
    module Growth
      extend self

      def resolve(value, assumptions)
        return 0.0 if value.nil? || value == "none"
        return value.to_f if value.is_a?(Numeric)

        assumption = assumptions.find { |a| a.id == value.to_s }
        return 0.0 unless assumption

        Float(assumption.value)
      rescue ArgumentError, TypeError
        0.0
      end

      def factor(rate, years)
        (1.0 + rate)**years
      end
    end
  end
end
