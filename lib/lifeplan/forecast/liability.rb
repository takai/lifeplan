# frozen_string_literal: true

module Lifeplan
  module Forecast
    class Liability
      attr_reader :record, :start_year, :end_year, :rate, :yearly_payment

      def initialize(record, project_start, project_end)
        @record = record
        @rate = (record.rate || 0).to_f
        @start_year = record.from || project_start
        @end_year = compute_end_year(record, project_end)
        @yearly_payment = compute_yearly_payment(record)
        @balance = (record.principal || 0).to_f
      end

      def balance
        @balance.round
      end

      def step!(year)
        return @balance.round if year < start_year || year > end_year

        interest = @balance * rate
        @balance += interest
        @balance -= yearly_payment
        @balance = 0.0 if @balance.negative?
        @balance.round
      end

      def yearly_outflow(year)
        return 0 if year < start_year || year > end_year || @balance.zero?

        yearly_payment.round
      end

      private

      def compute_end_year(record, project_end)
        return record.to if record.to
        return @start_year + record.years - 1 if record.years

        project_end
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
