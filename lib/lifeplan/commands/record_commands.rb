# frozen_string_literal: true

require "lifeplan/commands/helpers"

module Lifeplan
  module Commands
    module RecordCommands
      include Helpers

      def schema_payload(type)
        if type.nil?
          return payload(
            data: { "record_types" => Lifeplan::Schema.types },
            text: "Record types:\n  #{Lifeplan::Schema.types.join("\n  ")}",
          )
        end

        canonical = Lifeplan::Schema.canonical(type)
        fields = Lifeplan::Schema.fields_for(type)
        payload(
          data: {
            "type" => canonical,
            "fields" => fields.map { |f| f.to_h.transform_keys(&:to_s) },
          },
          text: format_schema_text(canonical, fields),
        )
      end

      def list_payload(type, opts)
        project = load_project
        canonical = Lifeplan::Schema.canonical(type)
        items = project.collection(canonical).map { |r| stringify_hash(r.to_h) }
        items = filter_items(items, opts)
        payload(
          data: { "type" => canonical, "items" => items },
          text: format_list_text(canonical, items),
        )
      end

      def get_payload(type, id)
        project = load_project
        record = project.find(type, id)
        data = stringify_hash(record.to_h)
        payload(
          data: { "type" => Lifeplan::Schema.canonical(type), "record" => data },
          text: data.map { |k, v| "#{k}: #{v.inspect}" }.join("\n"),
        )
      end

      private

      def filter_items(items, opts)
        items = items.select { |i| i["category"].to_s == opts[:category] } if opts[:category]
        items = items.select { |i| (i["to"] || i["year"] || 999_999) >= opts[:from] } if opts[:from]
        items = items.select { |i| (i["from"] || i["year"] || 0) <= opts[:to] } if opts[:to]
        items
      end

      def format_schema_text(type, fields)
        lines = ["Schema: #{type}"]
        fields.each do |f|
          mark = f.required ? "*" : " "
          allowed = f.allowed ? " [#{f.allowed.join("|")}]" : ""
          lines << "  #{mark} #{f.name}: #{f.type}#{allowed} - #{f.description}"
        end
        lines.join("\n")
      end

      def format_list_text(type, items)
        return "No #{type} records." if items.empty?

        lines = ["#{Lifeplan::Schema.plural(type).capitalize}:"]
        items.each do |i|
          line = +"  #{i["id"]}\t#{i["name"]}"
          line << "\t#{i["amount"]}" if i["amount"]
          if i["from"] || i["year"]
            line << "\t#{i["from"] || i["year"]}-#{i["to"] || i["year"]}"
          end
          lines << line
        end
        lines.join("\n")
      end

      def stringify_hash(hash)
        hash.transform_keys(&:to_s)
      end
    end
  end
end
