# frozen_string_literal: true

require "json"

module Lifeplan
  module Formatters
    module Registry
      extend self

      def render(payload, format: "text", io: $stdout)
        format = (format || "text").to_s
        case format
        when "json"
          io.puts(JSON.pretty_generate(json_envelope(payload)))
        when "text"
          io.puts(payload.respond_to?(:text) ? payload.text : payload.to_s)
        when "csv"
          io.puts(payload.respond_to?(:csv) ? payload.csv : "")
        when "markdown"
          io.puts(payload.respond_to?(:markdown) ? payload.markdown : payload.to_s)
        else
          raise InvalidArguments, "Unknown format: #{format}"
        end
      end

      def json_envelope(payload)
        if payload.respond_to?(:json_envelope)
          payload.json_envelope
        else
          {
            "data" => payload.respond_to?(:data) ? payload.data : payload,
            "warnings" => payload.respond_to?(:warnings) ? payload.warnings : [],
            "errors" => payload.respond_to?(:errors) ? payload.errors : [],
            "metadata" => payload.respond_to?(:metadata) ? payload.metadata : {},
          }
        end
      end
    end
  end
end
