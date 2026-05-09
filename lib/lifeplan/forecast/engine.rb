# frozen_string_literal: true

require "lifeplan/forecast/growth"
require "lifeplan/forecast/liability"
require "lifeplan/forecast/year_builder"
require "lifeplan/forecast/result"
require "lifeplan/forecast/summary_builder"

module Lifeplan
  module Forecast
    class Engine
      def initialize(project, scenario_id: "base", from: nil, to: nil)
        @project = project
        @scenario_id = scenario_id
        @from = from || project.start_year
        @to = to || project.end_year
      end

      def call
        liabilities = @project.liabilities.map { |l| Liability.new(l, @from, @to) }
        asset_balances = @project.assets.to_h { |a| [a.id, a.amount.to_f] }
        cash_pool = 0.0
        rows = []

        (@from..@to).each do |year|
          income = sum_records(@project.incomes, year, :income_for)
          expense = sum_records(@project.expenses, year, :expense_for)
          event_income, event_expense = event_totals(year)

          liability_outflow = liabilities.sum { |l| l.yearly_outflow(year) }
          net_cashflow = income + event_income - expense - event_expense - liability_outflow

          unless year == @from
            asset_balances = grow_assets(asset_balances)
          end
          cash_pool += net_cashflow

          liabilities.each { |l| l.step!(year) }
          liability_balance = liabilities.sum(&:balance)

          asset_balance = asset_balances.values.sum.round + cash_pool.round
          rows << YearRow.new(
            year: year,
            ages: ages_for(year),
            income: income,
            expense: expense,
            event_income: event_income,
            event_expense: event_expense,
            net_cashflow: net_cashflow,
            asset_balance: asset_balance,
            liability_balance: liability_balance,
            net_worth: asset_balance - liability_balance,
            details: nil,
          )
        end

        summary = SummaryBuilder.call(rows, @project)
        Result.new(
          scenario_id: @scenario_id,
          from: @from,
          to: @to,
          years: rows,
          summary: summary,
          warnings: [],
        )
      end

      private

      def sum_records(records, year, method)
        records.sum { |r| YearBuilder.public_send(method, r, year, @project.assumptions) }
      end

      def event_totals(year)
        income = 0
        expense = 0
        @project.events.each do |e|
          amount = YearBuilder.event_amount(e, year)
          next if amount.zero?

          case e.impact_type
          when "income" then income += amount
          when "expense" then expense += amount
          end
        end
        [income, expense]
      end

      def grow_assets(balances)
        @project.assets.each_with_object({}) do |asset, h|
          rate = Growth.resolve(asset.return, @project.assumptions)
          h[asset.id] = (balances[asset.id] || 0.0) * (1.0 + rate)
        end
      end

      def ages_for(year)
        return {} unless @project.profile&.people

        @project.profile.people.each_with_object({}) do |person, h|
          base = person.birth_year
          next unless base

          h[person.id] = year - base
        end
      end
    end
  end
end
