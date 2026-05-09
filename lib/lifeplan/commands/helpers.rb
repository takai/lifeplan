# frozen_string_literal: true

require "lifeplan/errors"
require "lifeplan/formatters/registry"
require "lifeplan/formatters/payload"
require "lifeplan/project"
require "lifeplan/schema"

module Lifeplan
  module Commands
    module Helpers
      def project_path
        options[:project] || Dir.pwd
      end

      def load_project
        Lifeplan::Project.load(project_path)
      end

      def render(payload)
        Formatters::Registry.render(payload, format: options[:format])
      end

      def payload(data:, text: nil, markdown: nil, csv: nil, metadata: {})
        Formatters::Payload.new(
          data: data, text: text, markdown: markdown, csv: csv, metadata: metadata,
        )
      end
    end
  end
end
