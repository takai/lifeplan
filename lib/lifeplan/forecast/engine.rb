# frozen_string_literal: true

require "lifeplan/forecast/growth"
require "lifeplan/forecast/liability"
require "lifeplan/forecast/year_builder"
require "lifeplan/forecast/result"
require "lifeplan/forecast/summary_builder"

module Lifeplan
  module Forecast
    class Engine
      def initialize(project, scenario_id: "base", from: nil, to: nil, include_details: false)
        @project = project
        @scenario_id = scenario_id
        @from = from || project.start_year
        @to = to || project.end_year
        @include_details = include_details
      end

      def call
        liabilities = @project.liabilities.map { |l| Liability.new(l, @from, @to) }
        asset_balances = @project.assets.to_h { |a| [a.id, a.amount.to_f] }
        cash_id = cash_asset_id
        cash_pool = 0.0
        warnings = []
        rows = []

        (@from..@to).each do |year|
          asset_balances = grow_assets(asset_balances) unless year == @from

          income = sum_records(active_incomes, year, :income_for)
          expense = sum_records(@project.expenses, year, :expense_for)
          event_income, event_expense, asset_changes = event_totals(year)

          liability_outflow = liabilities.sum { |l| l.yearly_outflow(year) }
          net_cashflow = income + event_income - expense - event_expense - liability_outflow

          contributions = apply_contributions(asset_balances, year)
          apply_asset_changes(asset_balances, asset_changes)

          if cash_id
            asset_balances[cash_id] += net_cashflow
          else
            cash_pool += net_cashflow
          end

          withdrawals, shortfall = settle_cash_deficit(asset_balances, cash_id, cash_pool)
          if shortfall.positive?
            warnings << {
              "year" => year,
              "code" => "WITHDRAWAL_SHORTFALL",
              "message" => "Cash deficit of #{shortfall.round} could not be covered by withdrawals",
            }
          end
          unless cash_id
            withdrawn_total = withdrawals.sum { |w| w["amount"] }
            cash_pool += withdrawn_total
          end

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
            details: build_details(asset_balances, contributions, asset_changes, withdrawals),
          )
        end

        summary = SummaryBuilder.call(rows, @project)
        Result.new(
          scenario_id: @scenario_id,
          from: @from,
          to: @to,
          years: rows,
          summary: summary,
          warnings: warnings,
        )
      end

      private

      def sum_records(records, year, method)
        records.sum { |r| YearBuilder.public_send(method, r, year, @project.assumptions) }
      end

      def active_incomes
        @project.incomes.reject(&:contribute_to)
      end

      def event_totals(year)
        income = 0
        expense = 0
        asset_changes = []
        @project.events.each do |e|
          amount = YearBuilder.event_amount(e, year)
          next if amount.zero?

          case e.impact_type
          when "income" then income += amount
          when "expense" then expense += amount
          when "asset_change"
            asset_changes << { "asset_id" => e.target_asset_id, "amount" => amount } if e.target_asset_id
          end
        end
        [income, expense, asset_changes]
      end

      def apply_contributions(asset_balances, year)
        contributions = []
        @project.expenses.each do |r|
          next unless r.contribute_to

          amount = YearBuilder.expense_for(r, year, @project.assumptions)
          next if amount.zero?

          asset_balances[r.contribute_to] = (asset_balances[r.contribute_to] || 0.0) + amount
          contributions << { "record_id" => r.id, "asset_id" => r.contribute_to, "amount" => amount }
        end
        @project.incomes.each do |r|
          next unless r.contribute_to

          amount = YearBuilder.income_for(r, year, @project.assumptions)
          next if amount.zero?

          asset_balances[r.contribute_to] = (asset_balances[r.contribute_to] || 0.0) + amount
          contributions << { "record_id" => r.id, "asset_id" => r.contribute_to, "amount" => amount }
        end
        contributions
      end

      def apply_asset_changes(asset_balances, asset_changes)
        asset_changes.each do |change|
          id = change["asset_id"]
          asset_balances[id] = (asset_balances[id] || 0.0) + change["amount"]
        end
      end

      def settle_cash_deficit(asset_balances, cash_id, cash_pool)
        deficit_source = cash_id ? asset_balances[cash_id].to_f : cash_pool
        return [[], 0.0] unless deficit_source.negative?

        withdrawals = []
        deficit = -deficit_source
        order = withdrawal_order(cash_id)
        order.each do |source_id|
          break if deficit <= 0

          source = asset_balances[source_id].to_f
          next if source <= 0

          take = [source, deficit].min
          asset_balances[source_id] -= take
          asset_balances[cash_id] += take if cash_id
          deficit -= take
          withdrawals << { "asset_id" => source_id, "amount" => take.round }
        end
        [withdrawals, deficit]
      end

      def withdrawal_order(cash_id)
        explicit = @project.assumptions.find { |a| a.id == "withdrawal_order" }
        if explicit && explicit.value.is_a?(Array)
          return explicit.value.map(&:to_s)
        end

        @project.assets.map(&:id).reject { |id| id == cash_id }
      end

      def cash_asset_id
        @project.assets.find { |a| a.category == "cash" }&.id
      end

      def grow_assets(balances)
        @project.assets.each_with_object({}) do |asset, h|
          rate = Growth.resolve(asset.return, @project.assumptions)
          h[asset.id] = (balances[asset.id] || 0.0) * (1.0 + rate)
        end.merge(balances.reject { |id, _| @project.assets.any? { |a| a.id == id } })
      end

      def ages_for(year)
        return {} unless @project.profile&.people

        @project.profile.people.each_with_object({}) do |person, h|
          base = person.birth_year
          next unless base

          h[person.id] = year - base
        end
      end

      def build_details(asset_balances, contributions, asset_changes, withdrawals)
        return unless @include_details

        {
          "assets" => asset_balances.transform_values(&:round),
          "contributions" => contributions,
          "asset_changes" => asset_changes,
          "withdrawals" => withdrawals,
        }
      end
    end
  end
end
