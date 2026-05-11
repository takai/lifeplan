# frozen_string_literal: true

require "lifeplan/commands/helpers"
require "lifeplan/coercion"
require "lifeplan/records"

module Lifeplan
  module Commands
    module MutationCommands
      include Helpers

      ADD_OPTIONS = [
        "id",
        "name",
        "description",
        "category",
        "notes",
        "source",
        "unit",
        "tags",
        "base",
        "amount",
        "principal",
        "currency",
        "frequency",
        "growth",
        "return",
        "rate",
        "payment",
        "years",
        "value",
        "from",
        "to",
        "year",
        "as-of",
        "person-id",
        "from-asset",
        "to-asset",
        "secured-by-asset-id",
        "primary-person-id",
        "impact-type",
        "target-asset-id",
        "proceeds",
        "proceeds-to-asset",
        "costs",
        "household-type",
        "relationship",
        "tax-treatment",
        "birth-year",
        "birth-date",
        "current-age",
        "retirement-age",
        "liquid",
        "dependent",
        "essential",
      ].freeze

      def add_payload(type, opts)
        canonical = Lifeplan::Schema.canonical(type)
        attrs = collect_attrs(canonical, opts)
        require_field(canonical, attrs, :id)
        require_field(canonical, attrs, :name)

        project = load_project
        ensure_unique_id(project, canonical, attrs[:id])

        klass = Lifeplan::Records.class_for(canonical)
        record = klass.from_hash(stringify_keys(attrs))

        unless dry_run?(opts)
          collection = project.collection(canonical)
          collection << record
          project.save
        end

        payload(
          data: action_data("add", canonical, record, opts),
          text: action_text("add", canonical, record, opts),
        )
      end

      def set_payload(type, id, field, value, opts)
        canonical = Lifeplan::Schema.canonical(type)
        project = load_project
        record = project.find(canonical, id)
        before = record.public_send(field.to_sym)
        coerced = Lifeplan::Coercion.coerce_field(canonical, field, value)

        updated = record.with(field.to_sym => coerced)
        unless dry_run?(opts)
          replace_record(project, canonical, id, updated)
          project.save
        end

        payload(
          data: {
            "action" => "set",
            "type" => canonical,
            "id" => id,
            "field" => field,
            "before" => before,
            "after" => coerced,
            "applied" => !dry_run?(opts),
          },
          text: "#{canonical} #{id}.#{field}: #{before.inspect} -> #{coerced.inspect}" \
            "#{dry_run?(opts) ? " (dry-run)" : ""}",
        )
      end

      def remove_payload(type, id, opts)
        canonical = Lifeplan::Schema.canonical(type)
        project = load_project
        record = project.find(canonical, id)

        unless dry_run?(opts)
          project.collection(canonical).reject! { |r| r.id == id }
          project.save
        end

        payload(
          data: {
            "action" => "remove",
            "type" => canonical,
            "id" => id,
            "removed" => stringify_keys_hash(record.to_h),
            "applied" => !dry_run?(opts),
          },
          text: "Removed #{canonical} #{id}#{dry_run?(opts) ? " (dry-run)" : ""}",
        )
      end

      private

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

      def require_field(type, attrs, name)
        return if attrs[name]

        raise InvalidArguments, "--#{name.to_s.tr("_", "-")} is required for #{type}"
      end

      def ensure_unique_id(project, type, id)
        return unless Lifeplan::Project::COLLECTIONS.value?(type)
        return unless project.collection(type).any? { |r| r.id == id }

        raise InvalidArguments, "#{type} '#{id}' already exists"
      end

      def replace_record(project, type, id, record)
        collection = project.collection(type)
        idx = collection.find_index { |r| r.id == id }
        collection[idx] = record
      end

      def dry_run?(opts)
        opts[:"dry-run"] || opts["dry-run"] || opts[:dry_run]
      end

      def action_data(action, type, record, opts)
        {
          "action" => action,
          "type" => type,
          "record" => stringify_keys_hash(record.to_h),
          "applied" => !dry_run?(opts),
        }
      end

      def action_text(action, type, record, opts)
        suffix = dry_run?(opts) ? " (dry-run)" : ""
        "#{action.capitalize}ed #{type} '#{record.id}'#{suffix}"
      end

      def stringify_keys(hash)
        hash.transform_keys(&:to_s)
      end

      def stringify_keys_hash(hash)
        hash.transform_keys(&:to_s)
      end
    end
  end
end
