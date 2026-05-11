# frozen_string_literal: true

require "date"
require "json"
require "lifeplan/errors"
require "lifeplan/schema"

module Lifeplan
  module Coercion
    TRUE_VALUES = ["true", "yes", "y", "1"].freeze
    FALSE_VALUES = ["false", "no", "n", "0"].freeze

    class << self
      def coerce_field(type, field_name, raw)
        return if raw.nil?

        field = lookup_field(type, field_name)
        coerce_value(field.type, raw, field_name)
      end

      def coerce_value(field_type, raw, field_name = nil)
        case field_type
        when :string, :currency_code, :date
          coerce_string(field_type, raw, field_name)
        when :integer, :year
          coerce_integer(raw, field_name)
        when :decimal
          coerce_decimal(raw, field_name)
        when :boolean
          coerce_boolean(raw, field_name)
        when :growth
          coerce_growth(raw)
        when :array
          coerce_array(raw)
        when :any
          coerce_any(raw)
        else
          raw
        end
      end

      def lookup_field(type, field_name)
        Schema.fields_for(type).find { |f| f.name.to_s == field_name.to_s } ||
          raise(InvalidArguments, "Unknown field '#{field_name}' for #{Schema.canonical(type)}")
      end

      private

      def coerce_string(field_type, raw, field_name)
        if field_type == :date
          parse_date(raw, field_name)
        else
          raw.to_s
        end
      end

      def parse_date(raw, field_name)
        Date.iso8601(raw.to_s).to_s
      rescue ArgumentError
        raise InvalidArguments, "Invalid date for '#{field_name}': #{raw}"
      end

      def coerce_integer(raw, field_name)
        return raw if raw.is_a?(Integer)

        Integer(raw.to_s, 10)
      rescue ArgumentError, TypeError
        raise InvalidArguments, "Expected integer for '#{field_name}', got #{raw.inspect}"
      end

      def coerce_decimal(raw, field_name)
        return raw if raw.is_a?(Float) || raw.is_a?(Integer)

        Float(raw.to_s)
      rescue ArgumentError, TypeError
        raise InvalidArguments, "Expected decimal for '#{field_name}', got #{raw.inspect}"
      end

      def coerce_boolean(raw, field_name)
        return raw if [true, false].include?(raw)

        str = raw.to_s.downcase
        return true if TRUE_VALUES.include?(str)
        return false if FALSE_VALUES.include?(str)

        raise InvalidArguments, "Expected boolean for '#{field_name}', got #{raw.inspect}"
      end

      def coerce_growth(raw)
        return raw if raw.is_a?(Numeric)

        str = raw.to_s
        Float(str)
      rescue ArgumentError
        str
      end

      def coerce_array(raw)
        return raw if raw.is_a?(Array)

        str = raw.to_s.strip
        if str.start_with?("[")
          parsed = JSON.parse(str)
          return parsed if parsed.is_a?(Array)
        end
        str.split(",").map(&:strip).reject(&:empty?)
      rescue JSON::ParserError
        raise InvalidArguments, "Expected JSON array, got #{raw.inspect}"
      end

      def coerce_any(raw)
        return raw unless raw.is_a?(String)

        return Float(raw) if raw.match?(/\A-?\d+\.\d+\z/)
        return Integer(raw, 10) if raw.match?(/\A-?\d+\z/)

        stripped = raw.strip
        if stripped.start_with?("{", "[")
          begin
            return JSON.parse(stripped)
          rescue JSON::ParserError
            # fall through and return raw
          end
        end

        raw
      end
    end
  end
end
