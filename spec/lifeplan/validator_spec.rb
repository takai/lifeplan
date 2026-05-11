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

  it "flags asset_disposal events missing target_asset_id" do
    project = make_project
    project.assets << Lifeplan::Records::Asset.from_hash({
      "id" => "cash", "name" => "Cash", "amount" => 0, "as_of" => "2026-01-01", "category" => "cash",
    })
    project.events << Lifeplan::Records::Event.from_hash({
      "id" => "sale",
      "name" => "Sale",
      "year" => 2030,
      "impact_type" => "asset_disposal",
      "proceeds" => 1_000_000,
    })

    codes = described_class.new.call(project).map(&:code)
    expect(codes).to(include("MISSING_REQUIRED_FIELD"))
  end

  it "flags asset_disposal events missing proceeds" do
    project = make_project
    project.assets << Lifeplan::Records::Asset.from_hash({
      "id" => "cash", "name" => "Cash", "amount" => 0, "as_of" => "2026-01-01", "category" => "cash",
    })
    project.assets << Lifeplan::Records::Asset.from_hash({
      "id" => "condo", "name" => "Condo", "amount" => 1_000_000, "as_of" => "2026-01-01",
    })
    project.events << Lifeplan::Records::Event.from_hash({
      "id" => "sale",
      "name" => "Sale",
      "year" => 2030,
      "impact_type" => "asset_disposal",
      "target_asset_id" => "condo",
    })

    codes = described_class.new.call(project).map(&:code)
    expect(codes).to(include("MISSING_REQUIRED_FIELD"))
  end

  it "flags asset_disposal events with unknown target_asset_id" do
    project = make_project
    project.assets << Lifeplan::Records::Asset.from_hash({
      "id" => "cash", "name" => "Cash", "amount" => 0, "as_of" => "2026-01-01", "category" => "cash",
    })
    project.events << Lifeplan::Records::Event.from_hash({
      "id" => "sale",
      "name" => "Sale",
      "year" => 2030,
      "impact_type" => "asset_disposal",
      "target_asset_id" => "ghost",
      "proceeds" => 1_000_000,
    })

    codes = described_class.new.call(project).map(&:code)
    expect(codes).to(include("MISSING_REFERENCE"))
  end

  it "flags asset_disposal events with unknown proceeds_to_asset" do
    project = make_project
    project.assets << Lifeplan::Records::Asset.from_hash({
      "id" => "condo", "name" => "Condo", "amount" => 1_000_000, "as_of" => "2026-01-01",
    })
    project.events << Lifeplan::Records::Event.from_hash({
      "id" => "sale",
      "name" => "Sale",
      "year" => 2030,
      "impact_type" => "asset_disposal",
      "target_asset_id" => "condo",
      "proceeds" => 1_000_000,
      "proceeds_to_asset" => "ghost",
    })

    codes = described_class.new.call(project).map(&:code)
    expect(codes).to(include("MISSING_REFERENCE"))
  end

  it "flags asset_disposal with no proceeds_to_asset and no cash-category asset" do
    project = make_project
    project.assets << Lifeplan::Records::Asset.from_hash({
      "id" => "condo", "name" => "Condo", "amount" => 1_000_000, "as_of" => "2026-01-01",
    })
    project.events << Lifeplan::Records::Event.from_hash({
      "id" => "sale",
      "name" => "Sale",
      "year" => 2030,
      "impact_type" => "asset_disposal",
      "target_asset_id" => "condo",
      "proceeds" => 1_000_000,
    })

    codes = described_class.new.call(project).map(&:code)
    expect(codes).to(include("MISSING_REFERENCE"))
  end

  it "accepts a project without household_aggregation set (defaults to merged)" do
    project = make_project
    expect(described_class.new.call(project)).to(be_empty)
  end

  it "accepts household_aggregation == merged" do
    project = make_project
    project.household_aggregation = "merged"
    expect(described_class.new.call(project)).to(be_empty)
  end

  it "rejects household_aggregation == separate as unsupported" do
    project = make_project
    project.household_aggregation = "separate"
    codes = described_class.new.call(project).map(&:code)
    expect(codes).to(include("UNSUPPORTED_AGGREGATION"))
  end

  it "rejects household_aggregation == joint_with_individual as unsupported" do
    project = make_project
    project.household_aggregation = "joint_with_individual"
    codes = described_class.new.call(project).map(&:code)
    expect(codes).to(include("UNSUPPORTED_AGGREGATION"))
  end

  it "rejects an unknown household_aggregation value" do
    project = make_project
    project.household_aggregation = "bogus"
    codes = described_class.new.call(project).map(&:code)
    expect(codes).to(include("INVALID_ENUM"))
  end

  it "accepts a well-formed asset_disposal event" do
    project = make_project
    project.assets << Lifeplan::Records::Asset.from_hash({
      "id" => "cash", "name" => "Cash", "amount" => 0, "as_of" => "2026-01-01", "category" => "cash",
    })
    project.assets << Lifeplan::Records::Asset.from_hash({
      "id" => "condo", "name" => "Condo", "amount" => 1_000_000, "as_of" => "2026-01-01",
    })
    project.events << Lifeplan::Records::Event.from_hash({
      "id" => "sale",
      "name" => "Sale",
      "year" => 2030,
      "impact_type" => "asset_disposal",
      "target_asset_id" => "condo",
      "proceeds" => 800_000,
    })

    issues = described_class.new.call(project)
    expect(issues).to(be_empty)
  end
end
