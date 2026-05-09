# frozen_string_literal: true

require "lifeplan/commands/helpers"
require "lifeplan/validation/validator"

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

      def check_payload(_opts)
        load_project
        data = {
          "risks" => [],
          "note" => "Heuristic checks require forecast (Phase 4); no risks reported.",
        }
        payload(
          data: data,
          text: "No risks detected (forecast-based checks not yet available).",
        )
      end

      private

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
