# frozen_string_literal: true

require "lifeplan/commands/helpers"
require "lifeplan/storage"
require "lifeplan/records"

module Lifeplan
  module Commands
    module ProjectCommands
      include Helpers

      def init_project(path, opts)
        path ||= "."
        if Storage.exist?(path)
          raise InvalidArguments, "Project already exists at #{path}"
        end

        project = Lifeplan::Project.new(
          path: path,
          id: derive_project_id(path, opts[:name]),
          name: opts[:name] || File.basename(File.expand_path(path)),
          currency: opts[:currency] || "JPY",
          start_year: opts[:"start-year"] || Time.now.year,
          end_year: opts[:"end-year"] || (Time.now.year + 30),
        )
        project.profile = Records::Profile.from_hash(
          "id" => "default",
          "name" => "Default Profile",
          "people" => [],
        )
        project.save
        project
      end

      def project_summary(project)
        {
          "id" => project.id,
          "name" => project.name,
          "currency" => project.currency,
          "start_year" => project.start_year,
          "end_year" => project.end_year,
          "record_counts" => {
            "incomes" => project.incomes.size,
            "expenses" => project.expenses.size,
            "assets" => project.assets.size,
            "liabilities" => project.liabilities.size,
            "events" => project.events.size,
            "assumptions" => project.assumptions.size,
            "scenarios" => project.scenarios.size,
          },
          "proposals" => project.proposals.size,
        }
      end

      def project_status_text(project)
        counts = project_summary(project).fetch("record_counts")
        counts_str = counts.map { |k, v| "#{k}=#{v}" }.join(" ")
        <<~TEXT.strip
          Project:    #{project.name} (#{project.id})
          Period:     #{project.start_year} - #{project.end_year}
          Currency:   #{project.currency}
          Records:    #{counts_str}
          Proposals:  #{project.proposals.size}
        TEXT
      end

      private

      def derive_project_id(path, name)
        base = name || File.basename(File.expand_path(path))
        base.to_s.downcase.strip.gsub(/[^a-z0-9]+/, "-").gsub(/(^-|-$)/, "")
      end
    end
  end
end
