# frozen_string_literal: true

require "lifeplan/schema"

module Lifeplan
  module Scenarios
    Path = Data.define(:type, :id, :field) do
      class << self
        def parse(raw)
          parts = raw.to_s.split(".")
          raise Lifeplan::InvalidArguments, "scenario path must be '<type>.<id>[.field]'" if parts.size < 2

          type = Lifeplan::Schema.canonical(parts[0])
          unless Lifeplan::Schema.types.include?(type)
            raise Lifeplan::InvalidArguments, "unknown record type '#{parts[0]}' in path '#{raw}'"
          end

          field = parts[2..]&.join(".")
          field = nil if field == ""
          new(type: type, id: parts[1], field: field)
        end
      end
    end
  end
end
