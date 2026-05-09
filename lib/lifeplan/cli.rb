# frozen_string_literal: true

require "thor"
require "lifeplan/version"
require "lifeplan/errors"
require "lifeplan/exit_codes"
require "lifeplan/commands/helpers"
require "lifeplan/commands/project_commands"
require "lifeplan/commands/record_commands"
require "lifeplan/commands/mutation_commands"
require "lifeplan/commands/validation_commands"
require "lifeplan/commands/forecast_commands"
require "lifeplan/commands/scenario_commands"
require "lifeplan/commands/compare_commands"
require "lifeplan/commands/proposal_commands"
require "lifeplan/commands/calc_commands"
require "lifeplan/commands/export_commands"
require "lifeplan/commands/report_commands"

module Lifeplan
  class CLI < Thor
    include Commands::Helpers
    include Commands::ProjectCommands
    include Commands::RecordCommands
    include Commands::MutationCommands
    include Commands::ValidationCommands
    include Commands::ForecastCommands
    include Commands::CompareCommands
    include Commands::ProposalCommands
    include Commands::ExportCommands
    include Commands::ReportCommands

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

    desc "add TYPE", "Add a new record"
    Lifeplan::Commands::MutationCommands::ADD_OPTIONS.each do |opt|
      method_option opt.to_sym, type: :string
    end
    method_option :"dry-run", type: :boolean, default: false
    def add(type)
      render(add_payload(type, options))
    end

    desc "set TYPE ID FIELD VALUE", "Update a field on an existing record"
    method_option :"dry-run", type: :boolean, default: false
    def set(type, id, field, value)
      render(set_payload(type, id, field, value, options))
    end

    desc "validate", "Validate the project against rules"
    method_option :strict, type: :boolean, default: false
    def validate
      render(validate_payload(options))
    end

    desc "check", "Run heuristic checks against the project"
    method_option :scenario, type: :string
    def check
      render(check_payload(options))
    end

    desc "forecast", "Generate an annual life planning projection"
    method_option :scenario, type: :string
    method_option :from, type: :numeric
    method_option :to, type: :numeric
    method_option :"include-details", type: :boolean, default: false
    def forecast
      render(forecast_payload(options))
    end

    desc "explain TARGET [ARGS...]", "Explain a forecast result (year|metric|scenario-diff)"
    method_option :scenario, type: :string
    method_option :year, type: :numeric
    method_option :metric, type: :string
    def explain(target, *args)
      render(explain_payload(target, args, options))
    end

    desc "scenario SUBCOMMAND ...ARGS", "Manage scenarios"
    subcommand "scenario", Commands::ScenarioCLI

    desc "calc SUBCOMMAND ...ARGS", "Financial calculators"
    subcommand "calc", Commands::CalcCLI

    desc "propose ACTION TYPE [ARGS...]", "Create a change proposal without applying"
    Lifeplan::Commands::MutationCommands::ADD_OPTIONS.each do |opt|
      method_option opt.to_sym, type: :string
    end
    method_option :summary, type: :string
    def propose(action, type, *args)
      render(propose_payload(action, type, args, options))
    end

    desc "proposals", "List pending proposals"
    def proposals
      render(proposals_payload(options))
    end

    desc "apply PROPOSAL_ID", "Apply a proposal"
    method_option :"dry-run", type: :boolean, default: false
    method_option :force, type: :boolean, default: false
    def apply(id)
      render(apply_payload(id, options))
    end

    desc "discard PROPOSAL_ID", "Discard a proposal"
    def discard(id)
      render(discard_payload(id, options))
    end

    desc "diff", "Show differences (--proposal <id> | --scenario <id>)"
    method_option :proposal, type: :string
    method_option :scenario, type: :string
    def diff
      render(diff_payload(options))
    end

    desc "compare BASE TARGET", "Compare two scenarios"
    method_option :scenario, type: :string
    method_option :from, type: :numeric
    method_option :to, type: :numeric
    def compare(base, target)
      render(compare_payload(base, target, options))
    end

    desc "export TARGET [ARGS...]", "Export project data, forecasts, scenarios, comparisons, or validation"
    method_option :scenario, type: :string
    method_option :from, type: :numeric
    method_option :to, type: :numeric
    def export(target, *args)
      render(export_payload(target, args, options))
    end

    desc "report", "Generate a human-readable report"
    method_option :scenario, type: :string
    method_option :from, type: :numeric
    method_option :to, type: :numeric
    method_option :"include-validation", type: :boolean, default: false
    method_option :"include-assumptions", type: :boolean, default: true
    method_option :"include-scenarios", type: :boolean, default: false
    def report
      render(report_payload(options))
    end

    desc "remove TYPE ID", "Remove a record"
    method_option :"dry-run", type: :boolean, default: false
    method_option :force, type: :boolean, default: false
    def remove(type, id)
      render(remove_payload(type, id, options))
    end
  end
end
