# frozen_string_literal: true

require "lifeplan/forecast/growth"
require "lifeplan/forecast/liability"
require "lifeplan/forecast/year_builder"
require "lifeplan/forecast/result"
require "lifeplan/forecast/summary_builder"

module Lifeplan
  module Forecast
    class Engine
      def initialize(
        project, scenario_id: "base", from: nil, to: nil,
        include_details: false, include_per_person: false
      )
        @project = project
        @scenario_id = scenario_id
        @from = from || project.start_year
        @to = to || project.end_year
        @include_details = include_details
        @include_per_person = include_per_person
      end

      def call
        liabilities = @project.liabilities.map { |l| Liability.new(l, @from, @to) }
        asset_balances = @project.assets.to_h { |a| [a.id, a.amount.to_f] }
        cash_id = cash_asset_id
        liquid_ids = liquid_asset_ids
        cash_pool = 0.0
        warnings = []
        rows = []

        (@from..@to).each do |year|
          asset_balances = grow_assets(asset_balances) unless year == @from

          income = sum_records(active_incomes, year, :income_for)
          expense = sum_records(@project.expenses, year, :expense_for)
          event_income, event_expense, asset_changes, asset_disposals = event_totals(year, cash_id)

          liability_outflow = liabilities.sum { |l| l.yearly_outflow(year) }
          net_cashflow = income + event_income - expense - event_expense - liability_outflow

          contributions = apply_contributions(asset_balances, year)
          contributions.concat(apply_contribution_records(asset_balances, year))
          apply_asset_changes(asset_balances, asset_changes)
          apply_asset_disposals(asset_balances, asset_disposals)

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
          liquid_balance = liquid_ids.sum { |id| asset_balances[id].to_f }.round + cash_pool.round
          rows << YearRow.new(
            year: year,
            ages: ages_for(year),
            income: income,
            expense: expense,
            event_income: event_income,
            event_expense: event_expense,
            net_cashflow: net_cashflow,
            asset_balance: asset_balance,
            liquid_balance: liquid_balance,
            liability_balance: liability_balance,
            net_worth: asset_balance - liability_balance,
            per_person: build_per_person(year, asset_balances, cash_pool, liability_balance),
            details: build_details(
              asset_balances: asset_balances,
              contributions: contributions,
              asset_changes: asset_changes,
              asset_disposals: asset_disposals,
              withdrawals: withdrawals,
              liabilities: liabilities,
            ),
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

      def event_totals(year, cash_id)
        income = 0
        expense = 0
        asset_changes = []
        asset_disposals = []
        @project.events.each do |e|
          case e.impact_type
          when "income", "expense", "asset_change"
            amount = YearBuilder.event_amount(e, year)
            next if amount.zero?

            case e.impact_type
            when "income" then income += amount
            when "expense" then expense += amount
            when "asset_change"
              if e.target_asset_id
                asset_changes << { "asset_id" => e.target_asset_id, "amount" => amount }
              end
            end
          when "asset_disposal"
            next unless e.target_asset_id && disposal_active?(e, year)

            asset_disposals << {
              "event_id" => e.id,
              "asset_id" => e.target_asset_id,
              "proceeds_to" => e.proceeds_to_asset || cash_id,
              "proceeds" => e.proceeds || 0,
              "costs" => e.costs || {},
            }
          end
        end
        [income, expense, asset_changes, asset_disposals]
      end

      def disposal_active?(event, year)
        if event.year
          event.year == year
        elsif event.from || event.to
          from = event.from || year
          to = event.to || year
          year.between?(from, to)
        else
          false
        end
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

      def apply_contribution_records(asset_balances, year)
        records = []
        @project.contributions.each do |c|
          amount = contribution_amount(c, year, asset_balances)
          next if amount.zero?

          asset_balances[c.from_asset] = (asset_balances[c.from_asset] || 0.0) - amount
          asset_balances[c.to_asset] = (asset_balances[c.to_asset] || 0.0) + amount
          records << {
            "record_id" => c.id,
            "from_asset" => c.from_asset,
            "to_asset" => c.to_asset,
            "amount" => amount,
            "tax_treatment" => c.tax_treatment,
          }
        end
        records
      end

      def contribution_amount(contribution, year, asset_balances)
        return 0 unless contribution_active?(contribution, year)

        raw = contribution.amount
        if raw == "all"
          balance = asset_balances[contribution.from_asset].to_f
          return balance.positive? ? balance : 0
        end

        amount = raw.to_i
        return 0 if amount.zero?

        case contribution.frequency
        when "monthly" then amount * 12
        else amount
        end
      end

      def contribution_active?(contribution, year)
        if contribution.year
          contribution.year == year
        else
          from = contribution.from || year
          to = contribution.to || year
          year.between?(from, to)
        end
      end

      def apply_asset_changes(asset_balances, asset_changes)
        asset_changes.each do |change|
          id = change["asset_id"]
          asset_balances[id] = (asset_balances[id] || 0.0) + change["amount"]
        end
      end

      def apply_asset_disposals(asset_balances, asset_disposals)
        asset_disposals.each do |disposal|
          asset_id = disposal["asset_id"]
          book_value = (asset_balances[asset_id] || 0.0).round
          asset_balances[asset_id] = 0.0
          proceeds = disposal["proceeds"].to_i
          dest = disposal["proceeds_to"]
          asset_balances[dest] = (asset_balances[dest] || 0.0) + proceeds if dest && proceeds.positive?
          disposal["book_value"] = book_value
          disposal["book_value_loss"] = book_value - proceeds
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

      def liquid_asset_ids
        @project.assets.select { |a| a.category == "cash" || a.liquid }.map(&:id)
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

      def build_per_person(year, asset_balances, cash_pool, liability_balance)
        return unless @include_per_person

        buckets = base_per_person_buckets
        accumulate_income_per_person(buckets, year)
        accumulate_expense_per_person(buckets, year)
        accumulate_event_per_person(buckets, year)
        accumulate_asset_per_person(buckets, asset_balances, cash_pool)
        buckets["_shared"]["liability_balance"] += liability_balance
        buckets.each_value { |b| b["net_worth"] = b["asset_balance"] - b["liability_balance"] }
        prune_per_person(buckets)
      end

      def base_per_person_buckets
        buckets = {}
        (@project.profile&.people || []).each do |p|
          buckets[p.id] = empty_per_person_bucket
        end
        buckets["_shared"] = empty_per_person_bucket
        buckets
      end

      def empty_per_person_bucket
        { "income" => 0, "expense" => 0, "asset_balance" => 0, "liability_balance" => 0, "net_worth" => 0 }
      end

      def accumulate_income_per_person(buckets, year)
        active_incomes.each do |r|
          amount = YearBuilder.income_for(r, year, @project.assumptions)
          next if amount.zero?

          bucket_for(buckets, r.person_id)["income"] += amount
        end
      end

      def accumulate_expense_per_person(buckets, year)
        @project.expenses.each do |r|
          amount = YearBuilder.expense_for(r, year, @project.assumptions)
          next if amount.zero?

          bucket_for(buckets, r.person_id)["expense"] += amount
        end
      end

      def accumulate_event_per_person(buckets, year)
        @project.events.each do |e|
          next unless ["income", "expense"].include?(e.impact_type)

          amount = YearBuilder.event_amount(e, year)
          next if amount.zero?

          key = e.impact_type == "income" ? "income" : "expense"
          bucket_for(buckets, e.person_id)[key] += amount
        end
      end

      def accumulate_asset_per_person(buckets, asset_balances, cash_pool)
        @project.assets.each do |a|
          bucket_for(buckets, a.person_id)["asset_balance"] += asset_balances[a.id].to_f.round
        end
        buckets["_shared"]["asset_balance"] += cash_pool.round
      end

      def bucket_for(buckets, person_id)
        key = person_id && buckets.key?(person_id) ? person_id : "_shared"
        buckets[key]
      end

      def prune_per_person(buckets)
        buckets.reject do |key, bucket|
          key == "_shared" && bucket.values.all?(&:zero?)
        end
      end

      def build_details(asset_balances:, contributions:, asset_changes:, asset_disposals:, withdrawals:, liabilities:)
        return unless @include_details

        {
          "assets" => asset_balances.transform_values(&:round),
          "contributions" => contributions,
          "asset_changes" => asset_changes,
          "asset_disposals" => asset_disposals,
          "withdrawals" => withdrawals,
          "liabilities" => liabilities.to_h { |l| [l.record.id, l.balance] },
        }
      end
    end
  end
end
