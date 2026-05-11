# frozen_string_literal: true

require "json"
require "stringio"
require "lifeplan/cli"

RSpec.describe("export and report commands") do
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
      "expense",
      "--project",
      dir,
      "--id",
      "living",
      "--name",
      "Living",
      "--amount",
      "500000",
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
      "1000000",
      "--as-of",
      "2026-01-01",
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

  it "export data --format json dumps the project" do
    with_tmp_project do |dir|
      init(dir)
      out = capture { cli.start(["export", "data", "--project", dir, "--format", "json"]) }
      data = JSON.parse(out)["data"]
      expect(data["project"]["name"]).to(eq("Plan"))
      expect(data["incomes"].size).to(eq(1))
      expect(data["expenses"].size).to(eq(1))
    end
  end

  it "export forecast --format csv emits wide per-record columns" do
    with_tmp_project do |dir|
      init(dir)
      out = capture { cli.start(["export", "forecast", "--project", dir, "--format", "csv"]) }
      header = out.split("\n").first
      expect(header).to(include("income_total"))
      expect(header).to(include("income_salary"))
      expect(header).to(include("expense_living"))
      expect(header).to(include("asset_cash"))
      expect(header).to(include("liquid_balance"))
      expect(out).to(include("2026"))
    end
  end

  it "export report --format markdown delegates to the report builder" do
    with_tmp_project do |dir|
      init(dir)
      out = capture { cli.start(["export", "report", "--project", dir, "--format", "markdown"]) }
      expect(out).to(include("# Life Plan Report: Plan"))
      expect(out).to(include("## Forecast"))
    end
  end

  it "export forecast --output writes to file" do
    with_tmp_project do |dir|
      init(dir)
      out_path = File.join(dir, "forecast.csv")
      capture do
        cli.start([
          "export", "forecast", "--project", dir, "--format", "csv", "--output", out_path,
        ])
      end
      expect(File.exist?(out_path)).to(be(true))
      header = File.read(out_path).split("\n").first
      expect(header).to(include("income_total"))
    end
  end

  it "export rejects unknown targets" do
    with_tmp_project do |dir|
      init(dir)
      expect { cli.start(["export", "bogus", "--project", dir]) }
        .to(raise_error(SystemExit))
    end
  end

  it "report --format markdown composes a markdown document" do
    with_tmp_project do |dir|
      init(dir)
      out = capture { cli.start(["report", "--project", dir, "--format", "markdown"]) }
      expect(out).to(include("# Life Plan Report: Plan"))
      expect(out).to(include("## Summary"))
      expect(out).to(include("## Forecast"))
    end
  end

  it "report --include-validation adds the validation section" do
    with_tmp_project do |dir|
      init(dir)
      out = capture do
        cli.start(["report", "--project", dir, "--format", "markdown", "--include-validation"])
      end
      expect(out).to(include("## Validation"))
    end
  end
end
