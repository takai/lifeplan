# frozen_string_literal: true

require "thor"
require "lifeplan/version"
require "lifeplan/errors"
require "lifeplan/exit_codes"
require "lifeplan/commands/helpers"
require "lifeplan/commands/project_commands"
require "lifeplan/commands/record_commands"

module Lifeplan
  class CLI < Thor
    include Commands::Helpers
    include Commands::ProjectCommands
    include Commands::RecordCommands

    class << self
      def exit_on_failure?
        true
      end

      def start(given_args = ARGV, config = {})
        super
      rescue Lifeplan::Error => e
        warn(e.message)
        exit(e.exit_code)
      end
    end

    class_option :project, type: :string, desc: "Project directory"
    class_option :format,
      type: :string,
      default: "text",
      enum: ["text", "json", "csv", "markdown"],
      desc: "Output format"
    class_option :quiet, type: :boolean, default: false
    class_option :verbose, type: :boolean, default: false
    class_option(:"no-color", type: :boolean, default: false)

    map ["--version", "-v"] => :version

    desc "version", "Show version"
    def version
      puts Lifeplan::VERSION
    end

    desc "init [PATH]", "Create a new life planning project"
    method_option :name, type: :string
    method_option :"start-year", type: :numeric
    method_option :"end-year", type: :numeric
    method_option :currency, type: :string
    method_option :template, type: :string
    def init(path = ".")
      project = init_project(path, options)
      render(payload(
        data: project_summary(project),
        text: "Initialized project '#{project.name}' at #{path}",
      ))
    end

    desc "status", "Show current project status"
    def status
      project = load_project
      render(payload(data: project_summary(project), text: project_status_text(project)))
    end

    desc "schema [TYPE]", "Show supported record types and fields"
    def schema(type = nil)
      render(schema_payload(type))
    end

    desc "list TYPE", "List records of a given type"
    method_option :category, type: :string
    method_option :from, type: :numeric
    method_option :to, type: :numeric
    def list(type)
      render(list_payload(type, options))
    end

    desc "get TYPE ID", "Show a specific record"
    def get(type, id)
      render(get_payload(type, id))
    end
  end
end
