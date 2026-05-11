# frozen_string_literal: true

require "json"
require "stringio"
require "lifeplan/cli"

RSpec.describe("forecast and explain commands") do
  let(:cli) { Lifeplan::CLI }

  def init_with_data(dir)
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
      "expense",
      "--project",
      dir,
      "--id",
      "living",
      "--name",
      "Living",
      "--amount",
      "400000",
      "--frequency",
      "yearly",
      "--from",
      "2026",
      "--to",
      "2028",
    ])
    cli.start([
      "add",
      "asset",
      "--project",
      dir,
      "--id",
      "cash",
      "--name",
      "Cash",
      "--amount",
      "0",
      "--as-of",
      "2026-01-01",
    ])
  end

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  it "forecast --format csv emits header and rows" do
    with_tmp_project do |dir|
      init_with_data(dir)
      out = capture_stdout do
        cli.start(["forecast", "--project", dir, "--format", "csv"])
      end
      expect(out).to(include("year,income,expense"))
      expect(out).to(include("2026,1000000,400000"))
    end
  end

  it "forecast --format json includes summary" do
    with_tmp_project do |dir|
      init_with_data(dir)
      out = capture_stdout do
        cli.start(["forecast", "--project", dir, "--format", "json"])
      end
      data = JSON.parse(out)
      expect(data["data"]["years"].size).to(eq(3))
      expect(data["data"]["summary"]["final_asset_balance"]).to(eq(1_800_000))
    end
  end

  it "forecast --include-details exposes per-asset balances in json" do
    with_tmp_project do |dir|
      init_with_data(dir)
      out = capture_stdout do
        cli.start([
          "forecast", "--project", dir, "--format", "json", "--include-details",
        ])
      end
      data = JSON.parse(out)
      details = data["data"]["years"][0]["details"]
      expect(details).to(include("assets"))
      expect(details["assets"]).to(include("cash"))
    end
  end

  it "forecast --by-person --format json includes per_person on each year row" do
    with_tmp_project do |dir|
      init_with_data(dir)
      out = capture_stdout do
        cli.start([
          "forecast", "--project", dir, "--format", "json", "--by-person",
        ])
      end
      data = JSON.parse(out)
      year0 = data["data"]["years"][0]
      expect(year0).to(include("per_person"))
      expect(year0["per_person"]["_shared"]).to(include("income" => 1_000_000, "expense" => 400_000))
    end
  end

  it "forecast --by-person --format markdown renders a per-person table per year" do
    with_tmp_project do |dir|
      init_with_data(dir)
      out = capture_stdout do
        cli.start([
          "forecast", "--project", dir, "--format", "markdown", "--by-person",
        ])
      end
      expect(out).to(include("Per-person breakdown for 2026"))
      expect(out).to(include("| _shared |"))
    end
  end

  it "forecast --by-person --format csv produces long-format rows" do
    with_tmp_project do |dir|
      init_with_data(dir)
      out = capture_stdout do
        cli.start([
          "forecast", "--project", dir, "--format", "csv", "--by-person",
        ])
      end
      expect(out).to(include("year,person_id,income,expense"))
      expect(out).to(include("2026,_shared,1000000,400000"))
    end
  end

  it "explain year prints contributors" do
    with_tmp_project do |dir|
      init_with_data(dir)
      out = capture_stdout do
        cli.start(["explain", "year", "2026", "--project", dir])
      end
      expect(out).to(include("salary"))
      expect(out).to(include("living"))
    end
  end

  it "explain year emits assumptions and warnings in JSON" do
    with_tmp_project do |dir|
      init_with_data(dir)
      out = capture_stdout do
        cli.start(["explain", "year", "2026", "--project", dir, "--format", "json"])
      end
      data = JSON.parse(out)["data"]
      expect(data).to(include("assumptions", "warnings"))
    end
  end

  it "explain metric depletion_year reports the depletion year and cumulative gap" do
    with_tmp_project do |dir|
      cli.start(["init", dir, "--name", "P", "--start-year", "2026", "--end-year", "2030"])
      cli.start([
        "add",
        "expense",
        "--project",
        dir,
        "--id",
        "big",
        "--name",
        "Big",
        "--amount",
        "2000000",
        "--frequency",
        "yearly",
        "--from",
        "2026",
        "--to",
        "2030",
      ])
      cli.start([
        "add",
        "asset",
        "--project",
        dir,
        "--id",
        "cash",
        "--name",
        "Cash",
        "--amount",
        "1000000",
        "--as-of",
        "2026-01-01",
        "--category",
        "cash",
        "--liquid",
        "true",
      ])
      out = capture_stdout do
        cli.start([
          "explain", "metric", "depletion_year", "--project", dir, "--format", "json",
        ])
      end
      data = JSON.parse(out)["data"]
      expect(data["target_type"]).to(eq("metric"))
      expect(data["value"]).to(be_a(Integer))
      expect(data["cumulative"]).to(include("income", "expense", "withdrawals"))
    end
  end

  it "explain metric reports value" do
    with_tmp_project do |dir|
      init_with_data(dir)
      out = capture_stdout do
        cli.start(["explain", "metric", "total_income", "--project", dir])
      end
      expect(out).to(include("3000000"))
    end
  end

  it "explain record sums per-year contribution across the forecast" do
    with_tmp_project do |dir|
      init_with_data(dir)
      out = capture_stdout do
        cli.start([
          "explain", "record", "income.salary", "--project", dir, "--format", "json",
        ])
      end
      data = JSON.parse(out)["data"]
      expect(data["target_type"]).to(eq("record"))
      expect(data["value"]).to(eq(3_000_000))
      expect(data["per_year"].size).to(eq(3))
    end
  end

  it "explain scenario-diff reports delta and override contributors" do
    with_tmp_project do |dir|
      init_with_data(dir)
      cli.start(["scenario", "create", "lean", "--project", dir, "--base", "base"])
      cli.start([
        "scenario", "set", "lean", "expense.living.amount", "100000", "--project", dir,
      ])
      out = capture_stdout do
        cli.start([
          "explain",
          "scenario-diff",
          "base",
          "lean",
          "--project",
          dir,
          "--year",
          "2028",
          "--format",
          "json",
        ])
      end
      data = JSON.parse(out)["data"]
      expect(data["target_type"]).to(eq("scenario_diff"))
      expect(data["deltas"]).to(include("net_worth"))
      paths = data["contributors"].map { |c| c["path"] }
      expect(paths).to(include("expense.living.amount"))
    end
  end

  it "check returns no risks for a healthy plan" do
    with_tmp_project do |dir|
      init_with_data(dir)
      out = capture_stdout do
        cli.start(["check", "--project", dir])
      end
      expect(out).to(include("No risks"))
    end
  end

  it "check flags negative assets" do
    with_tmp_project do |dir|
      cli.start(["init", dir, "--name", "P", "--start-year", "2026", "--end-year", "2027"])
      cli.start([
        "add",
        "expense",
        "--project",
        dir,
        "--id",
        "big",
        "--name",
        "Big",
        "--amount",
        "1000000",
        "--frequency",
        "yearly",
        "--from",
        "2026",
        "--to",
        "2027",
      ])
      cli.start([
        "add",
        "asset",
        "--project",
        dir,
        "--id",
        "cash",
        "--name",
        "Cash",
        "--amount",
        "0",
        "--as-of",
        "2026-01-01",
      ])
      out = capture_stdout do
        cli.start(["check", "--project", dir])
      end
      expect(out).to(include("ASSETS_NEGATIVE"))
    end
  end
end
