# frozen_string_literal: true

require "lifeplan/schema"

module Lifeplan
  module Records
    module Base
      module ClassMethods
        attr_reader :fields, :type_name

        def from_hash(hash)
          attrs = {}
          hash = stringify_keys(hash)
          fields.each do |f|
            attrs[f.name] = hash[f.name.to_s]
          end
          new(**attrs)
        end

        def stringify_keys(hash)
          hash.transform_keys(&:to_s)
        end
      end

      def to_h
        result = {}
        self.class.fields.each do |f|
          value = public_send(f.name)
          next if value.nil?

          result[f.name] = serialize_value(value)
        end
        result
      end

      def serialize_value(value)
        case value
        when Array
          value.map { |v| v.respond_to?(:to_h) && !v.is_a?(Hash) ? v.to_h : v }
        when Hash
          value
        else
          if value.respond_to?(:to_h) && !value.is_a?(Numeric) && !value.is_a?(String) &&
              !value.is_a?(TrueClass) && !value.is_a?(FalseClass)
            value.to_h
          else
            value
          end
        end
      end

      class << self
        def define(type_name, fields)
          members = fields.map(&:name)
          klass = Class.new(Data.define(*members))
          klass.include(self)
          klass.extend(ClassMethods)
          klass.instance_variable_set(:@fields, fields)
          klass.instance_variable_set(:@type_name, type_name)
          klass
        end
      end
    end
  end
end
