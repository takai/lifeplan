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

  it "flags contributions referencing unknown assets" do
    project = make_project
    project.assets << Lifeplan::Records::Asset.from_hash({
      "id" => "cash", "name" => "Cash", "amount" => 0, "as_of" => "2026-01-01",
    })
    project.contributions << Lifeplan::Records::Contribution.from_hash({
      "id" => "c",
      "name" => "C",
      "amount" => 100,
      "from_asset" => "cash",
      "to_asset" => "ghost",
      "year" => 2026,
    })

    codes = described_class.new.call(project).map(&:code)
    expect(codes).to(include("MISSING_REFERENCE"))
  end

  it "flags contributions whose from_asset and to_asset are identical" do
    project = make_project
    project.assets << Lifeplan::Records::Asset.from_hash({
      "id" => "cash", "name" => "Cash", "amount" => 0, "as_of" => "2026-01-01",
    })
    project.contributions << Lifeplan::Records::Contribution.from_hash({
      "id" => "c",
      "name" => "C",
      "amount" => 100,
      "from_asset" => "cash",
      "to_asset" => "cash",
      "year" => 2026,
    })

    codes = described_class.new.call(project).map(&:code)
    expect(codes).to(include("INVALID_REFERENCE"))
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

  it "flags expense transitions that are not strictly ascending" do
    project = make_project
    project.expenses << Lifeplan::Records::Expense.from_hash({
      "id" => "living",
      "name" => "Living",
      "amount" => 6_400_000,
      "frequency" => "yearly",
      "from" => 2026,
      "to" => 2030,
      "transitions" => [
        { "year" => 2028, "amount" => 5_400_000 },
        { "year" => 2027, "amount" => 4_900_000 },
      ],
    })

    codes = described_class.new.call(project).map(&:code)
    expect(codes).to(include("TRANSITIONS_NOT_SORTED"))
  end

  it "flags negative transition amount" do
    project = make_project
    project.expenses << Lifeplan::Records::Expense.from_hash({
      "id" => "living",
      "name" => "Living",
      "amount" => 6_400_000,
      "frequency" => "yearly",
      "from" => 2026,
      "to" => 2030,
      "transitions" => [{ "year" => 2028, "amount" => -1 }],
    })

    codes = described_class.new.call(project).map(&:code)
    expect(codes).to(include("NEGATIVE_AMOUNT"))
  end

  it "flags transition year outside expense period" do
    project = make_project
    project.expenses << Lifeplan::Records::Expense.from_hash({
      "id" => "living",
      "name" => "Living",
      "amount" => 6_400_000,
      "frequency" => "yearly",
      "from" => 2026,
      "to" => 2030,
      "transitions" => [{ "year" => 2040, "amount" => 1_000_000 }],
    })

    codes = described_class.new.call(project).map(&:code)
    expect(codes).to(include("TRANSITION_OUT_OF_RANGE"))
  end

  it "accepts a well-formed transitions array" do
    project = make_project
    project.expenses << Lifeplan::Records::Expense.from_hash({
      "id" => "living",
      "name" => "Living",
      "amount" => 6_400_000,
      "frequency" => "yearly",
      "from" => 2026,
      "to" => 2030,
      "transitions" => [
        { "year" => 2028, "amount" => 5_400_000, "label" => "stage" },
      ],
    })

    codes = described_class.new.call(project).map(&:code)
    expect(codes).not_to(include("TRANSITIONS_NOT_SORTED"))
    expect(codes).not_to(include("TRANSITION_OUT_OF_RANGE"))
    expect(codes).not_to(include("INVALID_TRANSITIONS"))
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
