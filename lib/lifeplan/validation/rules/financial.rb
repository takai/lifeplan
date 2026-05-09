# frozen_string_literal: true

require "lifeplan/validation/issue"

module Lifeplan
  module Validation
    module Rules
      module Financial
        extend self

        def call(project)
          issues = []
          issues.concat(check_non_negative(project))
          issues.concat(check_asset_as_of(project))
          issues.concat(check_liability_repayment(project))
          issues
        end

        def check_non_negative(project)
          issues = []
          [
            [:incomes, "income", :amount],
            [:expenses, "expense", :amount],
            [:assets, "asset", :amount],
            [:events, "event", :amount],
            [:liabilities, "liability", :principal],
          ].each do |coll, type, field|
            project.public_send(coll).each do |r|
              value = r.public_send(field)
              next if value.nil? || value >= 0

              issues << Issue.error(
                "NEGATIVE_AMOUNT",
                "#{type} '#{r.id}' #{field} must be non-negative (got #{value}).",
                record_type: type,
                record_id: r.id,
                path: field.to_s,
              )
            end
          end
          issues
        end

        def check_asset_as_of(project)
          project.assets.reject(&:as_of).map do |a|
            Issue.error(
              "ASSET_MISSING_AS_OF",
              "asset '#{a.id}' is missing valuation date (as_of).",
              record_type: "asset",
              record_id: a.id,
              path: "as_of",
            )
          end
        end

        def check_liability_repayment(project)
          project.liabilities.reject do |l|
            l.payment || l.years || l.to
          end.map do |l|
            Issue.warning(
              "LIABILITY_MISSING_REPAYMENT",
              "liability '#{l.id}' has no repayment definition (payment/years/to).",
              record_type: "liability",
              record_id: l.id,
              path: "payment",
            )
          end
        end
      end
    end
  end
end
