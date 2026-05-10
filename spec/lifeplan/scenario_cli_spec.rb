# frozen_string_literal: true

require "json"
require "stringio"
require "lifeplan/cli"

RSpec.describe("scenario and compare commands") do
  let(:cli) { Lifeplan::CLI }

  def init(dir)
    cli.start(["init", dir, "--name", "Plan", "--start-year", "2026", "--end-year", "2028"])
    cli.start([
      "add",
      "income",
      "--project",
      dir,
      "--id",
      "salary",
      "--name",
      "Salary",
      "--amount",
      "1000000",
      "--frequency",
      "yearly",
      "--from",
      "2026",
      "--to",
      "2028",
    ])
    cli.start([
      "add",
      "assumption",
      "--project",
      dir,
      "--id",
      "inflation",
      "--name",
      "Inflation",
      "--value",
      "0.02",
    ])
  end

  def capture
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  it "creates and lists scenarios" do
    with_tmp_project do |dir|
      init(dir)
      cli.start(["scenario", "create", "conservative", "--project", dir, "--base", "base"])
      out = capture { cli.start(["scenario", "list", "--project", dir]) }
      expect(out).to(include("conservative"))
    end
  end

  it "set adds an override and resolver applies it" do
    with_tmp_project do |dir|
      init(dir)
      cli.start(["scenario", "create", "high-inf", "--project", dir])
      cli.start([
        "scenario",
        "set",
        "high-inf",
        "assumption.inflation.value",
        "0.05",
        "--project",
        dir,
      ])
      project = Lifeplan::Project.load(dir)
      scenario = project.scenarios.find { |s| s.id == "high-inf" }
      expect(scenario.overrides.first["value"]).to(eq(0.05))
    end
  end

  it "compare emits one row per scenario in JSON" do
    with_tmp_project do |dir|
      init(dir)
      cli.start(["scenario", "create", "early", "--project", dir])
      cli.start([
        "scenario",
        "set",
        "early",
        "income.salary.to",
        "2026",
        "--project",
        dir,
      ])
      out = capture do
        cli.start(["compare", "base", "early", "--project", dir, "--format", "json"])
      end
      data = JSON.parse(out)["data"]
      expect(data["scenarios"].map { |s| s["scenario_id"] }).to(eq(["base", "early"]))
      expect(data["scenarios"].first.keys).to(include(
        "net_worth",
        "liquid",
        "depletion_year",
        "min_liquid_year",
        "final_asset_balance",
        "total_income",
        "total_expense",
      ))
      base_row = data["scenarios"].find { |s| s["scenario_id"] == "base" }
      early_row = data["scenarios"].find { |s| s["scenario_id"] == "early" }
      expect(early_row["total_income"]).to(be < base_row["total_income"])
    end
  end

  it "compare renders a text table for three scenarios with @<year> headers" do
    with_tmp_project do |dir|
      init(dir)
      cli.start(["scenario", "create", "early", "--project", dir])
      cli.start(["scenario", "create", "late", "--project", dir])
      out = capture do
        cli.start(["compare", "base", "early", "late", "--project", dir, "--format", "text"])
      end
      expect(out).to(include("base"))
      expect(out).to(include("early"))
      expect(out).to(include("late"))
      expect(out).to(include("net_worth@2028"))
      expect(out).to(include("liquid@2028"))
    end
  end

  it "compare honors --metrics and --at" do
    with_tmp_project do |dir|
      init(dir)
      out = capture do
        cli.start([
          "compare",
          "base",
          "--project",
          dir,
          "--metrics",
          "net_worth,liquid",
          "--at",
          "2027",
          "--format",
          "json",
        ])
      end
      data = JSON.parse(out)["data"]
      expect(data["at"]).to(eq(2027))
      expect(data["metrics"]).to(eq(["net_worth", "liquid"]))
    end
  end

  it "compare accepts md format alias" do
    with_tmp_project do |dir|
      init(dir)
      out = capture do
        cli.start(["compare", "base", "--project", dir, "--format", "md"])
      end
      expect(out).to(include("| scenario |"))
    end
  end

  it "remove deletes a scenario" do
    with_tmp_project do |dir|
      init(dir)
      cli.start(["scenario", "create", "x", "--project", dir])
      cli.start(["scenario", "remove", "x", "--project", dir])
      project = Lifeplan::Project.load(dir)
      expect(project.scenarios.map(&:id)).not_to(include("x"))
    end
  end
end
