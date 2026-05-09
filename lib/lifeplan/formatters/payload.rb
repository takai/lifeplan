# frozen_string_literal: true

module Lifeplan
  module Formatters
    class Payload
      attr_reader :data, :warnings, :errors, :metadata

      def initialize(data:, text: nil, markdown: nil, csv: nil, warnings: [], errors: [], metadata: {})
        @data = data
        @text = text
        @markdown = markdown
        @csv = csv
        @warnings = warnings
        @errors = errors
        @metadata = metadata
      end

      def text
        @text || data.to_s
      end

      def markdown
        @markdown || text
      end

      def csv
        @csv || ""
      end

      def json_envelope
        {
          "data" => data,
          "warnings" => warnings,
          "errors" => errors,
          "metadata" => metadata,
        }
      end
    end
  end
end
