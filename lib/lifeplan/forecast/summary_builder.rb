# frozen_string_literal: true

require "lifeplan/forecast/result"

module Lifeplan
  module Forecast
    module SummaryBuilder
      extend self

      def call(rows, project)
        return empty_summary if rows.empty?

        min_row = rows.min_by(&:asset_balance)
        first_negative = rows.find { |r| r.asset_balance.negative? }
        retirement_year = compute_retirement_year(project)
        retirement_row = rows.find { |r| r.year == retirement_year } if retirement_year

        Summary.new(
          minimum_asset_balance: min_row.asset_balance,
          minimum_asset_balance_year: min_row.year,
          first_negative_asset_year: first_negative&.year,
          asset_at_retirement: retirement_row&.asset_balance,
          retirement_year: retirement_year,
          total_income: rows.sum(&:income),
          total_expense: rows.sum(&:expense),
          final_asset_balance: rows.last.asset_balance,
        )
      end

      private

      def compute_retirement_year(project)
        primary = primary_person(project)
        return unless primary&.birth_year && primary.retirement_age

        primary.birth_year + primary.retirement_age
      end

      def primary_person(project)
        profile = project.profile
        return unless profile&.people&.any?

        profile.people.find { |p| p.id == profile.primary_person_id } || profile.people.first
      end

      def empty_summary
        Summary.new(
          minimum_asset_balance: 0,
          minimum_asset_balance_year: nil,
          first_negative_asset_year: nil,
          asset_at_retirement: nil,
          retirement_year: nil,
          total_income: 0,
          total_expense: 0,
          final_asset_balance: 0,
        )
      end
    end
  end
end
