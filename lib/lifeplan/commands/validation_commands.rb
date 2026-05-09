# frozen_string_literal: true

require "lifeplan/commands/helpers"
require "lifeplan/validation/validator"
require "lifeplan/forecast/engine"
require "lifeplan/forecast/year_builder"

module Lifeplan
  module Commands
    module ValidationCommands
      include Helpers

      def validate_payload(opts)
        project = load_project
        issues = Lifeplan::Validation::Validator.new.call(project)
        strict = opts[:strict] || opts["strict"]

        errors = issues.select(&:error?).map(&:to_h)
        warnings = issues.select(&:warning?).map(&:to_h)

        if strict
          errors.concat(warnings)
          warnings = []
        end

        valid = errors.empty?
        data = {
          "valid" => valid,
          "errors" => errors,
          "warnings" => warnings,
        }

        text = validation_text(valid, errors, warnings)
        result = payload(data: data, text: text)

        raise Lifeplan::ValidationFailed, validation_failure_message(errors) unless valid

        result
      end

      def check_payload(opts)
        project = load_project
        result = Lifeplan::Forecast::Engine.new(
          project, scenario_id: opts[:scenario] || "base"
        ).call

        risks = []
        risks.concat(check_negative_assets(result))
        risks.concat(check_retirement_income(project, result))
        risks.concat(check_loan_beyond_period(project))

        data = { "risks" => risks }
        text = if risks.empty?
          "No risks detected."
        else
          "Detected #{risks.size} risk(s):\n" + risks.map { |r| "  - #{r["code"]}: #{r["message"]}" }.join("\n")
        end
        payload(data: data, text: text)
      end

      private

      def check_negative_assets(result)
        year = result.summary.first_negative_asset_year
        return [] unless year

        [{
          "code" => "ASSETS_NEGATIVE",
          "message" => "Asset balance becomes negative in #{year}.",
          "year" => year,
        }]
      end

      def check_retirement_income(project, result)
        ry = result.summary.retirement_year
        return [] unless ry

        post = result.years.select { |r| r.year > ry }
        return [] if post.empty? || post.any? { |r| r.income.positive? }

        [{
          "code" => "MISSING_RETIREMENT_INCOME",
          "message" => "No income recorded after retirement year #{ry}.",
          "year" => ry,
        }]
      end

      def check_loan_beyond_period(project)
        end_year = project.end_year
        return [] unless end_year

        project.liabilities.filter_map do |l|
          next unless l.to && l.to > end_year

          {
            "code" => "LIABILITY_BEYOND_PROJECT",
            "message" => "liability '#{l.id}' repayment ends at #{l.to}, after project end #{end_year}.",
            "record_id" => l.id,
          }
        end
      end

      def validation_text(valid, errors, warnings)
        lines = []
        lines << (valid ? "Project is valid." : "Project has #{errors.size} error(s).")
        (errors + warnings).each do |issue|
          lines << format_issue(issue)
        end
        lines.join("\n")
      end

      def format_issue(issue)
        target = [issue["record_type"], issue["record_id"]].compact.join(" ")
        prefix = issue["severity"].upcase
        location = target.empty? ? "" : " [#{target}]"
        "#{prefix} #{issue["code"]}#{location}: #{issue["message"]}"
      end

      def validation_failure_message(errors)
        "Validation failed with #{errors.size} error(s):\n" +
          errors.map { |e| "  - #{e["code"]}: #{e["message"]}" }.join("\n")
      end
    end
  end
end
