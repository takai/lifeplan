# frozen_string_literal: true

require "lifeplan/commands/helpers"
require "lifeplan/errors"
require "lifeplan/scenarios/resolver"
require "lifeplan/forecast/engine"

module Lifeplan
  module Commands
    module CompareCommands
      include Helpers

      DEFAULT_METRICS = [
        "net_worth",
        "liquid",
        "depletion_year",
        "min_liquid_year",
        "final_asset_balance",
        "total_income",
        "total_expense",
      ].freeze

      KNOWN_METRICS = DEFAULT_METRICS

      AT_METRICS = ["net_worth", "liquid"].freeze

      def compare_payload(scenario_ids, opts)
        scenario_ids = Array(scenario_ids).reject { |id| id.nil? || id.empty? }
        raise Lifeplan::InvalidArguments, "compare requires at least one scenario" if scenario_ids.empty?

        project = load_project
        resolver = Lifeplan::Scenarios::Resolver.new(project)
        from = opts[:from]&.to_i
        to = opts[:to]&.to_i
        at = opts[:at]&.to_i

        results = scenario_ids.map do |id|
          scoped = resolver.call(id)
          Lifeplan::Forecast::Engine.new(scoped, scenario_id: id, from: from, to: to).call
        end

        at_year = at || results.first.to
        metrics = parse_metrics(opts[:metrics])

        rows = results.map { |r| summary_row(r, at_year, metrics) }

        data = { "at" => at_year, "metrics" => metrics, "scenarios" => rows }
        payload(
          data: data,
          text: compare_text(rows, metrics, at_year),
          markdown: compare_markdown(rows, metrics, at_year),
        )
      end

      private

      def parse_metrics(str)
        return DEFAULT_METRICS if str.nil? || str.empty?

        list = str.split(",").map(&:strip).reject(&:empty?)
        unknown = list - KNOWN_METRICS
        unless unknown.empty?
          raise Lifeplan::InvalidArguments,
            "unknown metric(s): #{unknown.join(", ")}. Known: #{KNOWN_METRICS.join(", ")}"
        end
        list
      end

      def summary_row(result, at_year, _metrics)
        at_row = result.years.find { |y| y.year == at_year }
        depletion = result.years.find { |y| y.liquid_balance.negative? }
        min_liq = result.years.min_by(&:liquid_balance)

        {
          "scenario_id" => result.scenario_id,
          "net_worth" => at_row&.net_worth,
          "liquid" => at_row&.liquid_balance,
          "depletion_year" => depletion&.year,
          "min_liquid_year" => min_liq&.year,
          "final_asset_balance" => result.summary.final_asset_balance,
          "total_income" => result.summary.total_income,
          "total_expense" => result.summary.total_expense,
        }
      end

      def column_label(metric, at_year)
        AT_METRICS.include?(metric) ? "#{metric}@#{at_year}" : metric
      end

      def cell(value)
        value.nil? ? "—" : value.to_s
      end

      def compare_text(rows, metrics, at_year)
        headers = ["scenario"] + metrics.map { |m| column_label(m, at_year) }
        body = rows.map do |row|
          [row["scenario_id"]] + metrics.map { |m| cell(row[m]) }
        end
        widths = headers.each_with_index.map do |h, i|
          ([h.length] + body.map { |r| r[i].to_s.length }).max
        end
        format_line = ->(values) { values.each_with_index.map { |v, i| v.to_s.ljust(widths[i]) }.join("  ") }
        lines = [format_line.call(headers)]
        lines << widths.map { |w| "-" * w }.join("  ")
        body.each { |r| lines << format_line.call(r) }
        lines.join("\n")
      end

      def compare_markdown(rows, metrics, at_year)
        headers = ["scenario"] + metrics.map { |m| column_label(m, at_year) }
        lines = ["| " + headers.join(" | ") + " |"]
        lines << "|" + (["---"] * headers.size).join("|") + "|"
        rows.each do |row|
          values = [row["scenario_id"]] + metrics.map { |m| cell(row[m]) }
          lines << "| " + values.join(" | ") + " |"
        end
        lines.join("\n")
      end
    end
  end
end
