# frozen_string_literal: true

require "json"
require "stringio"
require "lifeplan/cli"

RSpec.describe("sensitivity command") do
  let(:cli) { Lifeplan::CLI }

  def init(dir)
    cli.start(["init", dir, "--name", "Plan", "--start-year", "2026", "--end-year", "2030"])
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
      "5000000",
      "--frequency",
      "yearly",
      "--from",
      "2026",
      "--to",
      "2030",
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
      "4000000",
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
    cli.start([
      "add",
      "event",
      "--project",
      dir,
      "--id",
      "bonus",
      "--name",
      "Bonus",
      "--year",
      "2027",
      "--amount",
      "1000000",
      "--impact-type",
      "income",
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

  it "produces a 2D table for two axes and a metric" do
    with_tmp_project do |dir|
      init(dir)
      out = capture do
        cli.start([
          "sensitivity",
          "--project",
          dir,
          "--x-axis",
          "expense.living.amount",
          "--x-values",
          "3000000,5000000",
          "--y-axis",
          "event.bonus.amount",
          "--y-values",
          "0,1000000",
          "--metric",
          "net_worth_at_2030",
          "--format",
          "text",
        ])
      end
      expect(out).to(include("net_worth_at_2030"))
      expect(out).to(include("3000000"))
      expect(out).to(include("5000000"))
    end
  end

  it "emits a 2D grid in json with depletion flags" do
    with_tmp_project do |dir|
      init(dir)
      out = capture do
        cli.start([
          "sensitivity",
          "--project",
          dir,
          "--x-axis",
          "expense.living.amount",
          "--x-values",
          "3000000,8000000",
          "--y-axis",
          "event.bonus.amount",
          "--y-values",
          "0",
          "--metric",
          "net_worth_at_2030",
          "--format",
          "json",
        ])
      end
      data = JSON.parse(out)["data"]
      expect(data["x_values"]).to(eq([3_000_000, 8_000_000]))
      expect(data["y_values"]).to(eq([0]))
      expect(data["grid"].size).to(eq(2))
      cheap = data["grid"][0][0]
      pricey = data["grid"][1][0]
      expect(cheap["value"]).to(be > pricey["value"])
      expect(pricey["liquid_depleted"]).to(be(true))
      expect(cheap["liquid_depleted"]).to(be(false))
    end
  end

  it "supports summary metrics like depletion_year" do
    with_tmp_project do |dir|
      init(dir)
      out = capture do
        cli.start([
          "sensitivity",
          "--project",
          dir,
          "--x-axis",
          "expense.living.amount",
          "--x-values",
          "8000000",
          "--y-axis",
          "event.bonus.amount",
          "--y-values",
          "0",
          "--metric",
          "depletion_year",
          "--format",
          "json",
        ])
      end
      data = JSON.parse(out)["data"]
      expect(data["grid"][0][0]["value"]).to(be_a(Integer))
    end
  end

  it "rejects unknown metrics with a clear message" do
    with_tmp_project do |dir|
      init(dir)
      expect do
        cli.start([
          "sensitivity",
          "--project",
          dir,
          "--x-axis",
          "expense.living.amount",
          "--x-values",
          "3000000",
          "--y-axis",
          "event.bonus.amount",
          "--y-values",
          "0",
          "--metric",
          "garbage",
        ])
      end.to(raise_error(SystemExit))
    end
  end

  it "appends * to depleted cells in markdown" do
    with_tmp_project do |dir|
      init(dir)
      out = capture do
        cli.start([
          "sensitivity",
          "--project",
          dir,
          "--x-axis",
          "expense.living.amount",
          "--x-values",
          "8000000",
          "--y-axis",
          "event.bonus.amount",
          "--y-values",
          "0",
          "--metric",
          "net_worth_at_2030",
          "--format",
          "markdown",
        ])
      end
      lines = out.split("\n").reject(&:empty?)
      body_line = lines.find { |l| l.start_with?("| 8000000") }
      expect(body_line).to(include("*"))
    end
  end

  it "emits CSV with y-values as columns" do
    with_tmp_project do |dir|
      init(dir)
      out = capture do
        cli.start([
          "sensitivity",
          "--project",
          dir,
          "--x-axis",
          "expense.living.amount",
          "--x-values",
          "3000000,5000000",
          "--y-axis",
          "event.bonus.amount",
          "--y-values",
          "0,1000000",
          "--metric",
          "net_worth_at_2030",
          "--format",
          "csv",
        ])
      end
      lines = out.split("\n").reject(&:empty?)
      expect(lines[0]).to(eq("net_worth_at_2030,0,1000000"))
      expect(lines[1]).to(start_with("3000000,"))
      expect(lines[2]).to(start_with("5000000,"))
    end
  end
end
