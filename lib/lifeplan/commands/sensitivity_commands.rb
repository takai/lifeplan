# frozen_string_literal: true

require "csv"
require "lifeplan/commands/helpers"
require "lifeplan/errors"
require "lifeplan/scenarios/resolver"
require "lifeplan/scenarios/path"
require "lifeplan/coercion"
require "lifeplan/forecast/engine"

module Lifeplan
  module Commands
    module SensitivityCommands
      include Helpers

      SUMMARY_METRICS = [
        "final_asset_balance",
        "minimum_asset_balance",
        "minimum_asset_balance_year",
        "first_negative_asset_year",
        "asset_at_retirement",
        "retirement_year",
        "total_income",
        "total_expense",
        "depletion_year",
      ].freeze

      AT_YEAR_METRICS = ["net_worth", "asset_balance", "liquid_balance", "liquid"].freeze

      def sensitivity_payload(opts)
        spec = parse_spec(opts)
        project = load_project
        resolver = Lifeplan::Scenarios::Resolver.new(project)

        grid = spec.x_values.map do |x|
          spec.y_values.map do |y|
            evaluate_cell(resolver, spec, x, y)
          end
        end

        data = {
          "base_scenario" => spec.base_scenario || "base",
          "x_axis" => spec.x_axis,
          "x_values" => spec.x_values,
          "y_axis" => spec.y_axis,
          "y_values" => spec.y_values,
          "metric" => opts[:metric],
          "grid" => grid,
        }
        payload(
          data: data,
          text: render_text(spec, opts[:metric], grid),
          markdown: render_markdown(spec, opts[:metric], grid),
          csv: render_csv(spec, opts[:metric], grid),
        )
      end

      private

      Spec = Struct.new(
        :base_scenario,
        :x_axis,
        :y_axis,
        :x_values,
        :y_values,
        :metric_kind,
        :metric_year,
        :from,
        :to,
      )

      def parse_spec(opts)
        x_axis = require_opt(opts, :"x-axis")
        y_axis = require_opt(opts, :"y-axis")
        metric = require_opt(opts, :metric)
        kind, year = parse_metric(metric)
        Spec.new(
          opts[:"base-scenario"],
          x_axis,
          y_axis,
          parse_value_list(require_opt(opts, :"x-values"), x_axis),
          parse_value_list(require_opt(opts, :"y-values"), y_axis),
          kind,
          year,
          opts[:from]&.to_i,
          opts[:to]&.to_i,
        )
      end

      def require_opt(opts, key)
        value = opts[key]
        raise Lifeplan::InvalidArguments, "--#{key} is required" if value.nil? || value.to_s.empty?

        value
      end

      def parse_metric(metric)
        if metric =~ /\A(.+)_at_(\d{4})\z/
          [::Regexp.last_match(1), ::Regexp.last_match(2).to_i]
        elsif SUMMARY_METRICS.include?(metric)
          [metric, nil]
        else
          raise Lifeplan::InvalidArguments,
            "unknown metric '#{metric}'. Use <metric>_at_<year> for: " \
              "#{AT_YEAR_METRICS.join(", ")}; or one of: #{SUMMARY_METRICS.join(", ")}."
        end
      end

      def parse_value_list(raw, path)
        list = raw.to_s.split(",").map(&:strip).reject(&:empty?)
        raise Lifeplan::InvalidArguments, "empty value list for axis '#{path}'" if list.empty?

        list.map { |v| coerce_axis_value(path, v) }
      end

      def coerce_axis_value(path_str, raw)
        parsed = Lifeplan::Scenarios::Path.parse(path_str)
        if parsed.field
          Lifeplan::Coercion.coerce_field(parsed.type, parsed.field, raw)
        else
          raw
        end
      end

      def evaluate_cell(resolver, spec, x_value, y_value)
        derived = resolver.derive(spec.base_scenario, [
          { "op" => "set", "path" => spec.x_axis, "value" => x_value },
          { "op" => "set", "path" => spec.y_axis, "value" => y_value },
        ])
        result = Lifeplan::Forecast::Engine.new(
          derived, scenario_id: "sensitivity", from: spec.from, to: spec.to
        ).call
        {
          "x" => x_value,
          "y" => y_value,
          "value" => extract_metric(result, spec.metric_kind, spec.metric_year),
          "liquid_depleted" => liquid_depleted?(result),
        }
      end

      def extract_metric(result, kind, year)
        if year
          row = result.years.find { |y| y.year == year }
          return unless row

          case kind
          when "net_worth" then row.net_worth
          when "asset_balance" then row.asset_balance
          when "liquid_balance", "liquid" then row.liquid_balance
          end
        else
          case kind
          when "depletion_year"
            result.years.find { |y| y.liquid_balance.negative? }&.year
          else
            result.summary.to_h[kind]
          end
        end
      end

      def liquid_depleted?(result)
        result.years.any? { |y| y.liquid_balance.negative? }
      end

      def cell_label(cell)
        return "—" if cell["value"].nil?

        suffix = cell["liquid_depleted"] ? "*" : ""
        "#{cell["value"]}#{suffix}"
      end

      def render_text(spec, metric_name, grid)
        headers = [metric_name] + spec.y_values.map(&:to_s)
        body = spec.x_values.each_with_index.map do |x, i|
          [x.to_s] + grid[i].map { |c| cell_label(c) }
        end
        widths = headers.each_with_index.map do |h, i|
          ([h.length] + body.map { |r| r[i].length }).max
        end
        format_line = ->(values) { values.each_with_index.map { |v, i| v.ljust(widths[i]) }.join("  ") }
        lines = [format_line.call(headers)]
        lines << widths.map { |w| "-" * w }.join("  ")
        body.each { |r| lines << format_line.call(r) }
        lines.join("\n")
      end

      def render_markdown(spec, metric_name, grid)
        headers = [metric_name] + spec.y_values.map(&:to_s)
        lines = ["| " + headers.join(" | ") + " |"]
        lines << "|" + (["---"] * headers.size).join("|") + "|"
        spec.x_values.each_with_index do |x, i|
          values = [x.to_s] + grid[i].map { |c| cell_label(c) }
          lines << "| " + values.join(" | ") + " |"
        end
        lines.join("\n")
      end

      def render_csv(spec, metric_name, grid)
        CSV.generate do |csv|
          csv << [metric_name] + spec.y_values
          spec.x_values.each_with_index do |x, i|
            csv << [x] + grid[i].map { |c| cell_label(c) }
          end
        end
      end
    end
  end
end
