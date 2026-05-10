# frozen_string_literal: true

require "lifeplan/calc"

module Lifeplan
  module Forecast
    class Liability
      attr_reader :record, :start_year, :end_year, :rate, :yearly_payment

      def initialize(record, project_start, project_end)
        @record = record
        @rate = (record.rate || 0).to_f
        @start_year = record.from || project_start
        @end_year = compute_end_year(record, project_end)
        @schedule = build_amortization_schedule(record)
        @yearly_payment = compute_yearly_payment(record)
        @balance = (record.principal || 0).to_f
      end

      def balance
        @balance.round
      end

      def step!(year)
        return @balance.round if year < start_year || year > end_year

        if @schedule
          row = @schedule[year]
          @balance = row ? row[:balance_after] : 0.0
        else
          interest = @balance * rate
          @balance += interest
          @balance -= yearly_payment
          @balance = 0.0 if @balance.negative?
        end
        @balance.round
      end

      def yearly_outflow(year)
        return 0 if year < start_year || year > end_year || @balance.zero?

        if @schedule
          row = @schedule[year]
          row ? row[:payment].round : 0
        else
          yearly_payment.round
        end
      end

      private

      def compute_end_year(record, project_end)
        return record.to if record.to
        return @start_year + record.years - 1 if record.years

        project_end
      end

      def build_amortization_schedule(record)
        return unless record.payment && rate.positive? && record.frequency == "monthly"

        rate_changes = record.respond_to?(:rate_changes) ? record.rate_changes : nil
        from = "#{start_year}-01"
        result = Lifeplan::Calc.mortgage(
          principal: record.principal.to_f,
          rate: rate,
          payment: record.payment.to_f,
          frequency: "monthly",
          from: from,
          rate_changes: rate_changes,
        )
        schedule = {}
        running = record.principal.to_f
        result[:yearly].each do |row|
          running -= row["principal"]
          running = 0.0 if running.negative?
          schedule[row["year"]] = {
            payment: row["payment"],
            interest: row["interest"],
            principal: row["principal"],
            balance_after: running,
          }
        end
        schedule
      end

      def compute_yearly_payment(record)
        return record.payment * 12 if record.payment && record.frequency == "monthly"
        return record.payment.to_f if record.payment

        years = end_year - start_year + 1
        return 0.0 if years <= 0
        return record.principal.to_f / years if rate.zero?

        principal = record.principal.to_f
        principal * rate / (1.0 - (1.0 + rate)**(-years))
      end
    end
  end
end
