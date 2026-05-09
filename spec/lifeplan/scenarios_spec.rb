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
end
