# frozen_string_literal: true

require "csv"
require "lifeplan/commands/helpers"
require "lifeplan/commands/forecast_commands"
require "lifeplan/commands/compare_commands"
require "lifeplan/commands/validation_commands"
require "lifeplan/scenarios/resolver"

module Lifeplan
  module Commands
    module ExportCommands
      include Helpers
      include ForecastCommands
      include CompareCommands
      include ValidationCommands

      VALID_TARGETS = ["data", "forecast", "scenario", "comparison", "validation"].freeze

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
        forecast_payload(opts)
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
        base = args[0] || "base"
        target = args[1] || opts[:scenario] ||
          raise(Lifeplan::InvalidArguments, "comparison requires <base> <target> args or --scenario")
        compare_payload(base, target, opts)
      end

      def export_validation_payload(_args, opts)
        validate_payload(opts)
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
