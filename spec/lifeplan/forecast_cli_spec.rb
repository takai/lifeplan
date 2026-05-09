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

  it "explain metric reports value" do
    with_tmp_project do |dir|
      init_with_data(dir)
      out = capture_stdout do
        cli.start(["explain", "metric", "total_income", "--project", dir])
      end
      expect(out).to(include("3000000"))
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
