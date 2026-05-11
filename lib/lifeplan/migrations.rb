# frozen_string_literal: true

require "lifeplan/version"

module Lifeplan
  module Migrations
    Migration = Data.define(:from_version, :to_version, :description, :apply) do
      def call(project)
        apply.call(project)
      end
    end

    Step = Data.define(:version_from, :version_to, :path, :operation, :before, :after, :severity, :note) do
      def to_h
        {
          "version_from" => version_from,
          "version_to" => version_to,
          "path" => path,
          "operation" => operation,
          "before" => before,
          "after" => after,
          "severity" => severity,
          "note" => note,
        }
      end
    end

    REGISTRY = [
      Migration.new(
        from_version: nil,
        to_version: Lifeplan::VERSION,
        description: "Stamp pre-versioning workspaces with the current CLI version",
        apply: ->(_project) {
          [
            Step.new(
              version_from: nil,
              version_to: Lifeplan::VERSION,
              path: "lifeplan_version",
              operation: "add",
              before: nil,
              after: Lifeplan::VERSION,
              severity: "info",
              note: "Pre-versioning workspace; stamping with current CLI version",
            ),
          ]
        },
      ),
    ].freeze

    class << self
      def chain(from_version, to_version)
        REGISTRY.select do |m|
          equal_versions?(m.from_version, from_version) && version_lte?(m.to_version, to_version)
        end
      end

      def plan(project, to_version: Lifeplan::VERSION)
        from = project.lifeplan_version
        return { from: from, to: to_version, steps: [], up_to_date: true } if equal_versions?(from, to_version)

        migrations = chain(from, to_version)
        steps = migrations.flat_map { |m| m.call(project) }
        { from: from, to: to_version, steps: steps, up_to_date: false, migrations: migrations.size }
      end

      def apply!(project, to_version: Lifeplan::VERSION)
        result = plan(project, to_version: to_version)
        result[:steps].each do |step|
          apply_step!(project, step)
        end
        project.lifeplan_version = to_version unless result[:up_to_date]
        result
      end

      private

      def apply_step!(project, step)
        case step.operation
        when "add"
          # The pre-versioning stamp is handled by the version assignment below.
          # Future "add" steps would set fields on records here.
          project.lifeplan_version = step.after if step.path == "lifeplan_version"
        when "rename", "update"
          # Placeholder for future migrations that rewrite fields.
        when "remove"
          # Placeholder for future migrations that drop fields.
        end
      end

      def equal_versions?(a, b)
        a.to_s == b.to_s
      end

      def version_lte?(target, ceiling)
        Gem::Version.new(target.to_s) <= Gem::Version.new(ceiling.to_s)
      end
    end
  end
end
