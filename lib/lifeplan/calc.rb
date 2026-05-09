# frozen_string_literal: true

require "lifeplan/errors"

module Lifeplan
  module Calc
    extend self

    def future_value(principal:, rate:, years:)
      principal * ((1 + rate.to_f)**years)
    end

    def present_value(future:, rate:, years:)
      future / ((1 + rate.to_f)**years)
    end

    def savings(payment:, rate:, years:, initial: 0, frequency: "yearly")
      r, n = periodize(rate, years, frequency)
      growth = (1 + r)**n
      annuity = r.zero? ? payment * n : payment * (growth - 1) / r
      initial * growth + annuity
    end

    def required_savings(target:, rate:, years:, initial: 0, frequency: "yearly")
      r, n = periodize(rate, years, frequency)
      growth = (1 + r)**n
      remainder = target - initial * growth
      r.zero? ? remainder.to_f / n : remainder * r / (growth - 1)
    end

    def withdrawal(principal:, rate:, years:, frequency: "yearly")
      r, n = periodize(rate, years, frequency)
      r.zero? ? principal.to_f / n : principal * r / (1 - ((1 + r)**(-n)))
    end

    def loan(principal:, rate:, years:, frequency: "monthly", bonus_payment: 0)
      r, n = periodize(rate, years, frequency)
      base = r.zero? ? principal.to_f / n : principal * r / (1 - ((1 + r)**(-n)))
      total = base * n
      {
        periodic_payment: base,
        periods: n,
        total_payment: total,
        total_interest: total - principal,
        bonus_payment: bonus_payment,
      }
    end

    def inflation(amount:, rate:, years:)
      amount / ((1 + rate.to_f)**years)
    end

    def grow(amount:, rate:, years:)
      (0..years).map { |i| { "year" => i, "value" => amount * ((1 + rate.to_f)**i) } }
    end

    private

    def periodize(rate, years, frequency)
      case frequency.to_s
      when "monthly" then [rate.to_f / 12, years * 12]
      when "yearly", "" then [rate.to_f, years]
      else raise Lifeplan::InvalidArguments, "unsupported frequency '#{frequency}'"
      end
    end
  end
end
