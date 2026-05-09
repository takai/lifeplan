# frozen_string_literal: true

require "lifeplan/commands/helpers"
require "lifeplan/scenarios/resolver"
require "lifeplan/forecast/engine"

module Lifeplan
  module Commands
    module CompareCommands
      include Helpers

      def compare_payload(base_id, target_id, opts)
        project = load_project
        resolver = Lifeplan::Scenarios::Resolver.new(project)
        base_proj = resolver.call(base_id)
        target_proj = resolver.call(target_id)

        from = opts[:from]&.to_i
        to = opts[:to]&.to_i

        base_result = run_forecast(base_proj, base_id, from, to)
        target_result = run_forecast(target_proj, target_id, from, to)

        deltas = compute_deltas(base_result.summary, target_result.summary)
        data = {
          "base" => { "scenario_id" => base_id, "summary" => base_result.summary.to_h },
          "target" => { "scenario_id" => target_id, "summary" => target_result.summary.to_h },
          "deltas" => deltas,
        }
        text = compare_text(base_id, target_id, deltas)
        payload(data: data, text: text)
      end

      private

      def run_forecast(project, scenario_id, from, to)
        Lifeplan::Forecast::Engine.new(project, scenario_id: scenario_id, from: from, to: to).call
      end

      def compute_deltas(base, target)
        base.to_h.each_with_object({}) do |(key, base_val), h|
          target_val = target.to_h[key]
          h[key] = if base_val.is_a?(Numeric) && target_val.is_a?(Numeric)
            target_val - base_val
          else
            { "base" => base_val, "target" => target_val }
          end
        end
      end

      def compare_text(base_id, target_id, deltas)
        lines = ["Comparison: #{base_id} vs #{target_id}"]
        deltas.each { |k, v| lines << "  #{k}: #{v.inspect}" }
        lines.join("\n")
      end
    end
  end
end
