# frozen_string_literal: true

require "json"
require "stringio"
require "lifeplan/cli"

RSpec.describe("calc CLI") do
  let(:cli) { Lifeplan::CLI }

  def capture
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  it "calc fv prints future value as text" do
    out = capture { cli.start(["calc", "fv", "--principal", "10000000", "--rate", "0.03", "--years", "20"]) }
    expect(out).to(include("future_value"))
    expect(out).to(match(/18061\d+/))
  end

  it "calc pv emits json envelope" do
    out = capture do
      cli.start(["calc", "pv", "--future", "1000000", "--rate", "0.03", "--years", "10", "--format", "json"])
    end
    parsed = JSON.parse(out)
    expect(parsed["data"]).to(have_key("present_value"))
  end

  it "calc savings supports monthly frequency" do
    out = capture do
      cli.start([
        "calc",
        "savings",
        "--payment",
        "50000",
        "--rate",
        "0.03",
        "--years",
        "10",
        "--frequency",
        "monthly",
        "--format",
        "json",
      ])
    end
    value = JSON.parse(out)["data"]["savings"]
    expect(value).to(be_within(50).of(6_987_071))
  end

  it "calc loan emits csv with metric/value rows" do
    out = capture do
      cli.start([
        "calc", "loan", "--principal", "30000000", "--rate", "0.012", "--years", "30", "--format", "csv",
      ])
    end
    expect(out).to(include("metric,value"))
    expect(out).to(include("periodic_payment"))
    expect(out).to(include("total_interest"))
  end

  it "calc grow emits a row per year in csv" do
    out = capture do
      cli.start(["calc", "grow", "--amount", "1000", "--rate", "0.05", "--years", "3", "--format", "csv"])
    end
    expect(out).to(include("year,value"))
    expect(out.lines.size).to(be >= 5)
  end

  it "calc mortgage emits json with yearly breakdown and totals" do
    out = capture do
      cli.start([
        "calc",
        "mortgage",
        "--principal",
        "7487975",
        "--rate",
        "0.0059",
        "--payment",
        "76754",
        "--from",
        "2026-05",
        "--format",
        "json",
      ])
    end
    parsed = JSON.parse(out)
    expect(parsed["data"]["final_year"]).to(eq(2034))
    expect(parsed["data"]["final_period"]).to(be_between(7, 10))
    expect(parsed["data"]["yearly"]).to(be_an(Array))
  end

  it "calc mortgage honors --rate-changes" do
    out = capture do
      cli.start([
        "calc",
        "mortgage",
        "--principal",
        "1000000",
        "--rate",
        "0.01",
        "--payment",
        "50000",
        "--from",
        "2030-01",
        "--rate-changes",
        "2031:0.05",
        "--format",
        "json",
      ])
    end
    yearly = JSON.parse(out)["data"]["yearly"]
    rate_2031 = yearly.find { |r| r["year"] == 2031 }["rate"]
    expect(rate_2031).to(eq(0.05))
  end

  it "calc required-savings inverts savings" do
    out = capture do
      cli.start([
        "calc", "required-savings", "--target", "11463879", "--rate", "0.03", "--years", "10", "--format", "json",
      ])
    end
    payment = JSON.parse(out)["data"]["required_savings"]
    expect(payment).to(be_within(1).of(1_000_000))
  end
end
