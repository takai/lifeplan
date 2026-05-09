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
        income_for(record, year, assumptions)
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
