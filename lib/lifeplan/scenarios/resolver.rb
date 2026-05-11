# frozen_string_literal: true

require "lifeplan/errors"
require "lifeplan/project"
require "lifeplan/records"
require "lifeplan/scenarios/path"
require "lifeplan/coercion"

module Lifeplan
  module Scenarios
    class Resolver
      def initialize(project)
        @project = project
      end

      def call(scenario_id)
        return clone_project(@project) if scenario_id.nil? || scenario_id == "base"

        scenario = find_scenario!(scenario_id)
        chain = inheritance_chain(scenario)
        derived = clone_project(@project)
        chain.each { |s| apply_scenario(derived, s) }
        derived
      end

      def derive(scenario_id, overrides)
        derived = call(scenario_id)
        Array(overrides).each { |override| apply_override(derived, override) }
        derived
      end

      private

      def find_scenario!(id)
        @project.scenarios.find { |s| s.id == id } ||
          raise(Lifeplan::ScenarioNotFound, "scenario '#{id}' not found")
      end

      def inheritance_chain(scenario)
        chain = []
        current = scenario
        visited = []
        while current
          raise Lifeplan::InvalidArguments, "scenario inheritance cycle at '#{current.id}'" if visited.include?(current.id)

          visited << current.id
          chain.unshift(current)
          current = current.base ? @project.scenarios.find { |s| s.id == current.base } : nil
        end
        chain
      end

      def apply_scenario(project, scenario)
        (scenario.overrides || []).each do |override|
          apply_override(project, override)
        end
      end

      def apply_override(project, override)
        op = (override["op"] || override[:op] || "set").to_s
        path = Path.parse(override["path"] || override[:path])
        value = override["value"] || override[:value]

        case op
        when "set" then apply_set(project, path, value)
        when "remove" then apply_remove(project, path)
        when "add" then apply_add(project, path, value)
        else
          raise Lifeplan::InvalidArguments, "unsupported override op '#{op}'"
        end
      end

      def apply_set(project, path, value)
        collection = project.collection(path.type)
        idx = collection.find_index { |r| r.id == path.id }
        raise Lifeplan::InvalidArguments, "scenario target #{path.type} '#{path.id}' not found" unless idx

        if path.field
          Lifeplan::Coercion.lookup_field(path.type, path.field)
          field = path.field.to_sym
          coerced = if path.type == "assumption" && field == :value
            value
          else
            Lifeplan::Coercion.coerce_field(path.type, path.field, value)
          end
          collection[idx] = collection[idx].with(field => coerced)
        else
          klass = Lifeplan::Records.class_for(path.type)
          collection[idx] = klass.from_hash(value.merge("id" => path.id))
        end
      end

      def apply_remove(project, path)
        collection = project.collection(path.type)
        unless collection.any? { |r| r.id == path.id }
          raise Lifeplan::InvalidArguments, "scenario target #{path.type} '#{path.id}' not found"
        end

        collection.reject! { |r| r.id == path.id }
      end

      def apply_add(project, path, value)
        collection = project.collection(path.type)
        if collection.any? { |r| r.id == path.id }
          raise Lifeplan::InvalidArguments, "scenario target #{path.type} '#{path.id}' already exists"
        end

        klass = Lifeplan::Records.class_for(path.type)
        record = klass.from_hash((value || {}).merge("id" => path.id))
        collection << record
      end

      def clone_project(src)
        copy = Lifeplan::Project.new(
          path: src.path,
          id: src.id,
          name: src.name,
          currency: src.currency,
          start_year: src.start_year,
          end_year: src.end_year,
        )
        copy.profile = src.profile
        Lifeplan::Project::COLLECTIONS.each_key do |key|
          copy.public_send("#{key}=", src.public_send(key).dup)
        end
        copy.proposals = src.proposals.dup
        copy
      end
    end
  end
end
