# frozen_string_literal: true

require "lifeplan/validation/issue"
require "lifeplan/validation/rules/structural"
require "lifeplan/validation/rules/period"
require "lifeplan/validation/rules/financial"
require "lifeplan/validation/rules/scenario"

module Lifeplan
  module Validation
    class Validator
      DEFAULT_RULES = [
        Rules::Structural,
        Rules::Period,
        Rules::Financial,
        Rules::Scenario,
      ].freeze

      def initialize(rules: DEFAULT_RULES)
        @rules = rules
      end

      def call(project)
        @rules.flat_map { |rule| rule.call(project) }
      end
    end
  end
end
