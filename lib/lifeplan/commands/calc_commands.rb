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
