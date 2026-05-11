# frozen_string_literal: true

require "fileutils"
require "lifeplan/commands/helpers"
require "lifeplan/storage"
require "lifeplan/records"
require "lifeplan/version"

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
        project.lifeplan_version = Lifeplan::VERSION
        project.profile = Records::Profile.from_hash(
          "id" => "default",
          "name" => "Default Profile",
          "people" => [],
        )
        project.save
        write_init_scaffold(path)
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

      SCAFFOLD_DOCS = ["prd.md", "cli.md", "datamodel.md"].freeze

      def write_init_scaffold(path)
        copy_scaffold_docs(path)
        copy_scaffold_templates(path)
      end

      def copy_scaffold_docs(path)
        src_dir = File.join(Lifeplan::ROOT, "docs")
        dest_dir = File.join(path, "docs")
        FileUtils.mkdir_p(dest_dir)
        SCAFFOLD_DOCS.each do |name|
          src = File.join(src_dir, name)
          dest = File.join(dest_dir, name)
          next unless File.file?(src)
          next if File.exist?(dest)

          FileUtils.cp(src, dest)
        end
      end

      def copy_scaffold_templates(path)
        src_root = File.join(Lifeplan::ROOT, "templates")
        return unless File.directory?(src_root)

        Dir.glob("**/*", File::FNM_DOTMATCH, base: src_root).each do |entry|
          next if entry.end_with?("/.", "/..")

          src = File.join(src_root, entry)
          dest = File.join(path, entry)
          if File.directory?(src)
            FileUtils.mkdir_p(dest)
          elsif File.file?(src) && !File.exist?(dest)
            FileUtils.mkdir_p(File.dirname(dest))
            FileUtils.cp(src, dest)
          end
        end
      end
    end
  end
end
