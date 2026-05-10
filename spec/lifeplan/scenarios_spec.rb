# frozen_string_literal: true

require "lifeplan/project"
require "lifeplan/records"
require "lifeplan/scenarios/resolver"
require "lifeplan/scenarios/path"

RSpec.describe(Lifeplan::Scenarios::Resolver) do
  def project_with_scenarios
    project = Lifeplan::Project.new(
      path: "/tmp/x",
      id: "p",
      name: "P",
      currency: "JPY",
      start_year: 2026,
      end_year: 2030,
    )
    project.assumptions << Lifeplan::Records::Assumption.from_hash({
      "id" => "inflation", "name" => "Inflation", "value" => 0.02,
    })
    project.incomes << Lifeplan::Records::Income.from_hash({
      "id" => "salary",
      "name" => "Salary",
      "amount" => 1_000_000,
      "frequency" => "yearly",
      "from" => 2026,
      "to" => 2030,
    })
    project.expenses << Lifeplan::Records::Expense.from_hash({
      "id" => "living",
      "name" => "Living",
      "amount" => 200_000,
      "frequency" => "monthly",
      "from" => 2026,
      "to" => 2030,
    })
    project.assets << Lifeplan::Records::Asset.from_hash({
      "id" => "cash", "name" => "Cash", "amount" => 5_000_000, "as_of" => "2026-01-01",
    })
    project.liabilities << Lifeplan::Records::Liability.from_hash({
      "id" => "mortgage",
      "name" => "Mortgage",
      "principal" => 30_000_000,
      "rate" => 0.01,
      "from" => 2026,
      "to" => 2055,
      "frequency" => "monthly",
    })
    project.events << Lifeplan::Records::Event.from_hash({
      "id" => "car",
      "name" => "Car",
      "year" => 2027,
      "amount" => 3_000_000,
      "impact_type" => "expense",
    })
    project.scenarios << Lifeplan::Records::Scenario.from_hash({
      "id" => "base", "name" => "Base",
    })
    project
  end

  it "returns a clone for the base scenario" do
    project = project_with_scenarios
    resolved = described_class.new(project).call("base")
    expect(resolved.assumptions.first.value).to(eq(0.02))
    expect(resolved.object_id).not_to(eq(project.object_id))
  end

  it "applies overrides on assumption values" do
    project = project_with_scenarios
    project.scenarios << Lifeplan::Records::Scenario.from_hash({
      "id" => "conservative",
      "name" => "C",
      "base" => "base",
      "overrides" => [{ "op" => "set", "path" => "assumption.inflation.value", "value" => 0.05 }],
    })

    resolved = described_class.new(project).call("conservative")
    expect(resolved.assumptions.first.value).to(eq(0.05))
    expect(project.assumptions.first.value).to(eq(0.02))
  end

  it "applies overrides on record fields with coercion" do
    project = project_with_scenarios
    project.scenarios << Lifeplan::Records::Scenario.from_hash({
      "id" => "early",
      "name" => "E",
      "base" => "base",
      "overrides" => [{ "op" => "set", "path" => "income.salary.to", "value" => 2028 }],
    })

    resolved = described_class.new(project).call("early")
    expect(resolved.incomes.first.to).to(eq(2028))
  end

  it "raises ScenarioNotFound for unknown scenarios" do
    project = project_with_scenarios
    expect { described_class.new(project).call("missing") }
      .to(raise_error(Lifeplan::ScenarioNotFound))
  end

  it "applies overrides on event fields" do
    project = project_with_scenarios
    project.scenarios << Lifeplan::Records::Scenario.from_hash({
      "id" => "delay-car",
      "name" => "Delay car",
      "base" => "base",
      "overrides" => [{ "op" => "set", "path" => "event.car.year", "value" => 2030 }],
    })

    resolved = described_class.new(project).call("delay-car")
    expect(resolved.events.first.year).to(eq(2030))
  end

  it "applies overrides on asset fields" do
    project = project_with_scenarios
    project.scenarios << Lifeplan::Records::Scenario.from_hash({
      "id" => "rich",
      "name" => "Rich",
      "base" => "base",
      "overrides" => [{ "op" => "set", "path" => "asset.cash.amount", "value" => 9_999_999 }],
    })

    resolved = described_class.new(project).call("rich")
    expect(resolved.assets.first.amount).to(eq(9_999_999))
  end

  it "applies overrides on liability fields" do
    project = project_with_scenarios
    project.scenarios << Lifeplan::Records::Scenario.from_hash({
      "id" => "refi",
      "name" => "Refi",
      "base" => "base",
      "overrides" => [{ "op" => "set", "path" => "liability.mortgage.rate", "value" => 0.025 }],
    })

    resolved = described_class.new(project).call("refi")
    expect(resolved.liabilities.first.rate).to(eq(0.025))
  end

  it "supports add op to insert a new record" do
    project = project_with_scenarios
    project.scenarios << Lifeplan::Records::Scenario.from_hash({
      "id" => "with-bonus",
      "name" => "With bonus",
      "base" => "base",
      "overrides" => [{
        "op" => "add",
        "path" => "event.inheritance",
        "value" => {
          "name" => "Inheritance",
          "year" => 2041,
          "amount" => 10_000_000,
          "impact_type" => "income",
        },
      }],
    })

    resolved = described_class.new(project).call("with-bonus")
    expect(resolved.events.map(&:id)).to(include("inheritance"))
    expect(resolved.events.find { |e| e.id == "inheritance" }.amount).to(eq(10_000_000))
  end

  it "raises on add op when id already exists" do
    project = project_with_scenarios
    project.scenarios << Lifeplan::Records::Scenario.from_hash({
      "id" => "dup",
      "name" => "Dup",
      "base" => "base",
      "overrides" => [{
        "op" => "add",
        "path" => "income.salary",
        "value" => { "name" => "Other", "amount" => 1, "frequency" => "yearly" },
      }],
    })

    expect { described_class.new(project).call("dup") }
      .to(raise_error(Lifeplan::InvalidArguments, /already exists/))
  end

  it "supports remove op" do
    project = project_with_scenarios
    project.scenarios << Lifeplan::Records::Scenario.from_hash({
      "id" => "no-car",
      "name" => "No car",
      "base" => "base",
      "overrides" => [{ "op" => "remove", "path" => "event.car" }],
    })

    resolved = described_class.new(project).call("no-car")
    expect(resolved.events.map(&:id)).not_to(include("car"))
  end

  it "raises when remove op targets a missing record" do
    project = project_with_scenarios
    project.scenarios << Lifeplan::Records::Scenario.from_hash({
      "id" => "ghost-rm",
      "name" => "GR",
      "overrides" => [{ "op" => "remove", "path" => "event.ghost" }],
    })

    expect { described_class.new(project).call("ghost-rm") }
      .to(raise_error(Lifeplan::InvalidArguments, /not found/))
  end

  it "raises on unknown override field" do
    project = project_with_scenarios
    project.scenarios << Lifeplan::Records::Scenario.from_hash({
      "id" => "bogus",
      "name" => "B",
      "overrides" => [{ "op" => "set", "path" => "income.salary.bogus", "value" => 1 }],
    })

    expect { described_class.new(project).call("bogus") }
      .to(raise_error(Lifeplan::InvalidArguments, /Unknown field/))
  end

  it "raises on circular base inheritance" do
    project = project_with_scenarios
    project.scenarios << Lifeplan::Records::Scenario.from_hash({
      "id" => "a", "name" => "A", "base" => "b",
    })
    project.scenarios << Lifeplan::Records::Scenario.from_hash({
      "id" => "b", "name" => "B", "base" => "a",
    })

    expect { described_class.new(project).call("a") }
      .to(raise_error(Lifeplan::InvalidArguments, /cycle/))
  end

  it "raises on missing override target" do
    project = project_with_scenarios
    project.scenarios << Lifeplan::Records::Scenario.from_hash({
      "id" => "broken",
      "name" => "B",
      "overrides" => [{ "op" => "set", "path" => "income.ghost.amount", "value" => 1 }],
    })

    expect { described_class.new(project).call("broken") }
      .to(raise_error(Lifeplan::InvalidArguments, /not found/))
  end
end

RSpec.describe(Lifeplan::Scenarios::Path) do
  it "parses 3-segment paths" do
    p = described_class.parse("income.salary.amount")
    expect(p.type).to(eq("income"))
    expect(p.id).to(eq("salary"))
    expect(p.field).to(eq("amount"))
  end

  it "canonicalizes plural type to singular" do
    p = described_class.parse("incomes.salary.amount")
    expect(p.type).to(eq("income"))
  end

  it "rejects unknown record types" do
    expect { described_class.parse("widget.foo.bar") }
      .to(raise_error(Lifeplan::InvalidArguments))
  end

  it "rejects paths without an id segment" do
    expect { described_class.parse("income") }
      .to(raise_error(Lifeplan::InvalidArguments))
  end
end
