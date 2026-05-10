# frozen_string_literal: true

require "lifeplan/forecast/growth"

module Lifeplan
  module Forecast
    module YearBuilder
      extend self

      def income_for(record, year, assumptions)
        return 0 unless active?(record, year)

        rate = Growth.resolve(record.growth, assumptions)
        base_year = record.from || record.year || year
        amount = base_amount(record) * Growth.factor(rate, year - base_year)
        amount.round
      end

      def expense_for(record, year, assumptions)
        return 0 unless active?(record, year)

        stage = active_stage(record, year)
        rate = Growth.resolve(stage[:growth], assumptions)
        amount = stage[:amount] * Growth.factor(rate, year - stage[:base_year])
        amount.round
      end

      def active_stage(record, year)
        base = { base_year: record.from || record.year || year, amount: base_amount(record), growth: record.growth }
        transitions = record.respond_to?(:transitions) ? record.transitions : nil
        return base unless transitions.is_a?(Array) && !transitions.empty?

        applicable = transitions
          .map { |t| normalize_transition(t) }
          .select { |t| t[:year] && t[:year] <= year }
          .max_by { |t| t[:year] }
        return base unless applicable

        {
          base_year: applicable[:year],
          amount: transition_amount(applicable, record),
          growth: applicable[:growth] || record.growth,
        }
      end

      def normalize_transition(transition)
        return transition if transition.keys.first.is_a?(Symbol)

        transition.transform_keys(&:to_sym)
      end

      def transition_amount(transition, record)
        amount = transition[:amount] || 0
        case record.frequency
        when "monthly" then amount * 12
        else amount
        end
      end

      def event_amount(event, year)
        return 0 unless event.amount

        if event.year
          return 0 unless event.year == year
        elsif event.from || event.to
          from = event.from || year
          to = event.to || year
          return 0 unless year.between?(from, to)
        else
          return 0
        end

        event.amount
      end

      def active?(record, year)
        if record.respond_to?(:year) && record.year
          return record.year == year
        end

        from = record.respond_to?(:from) ? record.from : nil
        to = record.respond_to?(:to) ? record.to : nil
        (from.nil? || from <= year) && (to.nil? || to >= year)
      end

      def base_amount(record)
        amount = record.amount || 0
        case record.frequency
        when "monthly" then amount * 12
        else amount
        end
      end
    end
  end
end
