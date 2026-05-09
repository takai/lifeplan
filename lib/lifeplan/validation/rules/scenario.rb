# frozen_string_literal: true

require "lifeplan/validation/issue"

module Lifeplan
  module Validation
    module Rules
      module Scenario
        extend self

        def call(project)
          issues = []
          ids = project.scenarios.map(&:id)

          project.scenarios.each do |s|
            if s.base && !ids.include?(s.base)
              issues << Issue.error(
                "SCENARIO_BASE_MISSING",
                "scenario '#{s.id}' references missing base '#{s.base}'.",
                record_type: "scenario",
                record_id: s.id,
                path: "base",
              )
            end
          end

          issues.concat(detect_cycles(project.scenarios))
          issues
        end

        def detect_cycles(scenarios)
          by_id = scenarios.each_with_object({}) { |s, h| h[s.id] = s }
          issues = []

          scenarios.each do |s|
            visited = []
            current = s
            while current&.base
              if visited.include?(current.id)
                issues << Issue.error(
                  "SCENARIO_CYCLE",
                  "scenario '#{s.id}' inherits cyclically via #{visited.join(" -> ")}.",
                  record_type: "scenario",
                  record_id: s.id,
                  path: "base",
                )
                break
              end
              visited << current.id
              current = by_id[current.base]
            end
          end
          issues.uniq { |i| [i.code, i.record_id] }
        end
      end
    end
  end
end
