# frozen_string_literal: true

module Lifeplan
  module Forecast
    Result = Data.define(:scenario_id, :from, :to, :years, :summary, :warnings) do
      def to_h
        {
          "scenario_id" => scenario_id,
          "from" => from,
          "to" => to,
          "years" => years.map(&:to_h),
          "summary" => summary.to_h,
          "warnings" => warnings,
        }
      end

      def find_year(year)
        years.find { |y| y[:year] == year }
      end
    end

    YearRow = Data.define(
      :year,
      :ages,
      :income,
      :expense,
      :event_income,
      :event_expense,
      :net_cashflow,
      :asset_balance,
      :liquid_balance,
      :liability_balance,
      :net_worth,
      :details,
    ) do
      def to_h
        {
          "year" => year,
          "ages" => ages,
          "income" => income,
          "expense" => expense,
          "event_income" => event_income,
          "event_expense" => event_expense,
          "net_cashflow" => net_cashflow,
          "asset_balance" => asset_balance,
          "liquid_balance" => liquid_balance,
          "liability_balance" => liability_balance,
          "net_worth" => net_worth,
          "details" => details,
        }
      end

      def [](key)
        public_send(key)
      end
    end

    Summary = Data.define(
      :minimum_asset_balance,
      :minimum_asset_balance_year,
      :first_negative_asset_year,
      :asset_at_retirement,
      :retirement_year,
      :total_income,
      :total_expense,
      :final_asset_balance,
    ) do
      def to_h
        {
          "minimum_asset_balance" => minimum_asset_balance,
          "minimum_asset_balance_year" => minimum_asset_balance_year,
          "first_negative_asset_year" => first_negative_asset_year,
          "asset_at_retirement" => asset_at_retirement,
          "retirement_year" => retirement_year,
          "total_income" => total_income,
          "total_expense" => total_expense,
          "final_asset_balance" => final_asset_balance,
        }
      end
    end
  end
end
