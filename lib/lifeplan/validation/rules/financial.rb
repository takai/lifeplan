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
          issues.concat(check_expense_transitions(project))
          issues
        end

        def check_expense_transitions(project)
          issues = []
          project.expenses.each do |expense|
            transitions = expense.transitions
            next if transitions.nil? || transitions.empty?

            unless transitions.is_a?(Array)
              issues << Issue.error(
                "INVALID_TRANSITIONS",
                "expense '#{expense.id}' transitions must be an array.",
                record_type: "expense",
                record_id: expense.id,
                path: "transitions",
              )
              next
            end

            prior_year = nil
            transitions.each_with_index do |transition, index|
              issues.concat(check_transition(expense, transition, index, prior_year))
              year = transition.is_a?(Hash) ? (transition["year"] || transition[:year]) : nil
              prior_year = year if year
            end
          end
          issues
        end

        def check_transition(expense, transition, index, prior_year)
          issues = []
          unless transition.is_a?(Hash)
            return [Issue.error(
              "INVALID_TRANSITIONS",
              "expense '#{expense.id}' transition ##{index} must be an object.",
              record_type: "expense",
              record_id: expense.id,
              path: "transitions[#{index}]",
            )]
          end

          year = transition["year"] || transition[:year]
          amount = transition["amount"] || transition[:amount]

          if year.nil?
            issues << Issue.error(
              "INVALID_TRANSITIONS",
              "expense '#{expense.id}' transition ##{index} is missing 'year'.",
              record_type: "expense",
              record_id: expense.id,
              path: "transitions[#{index}].year",
            )
          end

          if amount.is_a?(Numeric) && amount.negative?
            issues << Issue.error(
              "NEGATIVE_AMOUNT",
              "expense '#{expense.id}' transition ##{index} amount must be non-negative (got #{amount}).",
              record_type: "expense",
              record_id: expense.id,
              path: "transitions[#{index}].amount",
            )
          end

          if year && expense.from && year < expense.from
            issues << Issue.warning(
              "TRANSITION_OUT_OF_RANGE",
              "expense '#{expense.id}' transition ##{index} year #{year} is before from #{expense.from}.",
              record_type: "expense",
              record_id: expense.id,
              path: "transitions[#{index}].year",
            )
          end

          if year && expense.to && year > expense.to
            issues << Issue.warning(
              "TRANSITION_OUT_OF_RANGE",
              "expense '#{expense.id}' transition ##{index} year #{year} is after to #{expense.to}.",
              record_type: "expense",
              record_id: expense.id,
              path: "transitions[#{index}].year",
            )
          end

          if year && prior_year && year <= prior_year
            issues << Issue.error(
              "TRANSITIONS_NOT_SORTED",
              "expense '#{expense.id}' transition ##{index} year #{year} is not after previous #{prior_year}.",
              record_type: "expense",
              record_id: expense.id,
              path: "transitions[#{index}].year",
            )
          end

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
