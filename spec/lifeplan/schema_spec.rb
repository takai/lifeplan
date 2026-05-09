# frozen_string_literal: true

require "lifeplan/schema"

RSpec.describe(Lifeplan::Schema) do
  it "lists canonical record types" do
    expect(described_class.types).to(include("income", "expense", "asset", "scenario"))
  end

  it "translates plural to canonical singular" do
    expect(described_class.canonical("incomes")).to(eq("income"))
    expect(described_class.canonical("income")).to(eq("income"))
  end

  it "returns fields including required ones" do
    income = described_class.fields_for("income")
    required = income.select(&:required).map(&:name)
    expect(required).to(include(:id, :name, :amount, :frequency))
  end

  it "raises on unknown type" do
    expect { described_class.fields_for("unknown") }.to(raise_error(Lifeplan::InvalidArguments))
  end
end
