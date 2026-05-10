# frozen_string_literal: true

require "thor"
require "lifeplan/commands/helpers"
require "lifeplan/scenarios/resolver"
require "lifeplan/forecast/engine"
require "lifeplan/records"

module Lifeplan
  module Commands
    class ScenarioCLI < Thor
      include Helpers

      desc "list", "List scenarios"
      def list
        project = load_project
        rows = project.scenarios.map { |s| scenario_summary(s) }
        render(payload(
          data: rows,
          text: rows.empty? ? "(no scenarios)" : rows.map { |r| "#{r["id"]}\t#{r["name"]}" }.join("\n"),
        ))
      end

      desc "create ID", "Create a new scenario"
      method_option :name, type: :string
      method_option :base, type: :string
      def create(id)
        project = load_project
        raise Lifeplan::InvalidArguments, "scenario '#{id}' already exists" if project.scenarios.any? { |s| s.id == id }

        scenario = Lifeplan::Records::Scenario.from_hash({
          "id" => id,
          "name" => options[:name] || id,
          "base" => options[:base],
          "overrides" => [],
        })
        project.scenarios << scenario
        project.save
        render(payload(data: scenario_summary(scenario), text: "Created scenario '#{id}'."))
      end

      desc "set SCENARIO_ID PATH VALUE", "Append an override to a scenario"
      method_option :"dry-run", type: :boolean, default: false
      def set(scenario_id, path, value)
        project = load_project
        scenario = project.scenarios.find { |s| s.id == scenario_id } ||
          raise(Lifeplan::ScenarioNotFound, "scenario '#{scenario_id}' not found")

        normalized_path = normalize_path(path)
        override = { "op" => "set", "path" => normalized_path, "value" => coerce_override_value(value) }
        overrides = (scenario.overrides || []) + [override]
        idx = project.scenarios.find_index { |s| s.id == scenario_id }
        project.scenarios[idx] = scenario.with(overrides: overrides)
        project.save unless options[:"dry-run"]
        render(payload(
          data: { "scenario_id" => scenario_id, "override" => override, "applied" => !options[:"dry-run"] },
          text: "Added override #{normalized_path} = #{value} to '#{scenario_id}'#{options[:"dry-run"] ? " (dry-run)" : ""}",
        ))
      end

      desc "apply SCENARIO_ID", "Create a derived scenario by stacking overrides on top of an existing one"
      method_option :to, type: :string, required: true, desc: "ID of the new scenario to create"
      method_option :name, type: :string
      method_option :override,
        type: :string,
        repeatable: true,
        default: [],
        desc: "Override expressed as PATH=VALUE (repeatable)"
      method_option :"dry-run", type: :boolean, default: false
      def apply(scenario_id)
        project = load_project
        unless scenario_id == "base" || project.scenarios.any? { |s| s.id == scenario_id }
          raise Lifeplan::ScenarioNotFound, "scenario '#{scenario_id}' not found"
        end

        new_id = options[:to]
        if project.scenarios.any? { |s| s.id == new_id }
          raise Lifeplan::InvalidArguments, "scenario '#{new_id}' already exists"
        end

        overrides = options[:override].map { |raw| parse_override_arg(raw) }

        scenario = Lifeplan::Records::Scenario.from_hash({
          "id" => new_id,
          "name" => options[:name] || new_id,
          "base" => scenario_id,
          "overrides" => overrides,
        })

        project.scenarios << scenario
        Lifeplan::Scenarios::Resolver.new(project).call(new_id)
        project.save unless options[:"dry-run"]
        render(payload(
          data: scenario_summary(scenario).merge("applied" => !options[:"dry-run"]),
          text: "Created scenario '#{new_id}' from '#{scenario_id}' with #{overrides.size} override(s)" \
            "#{options[:"dry-run"] ? " (dry-run)" : ""}",
        ))
      end

      desc "remove SCENARIO_ID", "Remove a scenario"
      def remove(scenario_id)
        project = load_project
        existed = project.scenarios.any? { |s| s.id == scenario_id }
        raise Lifeplan::ScenarioNotFound, "scenario '#{scenario_id}' not found" unless existed

        project.scenarios.reject! { |s| s.id == scenario_id }
        project.save
        render(payload(data: { "removed" => scenario_id }, text: "Removed scenario '#{scenario_id}'."))
      end

      private

      def scenario_summary(s)
        {
          "id" => s.id,
          "name" => s.name,
          "base" => s.base,
          "override_count" => (s.overrides || []).size,
        }
      end

      def normalize_path(path)
        parts = path.split(".")
        type = Lifeplan::Schema.canonical(parts[0])
        return path if parts.size >= 3
        return "#{type}.#{parts[1]}.value" if parts.size == 2 && type == "assumption"

        path
      end

      def parse_override_arg(raw)
        key, _, val = raw.partition("=")
        raise Lifeplan::InvalidArguments, "override must be in 'path=value' form: #{raw}" if val.empty?

        { "op" => "set", "path" => normalize_path(key), "value" => coerce_override_value(val) }
      end

      def coerce_override_value(raw)
        return raw if raw.is_a?(Numeric)

        return Float(raw) if raw.match?(/\A-?\d+\.\d+\z/)
        return Integer(raw, 10) if raw.match?(/\A-?\d+\z/)
        return true if raw == "true"
        return false if raw == "false"

        raw
      end
    end
  end
end
