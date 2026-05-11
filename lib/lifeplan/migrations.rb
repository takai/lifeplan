# frozen_string_literal: true

require "digest"
require "fileutils"
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

    module TemplateRefresh
      # Files that v0.1.0 init scaffolded into a workspace, with the SHA-256 of
      # the bundled content at that release. Used to detect whether the file in
      # the workspace is the unmodified original (safe to replace or remove) or
      # has been customized (skip with a warning so the user can review).
      LEGACY_FILES = [
        {
          path: "CLAUDE.md",
          legacy_hash: "e7cfbaefb39f28ade4cc60a18c8b913d1c36ee9c2e5af79363b3c55bb27de6ed",
          action: :replace,
        },
        {
          path: ".claude/skills/lifeplan-product/SKILL.md",
          legacy_hash: "b5255515baf9fa16b84de0e899408c41afba91e748a0edcf5e1bdcc14f29f74c",
          action: :remove,
        },
        {
          path: ".claude/skills/lifeplan-cli/SKILL.md",
          legacy_hash: "706b6ac5c60b388e1d5bac0a0de002edf6e523242de1e39a8718edd8f7ae8a31",
          action: :remove,
        },
        {
          path: ".claude/skills/lifeplan-data/SKILL.md",
          legacy_hash: "3f709e062498faa54c54db56c3fa7eb9b6c15ed06ecfc448d6bc00ed4473478a",
          action: :remove,
        },
        {
          path: "docs/prd.md",
          legacy_hash: "4d6249fab9089752da91b4f6ba8813f36aeb0afd582d7292f4a0ac41ae5a31b1",
          action: :remove,
        },
        {
          path: "docs/cli.md",
          legacy_hash: "7875db55aeeceefc4077292d34f0f78a0f23d1662b2bb59882e02225137a7895",
          action: :remove,
        },
        {
          path: "docs/datamodel.md",
          legacy_hash: "d45bbf23d2a72e2ede38eb09b19d7a54e8fc88f9e2a0777f4e1e77744f86b89b",
          action: :remove,
        },
      ].freeze

      VERSION_FROM = "0.1.0"
      VERSION_TO = "0.2.0"

      extend self

      def steps(project)
        out = []
        planned = []

        LEGACY_FILES.each do |entry|
          abs = File.join(project.path, entry[:path])
          next unless File.file?(abs)

          actual = sha256(abs)
          if actual == entry[:legacy_hash]
            case entry[:action]
            when :remove
              out << Step.new(
                version_from: VERSION_FROM,
                version_to: VERSION_TO,
                path: entry[:path],
                operation: "file_remove",
                before: short(actual),
                after: nil,
                severity: "info",
                note: "Remove legacy v0.1.0 scaffold (now obsolete).",
              )
            when :replace
              out << Step.new(
                version_from: VERSION_FROM,
                version_to: VERSION_TO,
                path: entry[:path],
                operation: "file_replace",
                before: short(actual),
                after: short(bundled_hash(entry[:path])),
                severity: "info",
                note: "Replace legacy v0.1.0 scaffold with the current bundled template.",
              )
            end
          elsif entry[:action] == :replace && bundled_present?(entry[:path]) && actual == bundled_hash(entry[:path])
            # Already at current bundled content; nothing to do.
          else
            out << Step.new(
              version_from: VERSION_FROM,
              version_to: VERSION_TO,
              path: entry[:path],
              operation: "file_skip",
              before: short(actual),
              after: short(entry[:legacy_hash]),
              severity: "warning",
              note: "File differs from the v0.1.0 scaffold (likely customized). " \
                "Move it aside and re-run upgrade to install the new template.",
            )
          end

          planned << entry[:path]
        end

        bundled_template_paths.each do |rel|
          next if planned.include?(rel)

          abs = File.join(project.path, rel)
          next if File.exist?(abs)

          out << Step.new(
            version_from: VERSION_FROM,
            version_to: VERSION_TO,
            path: rel,
            operation: "file_add",
            before: nil,
            after: short(bundled_hash(rel)),
            severity: "info",
            note: "Add new bundled template.",
          )
        end

        out << Step.new(
          version_from: VERSION_FROM,
          version_to: VERSION_TO,
          path: "lifeplan_version",
          operation: "update",
          before: VERSION_FROM,
          after: VERSION_TO,
          severity: "info",
          note: "Stamp workspace with v#{VERSION_TO}.",
        )

        out
      end

      def bundled_template_paths
        root = File.join(Lifeplan::ROOT, "templates")
        return [] unless File.directory?(root)

        Dir.glob("**/*", File::FNM_DOTMATCH, base: root).select do |entry|
          File.file?(File.join(root, entry))
        end
      end

      def bundled_present?(rel)
        File.file?(File.join(Lifeplan::ROOT, "templates", rel))
      end

      def bundled_hash(rel)
        sha256(File.join(Lifeplan::ROOT, "templates", rel))
      end

      def sha256(path)
        Digest::SHA256.hexdigest(File.binread(path))
      end

      def short(hex)
        hex && hex[0, 12]
      end
    end

    REGISTRY = [
      Migration.new(
        from_version: nil,
        to_version: "0.1.0",
        description: "Stamp pre-versioning workspaces as v0.1.0",
        apply: ->(_project) {
          [
            Step.new(
              version_from: nil,
              version_to: "0.1.0",
              path: "lifeplan_version",
              operation: "add",
              before: nil,
              after: "0.1.0",
              severity: "info",
              note: "Pre-versioning workspace; stamping as 0.1.0.",
            ),
          ]
        },
      ),
      Migration.new(
        from_version: "0.1.0",
        to_version: "0.2.0",
        description: "Replace developer-oriented workspace templates with the financial-planner persona",
        apply: ->(project) { TemplateRefresh.steps(project) },
      ),
    ].freeze

    class << self
      def chain(from_version, to_version)
        result = []
        current = from_version
        until equal_versions?(current, to_version)
          step = REGISTRY.find do |m|
            equal_versions?(m.from_version, current) && version_lte?(m.to_version, to_version)
          end
          break unless step

          result << step
          current = step.to_version
        end
        result
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
        when "add", "update"
          project.lifeplan_version = step.after if step.path == "lifeplan_version"
        when "rename", "remove"
          # Placeholder for future JSON-level migrations.
        when "file_remove"
          abs = File.join(project.path, step.path)
          FileUtils.rm_f(abs)
          prune_empty_parents(project.path, step.path)
        when "file_replace", "file_add"
          src = File.join(Lifeplan::ROOT, "templates", step.path)
          dest = File.join(project.path, step.path)
          FileUtils.mkdir_p(File.dirname(dest))
          FileUtils.cp(src, dest)
        when "file_skip"
          # No-op: warning lives in the step note for human review.
        end
      end

      def prune_empty_parents(project_path, rel)
        root = File.expand_path(project_path)
        dir = File.expand_path(File.dirname(File.join(project_path, rel)))
        while dir.start_with?("#{root}/") && File.directory?(dir) && Dir.empty?(dir)
          Dir.rmdir(dir)
          dir = File.dirname(dir)
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
