# frozen_string_literal: true

require "csv"
require "thor"
require "lifeplan/calc"
require "lifeplan/commands/helpers"

module Lifeplan
  module Commands
    class CalcCLI < Thor
      include Helpers

      class << self
        def exit_on_failure?
          true
        end
      end

      desc "future-value", "Calculate future value"
      method_option :principal, type: :numeric, required: true
      method_option :rate, type: :numeric, required: true
      method_option :years, type: :numeric, required: true
      def future_value
        result = Lifeplan::Calc.future_value(
          principal: options[:principal], rate: options[:rate], years: options[:years],
        )
        emit_scalar("future_value", result)
      end
      map "fv" => :future_value

      desc "present-value", "Calculate present value"
      method_option :future, type: :numeric, required: true
      method_option :rate, type: :numeric, required: true
      method_option :years, type: :numeric, required: true
      def present_value
        result = Lifeplan::Calc.present_value(
          future: options[:future], rate: options[:rate], years: options[:years],
        )
        emit_scalar("present_value", result)
      end
      map "pv" => :present_value

      desc "savings", "Calculate recurring savings projection"
      method_option :payment, type: :numeric, required: true
      method_option :rate, type: :numeric, required: true
      method_option :years, type: :numeric, required: true
      method_option :initial, type: :numeric, default: 0
      method_option :frequency, type: :string, default: "yearly"
      def savings
        result = Lifeplan::Calc.savings(
          payment: options[:payment],
          rate: options[:rate],
          years: options[:years],
          initial: options[:initial],
          frequency: options[:frequency],
        )
        emit_scalar("savings", result)
      end

      desc "required-savings", "Calculate required recurring savings amount"
      method_option :target, type: :numeric, required: true
      method_option :rate, type: :numeric, required: true
      method_option :years, type: :numeric, required: true
      method_option :initial, type: :numeric, default: 0
      method_option :frequency, type: :string, default: "yearly"
      def required_savings
        result = Lifeplan::Calc.required_savings(
          target: options[:target],
          rate: options[:rate],
          years: options[:years],
          initial: options[:initial],
          frequency: options[:frequency],
        )
        emit_scalar("required_savings", result)
      end

      desc "withdrawal", "Estimate sustainable withdrawal amount"
      method_option :principal, type: :numeric, required: true
      method_option :rate, type: :numeric, required: true
      method_option :years, type: :numeric, required: true
      method_option :frequency, type: :string, default: "yearly"
      def withdrawal
        result = Lifeplan::Calc.withdrawal(
          principal: options[:principal],
          rate: options[:rate],
          years: options[:years],
          frequency: options[:frequency],
        )
        emit_scalar("withdrawal", result)
      end

      desc "loan", "Calculate loan repayment"
      method_option :principal, type: :numeric, required: true
      method_option :rate, type: :numeric, required: true
      method_option :years, type: :numeric, required: true
      method_option :frequency, type: :string, default: "monthly"
      method_option :"bonus-payment", type: :numeric, default: 0
      def loan
        result = Lifeplan::Calc.loan(
          principal: options[:principal],
          rate: options[:rate],
          years: options[:years],
          frequency: options[:frequency],
          bonus_payment: options[:"bonus-payment"],
        )
        data = result.transform_keys(&:to_s)
        text = format(
          "periodic_payment: %.2f\nperiods: %d\ntotal_payment: %.2f\ntotal_interest: %.2f",
          data["periodic_payment"],
          data["periods"],
          data["total_payment"],
          data["total_interest"],
        )
        csv_str = CSV.generate do |csv|
          csv << ["metric", "value"]
          data.each { |k, v| csv << [k, v] }
        end
        markdown = "| metric | value |\n| --- | --- |\n" +
          data.map { |k, v| "| #{k} | #{v} |" }.join("\n")
        render(payload(data: data, text: text, csv: csv_str, markdown: markdown))
      end

      desc "mortgage", "Amortize a mortgage month-by-month with optional rate changes"
      method_option :principal, type: :numeric, required: true
      method_option :rate, type: :numeric, required: true
      method_option :payment, type: :numeric, required: true
      method_option :frequency, type: :string, default: "monthly"
      method_option :from, type: :string
      method_option :to, type: :string
      method_option :"rate-changes", type: :string
      def mortgage
        result = Lifeplan::Calc.mortgage(
          principal: options[:principal],
          rate: options[:rate],
          payment: options[:payment],
          frequency: options[:frequency],
          from: options[:from],
          to: options[:to],
          rate_changes: options[:"rate-changes"],
        )
        summary = {
          "principal" => result[:principal],
          "total_interest" => result[:total_interest],
          "total_principal" => result[:total_principal],
          "total_payment" => result[:total_payment],
          "final_year" => result[:final_year],
          "final_period" => result[:final_period],
          "periods" => result[:periods],
        }
        text_lines = summary.map { |k, v| "#{k}: #{v}" }
        text_lines << ""
        text_lines << format("%-6s %12s %12s %12s", "year", "interest", "principal", "payment")
        result[:yearly].each do |row|
          text_lines << format(
            "%-6d %12d %12d %12d", row["year"], row["interest"], row["principal"], row["payment"]
          )
        end
        csv_str = CSV.generate do |csv|
          csv << ["year", "interest", "principal", "payment", "rate"]
          result[:yearly].each { |row| csv << [row["year"], row["interest"], row["principal"], row["payment"], row["rate"]] }
        end
        markdown = "| year | interest | principal | payment |\n| ---: | ---: | ---: | ---: |\n" +
          result[:yearly].map { |r| "| #{r["year"]} | #{r["interest"]} | #{r["principal"]} | #{r["payment"]} |" }.join("\n")
        data = summary.merge("yearly" => result[:yearly])
        render(payload(data: data, text: text_lines.join("\n"), csv: csv_str, markdown: markdown))
      end

      desc "inflation", "Calculate inflation-adjusted value"
      method_option :amount, type: :numeric, required: true
      method_option :rate, type: :numeric, required: true
      method_option :years, type: :numeric, required: true
      def inflation
        result = Lifeplan::Calc.inflation(
          amount: options[:amount], rate: options[:rate], years: options[:years],
        )
        emit_scalar("inflation_adjusted", result)
      end

      desc "grow", "Generate a growth table"
      method_option :amount, type: :numeric, required: true
      method_option :rate, type: :numeric, required: true
      method_option :years, type: :numeric, required: true
      def grow
        rows = Lifeplan::Calc.grow(
          amount: options[:amount], rate: options[:rate], years: options[:years],
        )
        text = rows.map { |r| format("%4d  %.2f", r["year"], r["value"]) }.join("\n")
        csv_str = CSV.generate do |csv|
          csv << ["year", "value"]
          rows.each { |r| csv << [r["year"], r["value"]] }
        end
        markdown = "| year | value |\n| --- | --- |\n" +
          rows.map { |r| "| #{r["year"]} | #{r["value"]} |" }.join("\n")
        render(payload(data: rows, text: text, csv: csv_str, markdown: markdown))
      end

      private

      def emit_scalar(label, value)
        render(payload(
          data: { label => value },
          text: format("%s: %.2f", label, value),
        ))
      end
    end
  end
end
