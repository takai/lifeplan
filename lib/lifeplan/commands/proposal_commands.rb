# frozen_string_literal: true

require "securerandom"
require "time"
require "lifeplan/commands/helpers"
require "lifeplan/coercion"
require "lifeplan/records"
require "lifeplan/proposals/applier"
require "lifeplan/validation/validator"
require "lifeplan/scenarios/resolver"

module Lifeplan
  module Commands
    module ProposalCommands
      include Helpers

      def propose_payload(action, type, args, opts)
        canonical = Lifeplan::Schema.canonical(type)
        project = load_project
        change = build_change(action, canonical, args, opts, project)
        proposal = build_proposal(action, canonical, change, opts)

        preview = Lifeplan::Scenarios::Resolver.new(project).call("base")
        Lifeplan::Proposals::Applier.mutate(preview, change)
        issues = Lifeplan::Validation::Validator.new.call(preview).map(&:to_h)

        proposal["validation"] = issues
        project.proposals << proposal
        project.save
        payload(
          data: proposal,
          text: "Proposal #{proposal["id"]} (#{action} #{canonical}) created. Validation: #{issues.size} issue(s).",
        )
      end

      def proposals_payload(_opts)
        project = load_project
        rows = project.proposals.map { |p| proposal_summary(p) }
        text = rows.empty? ? "(no proposals)" : rows.map { |r| "#{r["id"]}\t#{r["status"]}\t#{r["summary"]}" }.join("\n")
        payload(data: rows, text: text)
      end

      def apply_payload(id, opts)
        project = load_project
        proposal = find_proposal!(project, id)
        result = Lifeplan::Proposals::Applier.apply!(
          project, proposal, force: opts[:force], dry_run: opts[:"dry-run"]
        )
        project.save unless opts[:"dry-run"]
        payload(
          data: { "proposal" => proposal, "result" => result, "applied" => !opts[:"dry-run"] },
          text: opts[:"dry-run"] ? "Proposal #{id} preview ok (not applied)" : "Applied proposal #{id}",
        )
      end

      def discard_payload(id, _opts)
        project = load_project
        proposal = find_proposal!(project, id)
        Lifeplan::Proposals::Applier.mark!(project, proposal, Lifeplan::Proposals::Applier::STATUS_DISCARDED)
        project.save
        payload(data: { "discarded" => id }, text: "Discarded proposal #{id}")
      end

      def diff_payload(opts)
        project = load_project
        if opts[:proposal]
          proposal = find_proposal!(project, opts[:proposal])
          change = proposal["changes"].first
          before = Lifeplan::Proposals::Applier.capture_before(project, change)
          payload(
            data: { "proposal_id" => proposal["id"], "change" => change, "current_before" => before },
            text: "Proposal #{proposal["id"]}: #{change["op"]} #{change["record_type"]} #{change["record_id"]}\n" \
              "before: #{before.inspect}\nafter: #{change["after"].inspect}",
          )
        elsif opts[:scenario]
          payload(
            data: { "scenario" => opts[:scenario], "note" => "scenario diff via compare command" },
            text: "Use `lifeplan compare base #{opts[:scenario]}` for scenario diffs.",
          )
        else
          raise Lifeplan::InvalidArguments, "diff requires --proposal <id> or --scenario <id>"
        end
      end

      private

      def build_change(action, type, args, opts, project)
        case action
        when "add" then build_add_change(type, opts)
        when "set" then build_set_change(type, args, opts, project)
        when "remove" then build_remove_change(type, args)
        else
          raise Lifeplan::InvalidArguments, "unsupported propose action '#{action}'"
        end
      end

      def build_add_change(type, opts)
        attrs = collect_attrs(type, opts)
        require_field!(type, attrs, :id)
        require_field!(type, attrs, :name)
        {
          "op" => "add",
          "record_type" => type,
          "record_id" => attrs[:id].to_s,
          "after" => attrs.transform_keys(&:to_s),
        }
      end

      def build_set_change(type, args, _opts, project)
        id, field, value = args
        raise Lifeplan::InvalidArguments, "set requires <id> <field> <value>" unless id && field && value

        record = project.collection(type).find { |r| r.id == id }
        before = record&.public_send(field.to_sym)
        coerced = Lifeplan::Coercion.coerce_field(type, field, value)
        {
          "op" => "set",
          "record_type" => type,
          "record_id" => id,
          "path" => field,
          "before" => before,
          "after" => coerced,
        }
      end

      def build_remove_change(type, args)
        id = args.first
        raise Lifeplan::InvalidArguments, "remove requires <id>" unless id

        { "op" => "remove", "record_type" => type, "record_id" => id }
      end

      def collect_attrs(type, opts)
        attrs = {}
        Lifeplan::Schema.fields_for(type).each do |field|
          opt_key = field.name.to_s.tr("_", "-")
          raw = opts[opt_key] || opts[field.name.to_s]
          next if raw.nil?

          attrs[field.name] = Lifeplan::Coercion.coerce_value(field.type, raw, field.name)
        end
        attrs
      end

      def require_field!(type, attrs, name)
        return if attrs[name]

        raise Lifeplan::InvalidArguments, "--#{name.to_s.tr("_", "-")} is required for #{type}"
      end

      def build_proposal(action, type, change, opts)
        id = opts[:id] || "proposal_#{SecureRandom.hex(4)}"
        {
          "id" => id,
          "summary" => opts[:summary] || "#{action} #{type} #{change["record_id"]}",
          "status" => "pending",
          "changes" => [change],
          "created_at" => Time.now.utc.iso8601,
        }
      end

      def proposal_summary(proposal)
        {
          "id" => proposal["id"],
          "status" => proposal["status"],
          "summary" => proposal["summary"],
        }
      end

      def find_proposal!(project, id)
        project.proposals.find { |p| p["id"] == id } ||
          raise(Lifeplan::ChangeNotApplied, "proposal '#{id}' not found")
      end
    end
  end
end
