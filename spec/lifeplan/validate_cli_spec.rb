# frozen_string_literal: true

require "json"
require "lifeplan/cli"

RSpec.describe("validate command") do
  let(:cli) { Lifeplan::CLI }

  def init(dir)
    cli.start(["init", dir, "--name", "Plan", "--start-year", "2026", "--end-year", "2065"])
  end

  it "reports valid for an empty project" do
    with_tmp_project do |dir|
      init(dir)
      expect { cli.start(["validate", "--project", dir]) }.not_to(raise_error)
    end
  end

  it "exits with VALIDATION_FAILED when errors exist" do
    with_tmp_project do |dir|
      init(dir)
      cli.start([
        "add",
        "income",
        "--project",
        dir,
        "--id",
        "neg",
        "--name",
        "Neg",
        "--amount",
        "100",
        "--frequency",
        "yearly",
      ])
      project = Lifeplan::Project.load(dir)
      project.incomes[0] = project.incomes.first.with(amount: -100)
      project.save

      expect { cli.start(["validate", "--project", dir]) }
        .to(raise_error(SystemExit) { |e| expect(e.status).to(eq(3)) })
    end
  end

  it "treats warnings as errors with --strict" do
    with_tmp_project do |dir|
      init(dir)
      cli.start([
        "add",
        "liability",
        "--project",
        dir,
        "--id",
        "loan",
        "--name",
        "Loan",
        "--principal",
        "1000",
      ])
      expect { cli.start(["validate", "--project", dir, "--strict"]) }
        .to(raise_error(SystemExit) { |e| expect(e.status).to(eq(3)) })
    end
  end

  it "check command runs without error (Phase 3 stub)" do
    with_tmp_project do |dir|
      init(dir)
      expect { cli.start(["check", "--project", dir]) }.not_to(raise_error)
    end
  end
end
