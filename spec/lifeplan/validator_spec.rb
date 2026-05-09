# frozen_string_literal: true

require "lifeplan/project"
require "lifeplan/records"
require "lifeplan/validation/validator"

RSpec.describe(Lifeplan::Validation::Validator) do
  def make_project
    project = Lifeplan::Project.new(
      path: "/tmp/x",
      id: "p",
      name: "Plan",
      currency: "JPY",
      start_year: 2026,
      end_year: 2030,
    )
    project
  end

  it "returns no issues for an empty valid project" do
    expect(described_class.new.call(make_project)).to(be_empty)
  end

  it "detects duplicate ids" do
    project = make_project
    project.incomes << Lifeplan::Records::Income.from_hash({
      "id" => "a", "name" => "A", "amount" => 1, "frequency" => "yearly",
    })
    project.incomes << Lifeplan::Records::Income.from_hash({
      "id" => "a", "name" => "B", "amount" => 2, "frequency" => "yearly",
    })

    issues = described_class.new.call(project)
    expect(issues.map(&:code)).to(include("DUPLICATE_ID"))
  end

  it "flags negative amounts" do
    project = make_project
    project.expenses << Lifeplan::Records::Expense.from_hash({
      "id" => "e", "name" => "E", "amount" => -100, "frequency" => "yearly",
    })

    issues = described_class.new.call(project)
    expect(issues.map(&:code)).to(include("NEGATIVE_AMOUNT"))
  end

  it "flags asset missing as_of" do
    project = make_project
    project.assets << Lifeplan::Records::Asset.from_hash({
      "id" => "cash", "name" => "Cash", "amount" => 100,
    })

    codes = described_class.new.call(project).map(&:code)
    expect(codes).to(include("ASSET_MISSING_AS_OF"))
  end

  it "flags invalid period (from > to)" do
    project = make_project
    project.incomes << Lifeplan::Records::Income.from_hash({
      "id" => "s",
      "name" => "S",
      "amount" => 1,
      "frequency" => "yearly",
      "from" => 2030,
      "to" => 2026,
    })

    codes = described_class.new.call(project).map(&:code)
    expect(codes).to(include("INVALID_PERIOD"))
  end

  it "flags missing scenario base" do
    project = make_project
    project.scenarios << Lifeplan::Records::Scenario.from_hash({
      "id" => "child", "name" => "Child", "base" => "missing",
    })

    codes = described_class.new.call(project).map(&:code)
    expect(codes).to(include("SCENARIO_BASE_MISSING"))
  end

  it "detects scenario inheritance cycles" do
    project = make_project
    project.scenarios << Lifeplan::Records::Scenario.from_hash({
      "id" => "a", "name" => "A", "base" => "b",
    })
    project.scenarios << Lifeplan::Records::Scenario.from_hash({
      "id" => "b", "name" => "B", "base" => "a",
    })

    codes = described_class.new.call(project).map(&:code)
    expect(codes).to(include("SCENARIO_CYCLE"))
  end

  it "flags missing references" do
    project = make_project
    project.incomes << Lifeplan::Records::Income.from_hash({
      "id" => "s",
      "name" => "S",
      "amount" => 1,
      "frequency" => "yearly",
      "person_id" => "ghost",
    })

    codes = described_class.new.call(project).map(&:code)
    expect(codes).to(include("MISSING_REFERENCE"))
  end
end
