# frozen_string_literal: true

require "lifeplan/commands/helpers"
require "lifeplan/migrations"
require "lifeplan/version"

module Lifeplan
  module Commands
    module UpgradeCommands
      include Helpers

      def upgrade_payload(opts)
        project = load_project
        to_version = opts[:to] || Lifeplan::VERSION
        from_override = opts[:from]
        project.lifeplan_version = from_override if from_override

        result = Lifeplan::Migrations.plan(project, to_version: to_version)
        apply_requested = !!(opts[:apply] && !opts[:"dry-run"])
        applied = false

        if apply_requested && !result[:up_to_date]
          Lifeplan::Migrations.apply!(project, to_version: to_version)
          project.save
          applied = true
        end

        data = {
          "from" => result[:from],
          "to" => result[:to],
          "up_to_date" => result[:up_to_date],
          "applied" => applied,
          "dry_run" => !applied,
          "steps" => result[:steps].map(&:to_h),
        }
        payload(data: data, text: upgrade_text(data))
      end

      private

      def upgrade_text(data)
        lines = []
        if data["up_to_date"]
          lines << "Workspace is already at #{data["to"]}."
          return lines.join("\n")
        end

        suffix = data["applied"] ? "applied" : "dry-run"
        lines << "Upgrade #{data["from"] || "(unversioned)"} -> #{data["to"]} (#{suffix}):"
        data["steps"].each do |step|
          lines << "  - [#{step["severity"]}] #{step["operation"]} #{step["path"]}: " \
            "#{step["before"].inspect} -> #{step["after"].inspect}"
          lines << "      #{step["note"]}" if step["note"]
        end
        lines << "" << "Run with --apply to write changes." unless data["applied"]
        lines.join("\n")
      end
    end
  end
end
