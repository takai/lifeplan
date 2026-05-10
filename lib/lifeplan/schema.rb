# frozen_string_literal: true

require "lifeplan/errors"

module Lifeplan
  module Schema
    Field = Data.define(:name, :type, :required, :description, :allowed) do
      def to_h
        result = { name: name, type: type, required: required, description: description }
        result[:allowed] = allowed if allowed
        result
      end
    end

    class << self
      def field(name, type, required: false, description: nil, allowed: nil)
        Field.new(
          name: name, type: type, required: required, description: description, allowed: allowed,
        )
      end

      def fields_for(type)
        BY_TYPE.fetch(canonical(type)) do
          raise InvalidArguments, "Unknown record type: #{type}"
        end
      end

      def canonical(type)
        key = type.to_s
        PLURAL_TO_SINGULAR.fetch(key, key)
      end

      def plural(type)
        SINGULAR_TO_PLURAL.fetch(canonical(type))
      end

      def types
        BY_TYPE.keys
      end
    end

    PROFILE = [
      field(:id, :string, required: true, description: "Profile ID"),
      field(:name, :string, required: true, description: "Profile name"),
      field(:people, :array, required: true, description: "People in the plan"),
      field(:primary_person_id, :string, description: "Main person ID"),
      field(
        :household_type,
        :string,
        description: "Household type",
        allowed: ["single", "couple", "family", "retirement", "other"],
      ),
      field(:notes, :string, description: "Notes"),
    ].freeze

    PERSON = [
      field(:id, :string, required: true, description: "Person ID"),
      field(:name, :string, required: true, description: "Person name"),
      field(
        :relationship,
        :string,
        required: true,
        description: "Relationship to primary",
        allowed: ["self", "spouse", "child", "parent", "other"],
      ),
      field(:birth_year, :year, description: "Birth year"),
      field(:birth_date, :date, description: "Birth date"),
      field(:current_age, :integer, description: "Current age if birth year unknown"),
      field(:retirement_age, :integer, description: "Planned retirement age"),
      field(:dependent, :boolean, description: "Dependent flag"),
    ].freeze

    INCOME = [
      field(:id, :string, required: true, description: "Income ID"),
      field(:name, :string, required: true, description: "Income name"),
      field(:amount, :integer, required: true, description: "Amount per frequency"),
      field(:currency, :currency_code, description: "Currency"),
      field(
        :frequency,
        :string,
        required: true,
        description: "Frequency",
        allowed: ["once", "monthly", "yearly"],
      ),
      field(:from, :year, description: "Start year"),
      field(:to, :year, description: "End year"),
      field(:year, :year, description: "One-time income year"),
      field(:growth, :growth, description: "Annual growth rule"),
      field(:category, :string, description: "Income category"),
      field(:person_id, :string, description: "Related person"),
      field(:tax_treatment, :string, description: "Tax handling label"),
      field(:contribute_to, :string, description: "Asset id that receives this income (no cashflow effect)"),
      field(:notes, :string, description: "Notes"),
    ].freeze

    EXPENSE = [
      field(:id, :string, required: true, description: "Expense ID"),
      field(:name, :string, required: true, description: "Expense name"),
      field(:amount, :integer, required: true, description: "Amount per frequency"),
      field(:currency, :currency_code, description: "Currency"),
      field(
        :frequency,
        :string,
        required: true,
        description: "Frequency",
        allowed: ["once", "monthly", "yearly"],
      ),
      field(:from, :year, description: "Start year"),
      field(:to, :year, description: "End year"),
      field(:year, :year, description: "One-time expense year"),
      field(:growth, :growth, description: "Annual growth rule"),
      field(:category, :string, description: "Expense category"),
      field(:person_id, :string, description: "Related person"),
      field(:essential, :boolean, description: "Essential flag"),
      field(:contribute_to, :string, description: "Asset id that this expense funds (e.g. NISA, iDeCo)"),
      field(:transitions, :array, description: "Lifestage transitions overriding amount/growth"),
      field(:notes, :string, description: "Notes"),
    ].freeze

    ASSET = [
      field(:id, :string, required: true, description: "Asset ID"),
      field(:name, :string, required: true, description: "Asset name"),
      field(:amount, :integer, required: true, description: "Current value"),
      field(:currency, :currency_code, description: "Currency"),
      field(:as_of, :date, required: true, description: "Valuation date"),
      field(:category, :string, description: "Asset category"),
      field(:return, :growth, description: "Expected annual return"),
      field(:liquid, :boolean, description: "Liquid flag"),
      field(:person_id, :string, description: "Owner or related person"),
      field(:notes, :string, description: "Notes"),
    ].freeze

    LIABILITY = [
      field(:id, :string, required: true, description: "Liability ID"),
      field(:name, :string, required: true, description: "Liability name"),
      field(:principal, :integer, required: true, description: "Outstanding principal"),
      field(:currency, :currency_code, description: "Currency"),
      field(:rate, :decimal, description: "Annual interest rate"),
      field(:from, :year, description: "Repayment start year"),
      field(:to, :year, description: "Repayment end year"),
      field(:years, :integer, description: "Repayment duration"),
      field(:payment, :integer, description: "Payment amount per frequency"),
      field(
        :frequency,
        :string,
        description: "Payment frequency",
        allowed: ["monthly", "yearly"],
      ),
      field(:category, :string, description: "Liability category"),
      field(:secured_by_asset_id, :string, description: "Related asset"),
      field(:notes, :string, description: "Notes"),
    ].freeze

    EVENT = [
      field(:id, :string, required: true, description: "Event ID"),
      field(:name, :string, required: true, description: "Event name"),
      field(:year, :year, description: "Occurrence year"),
      field(:from, :year, description: "Start year"),
      field(:to, :year, description: "End year"),
      field(:amount, :integer, description: "Financial impact"),
      field(:currency, :currency_code, description: "Currency"),
      field(:category, :string, description: "Event category"),
      field(:person_id, :string, description: "Related person"),
      field(
        :impact_type,
        :string,
        description: "Financial direction",
        allowed: ["income", "expense", "asset_change", "liability_change", "informational"],
      ),
      field(:target_asset_id, :string, description: "Asset id targeted by an asset_change event"),
      field(:notes, :string, description: "Notes"),
    ].freeze

    ASSUMPTION = [
      field(:id, :string, required: true, description: "Assumption ID"),
      field(:name, :string, required: true, description: "Human-readable name"),
      field(:value, :any, required: true, description: "Assumption value"),
      field(:unit, :string, description: "Unit of value"),
      field(:category, :string, description: "Assumption category"),
      field(:description, :string, description: "Meaning"),
      field(:source, :string, description: "Source or rationale"),
      field(:notes, :string, description: "Notes"),
    ].freeze

    CONTRIBUTION = [
      field(:id, :string, required: true, description: "Contribution ID"),
      field(:name, :string, required: true, description: "Contribution name"),
      field(:amount, :any, required: true, description: "Amount per frequency, or 'all' for full from_asset balance"),
      field(:currency, :currency_code, description: "Currency"),
      field(
        :frequency,
        :string,
        description: "Frequency",
        allowed: ["once", "monthly", "yearly"],
      ),
      field(:from, :year, description: "Start year"),
      field(:to, :year, description: "End year"),
      field(:year, :year, description: "One-time transfer year"),
      field(:from_asset, :string, required: true, description: "Source asset id"),
      field(:to_asset, :string, required: true, description: "Destination asset id"),
      field(
        :tax_treatment,
        :string,
        description: "Tax handling label (nisa, ideco_deduction, retirement_income, etc.)",
      ),
      field(:person_id, :string, description: "Related person"),
      field(:notes, :string, description: "Notes"),
    ].freeze

    SCENARIO = [
      field(:id, :string, required: true, description: "Scenario ID"),
      field(:name, :string, required: true, description: "Human-readable name"),
      field(:base, :string, description: "Base scenario ID"),
      field(:overrides, :array, description: "Scenario-specific changes"),
      field(:description, :string, description: "Scenario explanation"),
      field(:tags, :array, description: "Optional labels"),
    ].freeze

    BY_TYPE = {
      "profile" => PROFILE,
      "person" => PERSON,
      "income" => INCOME,
      "expense" => EXPENSE,
      "asset" => ASSET,
      "liability" => LIABILITY,
      "event" => EVENT,
      "contribution" => CONTRIBUTION,
      "assumption" => ASSUMPTION,
      "scenario" => SCENARIO,
    }.freeze

    PLURAL_TO_SINGULAR = {
      "profiles" => "profile",
      "people" => "person",
      "incomes" => "income",
      "expenses" => "expense",
      "assets" => "asset",
      "liabilities" => "liability",
      "events" => "event",
      "contributions" => "contribution",
      "assumptions" => "assumption",
      "scenarios" => "scenario",
    }.freeze

    SINGULAR_TO_PLURAL = PLURAL_TO_SINGULAR.invert.freeze
  end
end
