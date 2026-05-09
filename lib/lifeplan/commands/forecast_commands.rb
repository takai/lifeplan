# frozen_string_literal: true

require "csv"
require "lifeplan/commands/helpers"
require "lifeplan/forecast/engine"

module Lifeplan
  module Commands
    module ForecastCommands
      include Helpers

      FORECAST_COLUMNS = [
        "year",
        "income",
        "expense",
        "event_income",
        "event_expense",
        "net_cashflow",
        "asset_balance",
        "liability_balance",
        "net_worth",
      ].freeze

      def forecast_payload(opts)
        project = load_project
        result = build_forecast(project, opts)

        rows = result.years.map(&:to_h)
        data = {
          "scenario_id" => result.scenario_id,
          "from" => result.from,
          "to" => result.to,
          "years" => rows,
          "summary" => result.summary.to_h,
        }
        payload(
          data: data,
          text: forecast_text(result),
          markdown: forecast_markdown(result),
          csv: forecast_csv(rows),
        )
      end

      def explain_payload(target, args, opts)
        project = load_project
        result = build_forecast(project, opts)

        case target.to_s
        when "year" then explain_year(project, result, args.first&.to_i)
        when "metric" then explain_metric(result, args.first, opts)
        when "scenario-diff", "scenario_diff"
          explain_scenario_diff_stub
        else
          raise InvalidArguments, "Unknown explain target: #{target}"
        end
      end

      private

      def build_forecast(project, opts)
        Lifeplan::Forecast::Engine.new(
          project,
          scenario_id: opts[:scenario] || "base",
          from: opts[:from]&.to_i,
          to: opts[:to]&.to_i,
        ).call
      end

      def forecast_text(result)
        header = format_row(FORECAST_COLUMNS)
        lines = [header, "-" * header.length]
        result.years.each do |row|
          lines << format_row(FORECAST_COLUMNS.map { |c| row[c.to_sym] })
        end
        lines << ""
        lines << "Summary:"
        result.summary.to_h.each { |k, v| lines << "  #{k}: #{v.inspect}" }
        lines.join("\n")
      end

      def forecast_csv(rows)
        CSV.generate do |csv|
          csv << FORECAST_COLUMNS
          rows.each { |row| csv << FORECAST_COLUMNS.map { |c| row[c] } }
        end
      end

      def forecast_markdown(result)
        lines = ["| " + FORECAST_COLUMNS.join(" | ") + " |"]
        lines << "|" + (["---"] * FORECAST_COLUMNS.size).join("|") + "|"
        result.years.each do |row|
          lines << "| " + FORECAST_COLUMNS.map { |c| row[c.to_sym].to_s }.join(" | ") + " |"
        end
        lines.join("\n")
      end

      def format_row(values)
        values.map { |v| v.to_s.rjust(14) }.join(" ")
      end

      def explain_year(project, result, year)
        raise InvalidArguments, "year argument required" unless year

        row = result.years.find { |r| r.year == year }
        raise InvalidArguments, "year #{year} not in forecast range" unless row

        contributors = year_contributors(project, year)
        data = {
          "target_type" => "year",
          "target" => year,
          "scenario_id" => result.scenario_id,
          "year" => year,
          "summary" => "Year #{year}: income #{row.income}, expense #{row.expense}, " \
            "net cashflow #{row.net_cashflow}, assets #{row.asset_balance}.",
          "contributors" => contributors,
          "row" => row.to_h,
        }
        text = data["summary"] + "\nContributors:\n" + contributors.map { |c|
          "  - #{c["record_type"]} #{c["record_id"]}: #{c["amount"]}"
        }.join("\n")
        payload(data: data, text: text)
      end

      def explain_metric(result, metric, opts)
        raise InvalidArguments, "metric argument required" unless metric

        summary = result.summary.to_h
        unless summary.key?(metric)
          raise InvalidArguments,
            "unknown metric '#{metric}'. Known: #{summary.keys.join(", ")}"
        end

        year = opts[:year]&.to_i
        row = year ? result.years.find { |r| r.year == year } : nil

        data = {
          "target_type" => "metric",
          "target" => metric,
          "scenario_id" => result.scenario_id,
          "year" => year,
          "value" => summary[metric],
          "summary" => "#{metric} = #{summary[metric].inspect}",
          "row" => row&.to_h,
        }
        payload(data: data, text: data["summary"])
      end

      def explain_scenario_diff_stub
        data = {
          "target_type" => "scenario_diff",
          "summary" => "scenario-diff explanation requires Phase 5 scenario resolver.",
          "available" => false,
        }
        payload(data: data, text: data["summary"])
      end

      def year_contributors(project, year)
        contributors = []
        project.incomes.each do |r|
          amount = Lifeplan::Forecast::YearBuilder.income_for(r, year, project.assumptions)
          next if amount.zero?

          contributors << contributor("income", r, amount)
        end
        project.expenses.each do |r|
          amount = Lifeplan::Forecast::YearBuilder.expense_for(r, year, project.assumptions)
          next if amount.zero?

          contributors << contributor("expense", r, -amount)
        end
        project.events.each do |r|
          amount = Lifeplan::Forecast::YearBuilder.event_amount(r, year)
          next if amount.zero?

          signed = r.impact_type == "expense" ? -amount : amount
          contributors << contributor("event", r, signed)
        end
        contributors
      end

      def contributor(type, record, amount)
        {
          "record_type" => type,
          "record_id" => record.id,
          "name" => record.name,
          "amount" => amount,
        }
      end
    end
  end
end
