# frozen_string_literal: true

require "lifeplan/commands/helpers"
require "lifeplan/commands/forecast_commands"
require "lifeplan/commands/validation_commands"
require "lifeplan/commands/compare_commands"
require "lifeplan/scenarios/resolver"

module Lifeplan
  module Commands
    module ReportCommands
      include Helpers
      include ForecastCommands
      include ValidationCommands
      include CompareCommands

      def report_payload(opts)
        base_project = load_project
        project = scenario_project(base_project, opts[:scenario])
        forecast = build_forecast(project, opts)
        sections = build_sections(base_project, project, forecast, opts)
        markdown = render_report_markdown(base_project, sections)
        text = render_report_text(base_project, sections)
        payload(
          data: { "title" => report_title(base_project, opts), "sections" => sections },
          text: text,
          markdown: markdown,
        )
      end

      private

      def scenario_project(base, scenario_id)
        return base if scenario_id.nil? || scenario_id == "base"

        Lifeplan::Scenarios::Resolver.new(base).call(scenario_id)
      end

      def report_title(project, opts)
        suffix = opts[:scenario] && opts[:scenario] != "base" ? " — scenario #{opts[:scenario]}" : ""
        "Life Plan Report: #{project.name}#{suffix}"
      end

      def build_sections(base_project, project, forecast, opts)
        sections = []
        sections << summary_section(project, forecast)
        sections << assumptions_section(project) if opts[:"include-assumptions"] != false
        sections << forecast_section(forecast)
        sections << validation_section(project) if opts[:"include-validation"]
        sections << scenario_section(base_project, opts) if opts[:"include-scenarios"]
        sections.compact
      end

      def summary_section(project, forecast)
        {
          "title" => "Summary",
          "kind" => "summary",
          "content" => {
            "project" => project.name,
            "period" => "#{project.start_year}-#{project.end_year}",
            "currency" => project.currency,
            "summary" => forecast.summary.to_h,
          },
        }
      end

      def assumptions_section(project)
        rows = project.assumptions.map { |a| a.to_h.transform_keys(&:to_s) }
        {
          "title" => "Assumptions",
          "kind" => "assumptions",
          "content" => rows,
        }
      end

      def forecast_section(forecast)
        rows = forecast.years.map(&:to_h)
        {
          "title" => "Forecast",
          "kind" => "forecast",
          "content" => { "years" => rows, "summary" => forecast.summary.to_h },
        }
      end

      def validation_section(project)
        issues = Lifeplan::Validation::Validator.new.call(project).map(&:to_h)
        {
          "title" => "Validation",
          "kind" => "validation",
          "content" => issues,
        }
      end

      def scenario_section(base_project, opts)
        return if base_project.scenarios.empty?

        rows = base_project.scenarios.map do |s|
          target = Lifeplan::Scenarios::Resolver.new(base_project).call(s.id)
          fc = Lifeplan::Forecast::Engine.new(target, scenario_id: s.id, from: opts[:from]&.to_i, to: opts[:to]&.to_i).call
          { "scenario_id" => s.id, "name" => s.name, "summary" => fc.summary.to_h }
        end
        {
          "title" => "Scenarios",
          "kind" => "scenario_comparison",
          "content" => rows,
        }
      end

      def render_report_markdown(project, sections)
        lines = ["# Life Plan Report: #{project.name}", ""]
        sections.each do |section|
          lines << "## #{section["title"]}"
          lines << ""
          lines.concat(format_section_markdown(section))
          lines << ""
        end
        lines.join("\n")
      end

      def render_report_text(project, sections)
        lines = ["Life Plan Report: #{project.name}", ""]
        sections.each do |section|
          lines << "## #{section["title"]}"
          lines.concat(format_section_text(section))
          lines << ""
        end
        lines.join("\n")
      end

      def format_section_markdown(section)
        case section["kind"]
        when "summary" then summary_markdown(section["content"])
        when "assumptions" then table_markdown(section["content"], ["id", "name", "value"])
        when "forecast" then forecast_section_markdown(section["content"])
        when "validation" then validation_markdown(section["content"])
        when "scenario_comparison" then scenario_markdown(section["content"])
        else [section["content"].inspect]
        end
      end

      def format_section_text(section)
        format_section_markdown(section)
      end

      def summary_markdown(content)
        lines = [
          "- Project: #{content["project"]}",
          "- Period: #{content["period"]}",
          "- Currency: #{content["currency"]}",
          "",
          "Summary metrics:",
        ]
        content["summary"].each { |k, v| lines << "- #{k}: #{v.inspect}" }
        lines
      end

      def table_markdown(rows, columns)
        return ["(none)"] if rows.empty?

        header = "| " + columns.join(" | ") + " |"
        sep = "|" + (["---"] * columns.size).join("|") + "|"
        body = rows.map { |r| "| " + columns.map { |c| r[c].to_s }.join(" | ") + " |" }
        [header, sep, *body]
      end

      def forecast_section_markdown(content)
        cols = ForecastCommands::FORECAST_COLUMNS
        rows = content["years"]
        header = "| " + cols.join(" | ") + " |"
        sep = "|" + (["---"] * cols.size).join("|") + "|"
        body = rows.map { |row| "| " + cols.map { |c| row[c.to_sym].to_s }.join(" | ") + " |" }
        [header, sep, *body, "", "Summary: #{content["summary"].inspect}"]
      end

      def validation_markdown(issues)
        return ["No validation issues."] if issues.empty?

        issues.map { |i| "- [#{i[:level] || i["level"]}] #{i[:code] || i["code"]}: #{i[:message] || i["message"]}" }
      end

      def scenario_markdown(rows)
        return ["(no scenarios)"] if rows.empty?

        rows.map { |r| "- #{r["scenario_id"]} (#{r["name"]}): #{r["summary"].inspect}" }
      end
    end
  end
end
