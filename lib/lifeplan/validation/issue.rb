# frozen_string_literal: true

module Lifeplan
  module Validation
    Issue = Data.define(
      :severity, :code, :message, :record_type, :record_id, :path, :suggested_fix
    ) do
      class << self
        def error(code, message, **opts)
          new(
            severity: "error",
            code: code,
            message: message,
            record_type: opts[:record_type],
            record_id: opts[:record_id],
            path: opts[:path],
            suggested_fix: opts[:suggested_fix],
          )
        end

        def warning(code, message, **opts)
          new(
            severity: "warning",
            code: code,
            message: message,
            record_type: opts[:record_type],
            record_id: opts[:record_id],
            path: opts[:path],
            suggested_fix: opts[:suggested_fix],
          )
        end
      end

      def to_h
        {
          "severity" => severity,
          "code" => code,
          "message" => message,
          "record_type" => record_type,
          "record_id" => record_id,
          "path" => path,
          "suggested_fix" => suggested_fix,
        }.compact
      end

      def error?
        severity == "error"
      end

      def warning?
        severity == "warning"
      end
    end
  end
end
