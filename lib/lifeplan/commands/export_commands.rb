# frozen_string_literal: true

require "csv"
require "lifeplan/commands/helpers"
require "lifeplan/commands/forecast_commands"
require "lifeplan/commands/compare_commands"
require "lifeplan/commands/validation_commands"
require "lifeplan/commands/report_commands"
require "lifeplan/forecast/year_builder"
require "lifeplan/scenarios/resolver"

module Lifeplan
  module Commands
    module ExportCommands
      include Helpers
      include ForecastCommands
      include CompareCommands
      include ValidationCommands
      include ReportCommands

      VALID_TARGETS = ["data", "forecast", "scenario", "comparison", "validation", "report"].freeze

      def export_payload(target, args, opts)
        unless VALID_TARGETS.include?(target.to_s)
          raise Lifeplan::InvalidArguments,
            "unknown export target '#{target}'. Valid: #{VALID_TARGETS.join(", ")}"
        end

        send("export_#{target}_payload", args, opts)
      end

      private

      def export_data_payload(_args, _opts)
        project = load_project
        data = project_data_dump(project)
        text = data.map { |k, v| "#{k}: #{v.is_a?(Array) ? "#{v.size} record(s)" : v.inspect}" }.join("\n")
        payload(data: data, text: text, csv: data_csv(project))
      end

      def export_forecast_payload(_args, opts)
        project = scenario_project(load_project, opts[:scenario])
        forecast = Lifeplan::Forecast::Engine.new(
          project,
          scenario_id: opts[:scenario] || "base",
          from: opts[:from]&.to_i,
          to: opts[:to]&.to_i,
          include_details: true,
        ).call

        rows = forecast.years.map(&:to_h)
        data = {
          "scenario_id" => forecast.scenario_id,
          "from" => forecast.from,
          "to" => forecast.to,
          "years" => rows,
          "summary" => forecast.summary.to_h,
        }
        payload(
          data: data,
          text: forecast_text(forecast),
          markdown: forecast_markdown(forecast),
          csv: forecast_wide_csv(project, forecast),
        )
      end

      def export_report_payload(_args, opts)
        report_payload(opts)
      end

      def export_scenario_payload(args, _opts)
        project = load_project
        id = args.first
        if id
          scenario = project.scenarios.find { |s| s.id == id } ||
            raise(Lifeplan::ScenarioNotFound, "scenario '#{id}' not found")
          payload(
            data: scenario.to_h.transform_keys(&:to_s),
            text: scenario.to_h.map { |k, v| "#{k}: #{v.inspect}" }.join("\n"),
          )
        else
          rows = project.scenarios.map { |s| s.to_h.transform_keys(&:to_s) }
          payload(
            data: { "scenarios" => rows },
            text: rows.empty? ? "(no scenarios)" : rows.map { |r| "#{r["id"]}\t#{r["name"]}" }.join("\n"),
          )
        end
      end

      def export_comparison_payload(args, opts)
        scenario_ids = args.dup
        scenario_ids << opts[:scenario] if scenario_ids.empty? && opts[:scenario]
        if scenario_ids.empty?
          raise Lifeplan::InvalidArguments, "comparison requires at least one scenario id"
        end

        compare_payload(scenario_ids, opts)
      end

      def export_validation_payload(_args, opts)
        validate_payload(opts)
      end

      WideForecastSchema = Struct.new(:people, :incomes, :expenses, :assets, :liabilities)

      def forecast_wide_csv(project, forecast)
        schema = WideForecastSchema.new(
          (project.profile&.people || []).map(&:id),
          project.incomes.map(&:id),
          project.expenses.map(&:id),
          project.assets.map(&:id),
          project.liabilities.map(&:id),
        )

        CSV.generate do |csv|
          csv << forecast_wide_headers(schema)
          forecast.years.each do |row|
            csv << forecast_wide_row(project, schema, row)
          end
        end
      end

      def forecast_wide_headers(schema)
        headers = ["year"]
        headers.concat(schema.people.map { |id| "age_#{id}" })
        headers << "income_total"
        headers.concat(schema.incomes.map { |id| "income_#{id}" })
        headers << "expense_total"
        headers.concat(schema.expenses.map { |id| "expense_#{id}" })
        headers.push("event_income", "event_expense", "net_cashflow")
        headers.concat(schema.assets.map { |id| "asset_#{id}" })
        headers.concat(schema.liabilities.map { |id| "liability_#{id}_balance" })
        headers.push("asset_balance", "liability_balance", "liquid_balance", "net_worth")
        headers
      end

      def forecast_wide_row(project, schema, row)
        year = row.year
        assumptions = project.assumptions
        per_income = project.incomes.to_h do |r|
          [r.id, Lifeplan::Forecast::YearBuilder.income_for(r, year, assumptions)]
        end
        per_expense = project.expenses.to_h do |r|
          [r.id, Lifeplan::Forecast::YearBuilder.expense_for(r, year, assumptions)]
        end
        assets = row.details&.dig("assets") || {}
        liabilities = row.details&.dig("liabilities") || {}

        cells = [year]
        cells.concat(schema.people.map { |id| row.ages[id] })
        cells << row.income
        cells.concat(schema.incomes.map { |id| per_income[id] })
        cells << row.expense
        cells.concat(schema.expenses.map { |id| per_expense[id] })
        cells.push(row.event_income, row.event_expense, row.net_cashflow)
        cells.concat(schema.assets.map { |id| assets[id] })
        cells.concat(schema.liabilities.map { |id| liabilities[id] })
        cells.push(row.asset_balance, row.liability_balance, row.liquid_balance, row.net_worth)
        cells
      end

      def project_data_dump(project)
        {
          "project" => {
            "id" => project.id,
            "name" => project.name,
            "currency" => project.currency,
            "start_year" => project.start_year,
            "end_year" => project.end_year,
          },
          "profile" => project.profile&.to_h&.transform_keys(&:to_s),
          "incomes" => project.incomes.map { |r| r.to_h.transform_keys(&:to_s) },
          "expenses" => project.expenses.map { |r| r.to_h.transform_keys(&:to_s) },
          "assets" => project.assets.map { |r| r.to_h.transform_keys(&:to_s) },
          "liabilities" => project.liabilities.map { |r| r.to_h.transform_keys(&:to_s) },
          "events" => project.events.map { |r| r.to_h.transform_keys(&:to_s) },
          "assumptions" => project.assumptions.map { |r| r.to_h.transform_keys(&:to_s) },
          "scenarios" => project.scenarios.map { |r| r.to_h.transform_keys(&:to_s) },
        }
      end

      def data_csv(project)
        CSV.generate do |csv|
          csv << ["type", "id", "name", "amount", "from", "to", "category"]
          Lifeplan::Project::COLLECTIONS.each_value do |type|
            next if type == "scenario" || type == "assumption"

            project.collection(type).each do |r|
              h = r.to_h
              csv << [type, h[:id], h[:name], h[:amount], h[:from], h[:to], h[:category]]
            end
          end
        end
      end
    end
  end
end
