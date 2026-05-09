# frozen_string_literal: true

require "lifeplan/records"
require "lifeplan/coercion"
require "lifeplan/validation/validator"
require "lifeplan/scenarios/resolver"

module Lifeplan
  module Proposals
    module Applier
      extend self

      STATUS_PENDING = "pending"
      STATUS_APPLIED = "applied"
      STATUS_DISCARDED = "discarded"
      STATUS_STALE = "stale"

      def apply!(project, proposal, force: false, dry_run: false)
        raise Lifeplan::ChangeNotApplied, "proposal '#{proposal["id"]}' is not pending (status=#{proposal["status"]})" unless proposal["status"] == STATUS_PENDING

        change = proposal.fetch("changes").first
        before = capture_before(project, change)
        if !force && stale?(change, before)
          mark!(project, proposal, STATUS_STALE)
          raise Lifeplan::ChangeNotApplied, "proposal '#{proposal["id"]}' is stale (#{change["path"] || change["record_id"]} changed)"
        end

        preview = Lifeplan::Scenarios::Resolver.new(project).call("base")
        mutate(preview, change)
        issues = Lifeplan::Validation::Validator.new.call(preview)
        errors = issues.select(&:error?)
        unless errors.empty? || force
          raise Lifeplan::ChangeNotApplied,
            "applying proposal '#{proposal["id"]}' would produce errors: #{errors.map(&:code).join(", ")}"
        end

        unless dry_run
          mutate(project, change)
          mark!(project, proposal, STATUS_APPLIED)
        end

        { "before" => before, "after" => change["after"], "issues" => issues.map(&:to_h) }
      end

      def mutate(project, change)
        type = Lifeplan::Schema.canonical(change["record_type"])
        case change["op"]
        when "add" then add_record(project, type, change["after"])
        when "set" then set_field(project, type, change["record_id"], change["path"], change["after"])
        when "remove" then remove_record(project, type, change["record_id"])
        else
          raise Lifeplan::InvalidArguments, "unsupported proposal op '#{change["op"]}'"
        end
      end

      def capture_before(project, change)
        type = Lifeplan::Schema.canonical(change["record_type"])
        case change["op"]
        when "add" then nil
        when "set"
          record = project.collection(type).find { |r| r.id == change["record_id"] }
          record&.public_send(change["path"].to_sym)
        when "remove"
          record = project.collection(type).find { |r| r.id == change["record_id"] }
          record&.to_h&.transform_keys(&:to_s)
        end
      end

      def stale?(change, current_before)
        return false unless change.key?("before")

        change["before"] != current_before
      end

      def mark!(project, proposal, status)
        idx = project.proposals.find_index { |p| p["id"] == proposal["id"] }
        return unless idx

        updated = proposal.merge("status" => status)
        updated["applied_at"] = Time.now.utc.iso8601 if status == STATUS_APPLIED
        project.proposals[idx] = updated
        proposal.replace(updated) if proposal.is_a?(Hash)
      end

      private

      def add_record(project, type, attrs)
        klass = Lifeplan::Records.class_for(type)
        record = klass.from_hash(attrs.transform_keys(&:to_s))
        project.collection(type) << record
      end

      def set_field(project, type, id, path, value)
        collection = project.collection(type)
        idx = collection.find_index { |r| r.id == id }
        raise Lifeplan::RecordNotFound, "#{type} '#{id}' not found" unless idx

        coerced = Lifeplan::Coercion.coerce_field(type, path, value)
        collection[idx] = collection[idx].with(path.to_sym => coerced)
      end

      def remove_record(project, type, id)
        collection = project.collection(type)
        raise Lifeplan::RecordNotFound, "#{type} '#{id}' not found" unless collection.any? { |r| r.id == id }

        collection.reject! { |r| r.id == id }
      end
    end
  end
end
