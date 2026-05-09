# frozen_string_literal: true

require "lifeplan/validation/issue"

module Lifeplan
  module Validation
    module Rules
      module Period
        extend self

        def call(project)
          issues = []
          start_year = project.start_year
          end_year = project.end_year

          [:incomes, :expenses, :events].each do |coll|
            project.public_send(coll).each do |record|
              type = Lifeplan::Project::COLLECTIONS[coll.to_s]
              issues.concat(check_record(type, record, start_year, end_year))
            end
          end

          project.liabilities.each do |l|
            issues.concat(check_period(l, "liability", start_year, end_year))
          end

          issues
        end

        def check_record(type, record, start_year, end_year)
          issues = check_period(record, type, start_year, end_year)

          if record.respond_to?(:year) && record.year && start_year && end_year &&
              !(start_year..end_year).cover?(record.year)
            issues << Issue.warning(
              "PERIOD_OUT_OF_RANGE",
              "#{type} '#{record.id}' year #{record.year} is outside project period " \
                "#{start_year}-#{end_year}.",
              record_type: type,
              record_id: record.id,
              path: "year",
            )
          end
          issues
        end

        def check_period(record, type, start_year, end_year)
          issues = []
          from = record.respond_to?(:from) ? record.from : nil
          to = record.respond_to?(:to) ? record.to : nil

          if from && to && from > to
            issues << Issue.error(
              "INVALID_PERIOD",
              "#{type} '#{record.id}' has from #{from} after to #{to}.",
              record_type: type,
              record_id: record.id,
              path: "from",
            )
          end

          if start_year && end_year
            if from && from > end_year
              issues << Issue.warning(
                "PERIOD_OUT_OF_RANGE",
                "#{type} '#{record.id}' starts at #{from}, after project end #{end_year}.",
                record_type: type,
                record_id: record.id,
                path: "from",
              )
            end
            if to && to < start_year
              issues << Issue.warning(
                "PERIOD_OUT_OF_RANGE",
                "#{type} '#{record.id}' ends at #{to}, before project start #{start_year}.",
                record_type: type,
                record_id: record.id,
                path: "to",
              )
            end
          end
          issues
        end
      end
    end
  end
end
