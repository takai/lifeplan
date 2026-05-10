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

    def mortgage(principal:, rate:, payment:, frequency: "monthly", from: nil, to: nil, rate_changes: nil)
      steps_per_year = period_steps(frequency)
      start_year, start_period = parse_period(from, default: [1, 1])
      end_year, end_period = parse_period(to, default: nil)
      changes = normalize_rate_changes(rate_changes)

      balance = principal.to_f
      current_rate = rate.to_f
      total_interest = 0.0
      total_principal = 0.0
      yearly = {}
      months = []

      year = start_year
      period = start_period
      loop do
        break if balance <= 0
        break if end_year && (year > end_year || (year == end_year && period > end_period))

        current_rate = changes[year] if period == 1 && changes.key?(year)
        period_rate = current_rate / steps_per_year
        interest = balance * period_rate

        pay = payment.to_f
        if balance + interest <= pay
          pay = balance + interest
          principal_pmt = balance
          balance = 0.0
        else
          principal_pmt = pay - interest
          balance -= principal_pmt
        end

        months << {
          "year" => year,
          "period" => period,
          "interest" => interest,
          "principal" => principal_pmt,
          "payment" => pay,
          "balance" => balance,
        }
        bucket = (yearly[year] ||= { interest: 0.0, principal: 0.0, payment: 0.0, rate: current_rate })
        bucket[:interest] += interest
        bucket[:principal] += principal_pmt
        bucket[:payment] += pay
        bucket[:rate] = current_rate
        total_interest += interest
        total_principal += principal_pmt

        period += 1
        if period > steps_per_year
          period = 1
          year += 1
        end
      end

      final = months.last
      yearly_table = yearly.map do |y, h|
        {
          "year" => y,
          "interest" => h[:interest].round,
          "principal" => h[:principal].round,
          "payment" => h[:payment].round,
          "rate" => h[:rate],
        }
      end

      {
        principal: principal.to_f.round,
        total_interest: total_interest.round,
        total_principal: total_principal.round,
        total_payment: (total_interest + total_principal).round,
        final_year: final && final["year"],
        final_period: final && final["period"],
        periods: months.length,
        yearly: yearly_table,
        months: months,
      }
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

    def period_steps(frequency)
      case frequency.to_s
      when "monthly" then 12
      when "yearly", "" then 1
      else raise Lifeplan::InvalidArguments, "unsupported frequency '#{frequency}'"
      end
    end

    def parse_period(value, default:)
      return default if value.nil? || value == ""
      return [value.to_i, 1] if value.is_a?(Integer) || value.to_s.match?(/\A\d+\z/)

      str = value.to_s
      if (m = str.match(/\A(\d{4})-(\d{1,2})\z/))
        [m[1].to_i, m[2].to_i]
      else
        raise Lifeplan::InvalidArguments, "Invalid year/month value: #{value.inspect}"
      end
    end

    def normalize_rate_changes(raw)
      return {} if raw.nil? || raw == ""

      hash =
        case raw
        when Hash then raw
        when String
          raw.split(",").to_h do |pair|
            year, rate = pair.split(":", 2)
            raise Lifeplan::InvalidArguments, "Invalid rate change: #{pair.inspect}" if rate.nil?

            [year, rate]
          end
        else
          raise Lifeplan::InvalidArguments, "Unsupported rate_changes: #{raw.inspect}"
        end
      hash.to_h { |k, v| [k.to_i, v.to_f] }
    end
  end
end
