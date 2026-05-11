# frozen_string_literal: true

require "lifeplan/coercion"

RSpec.describe(Lifeplan::Coercion) do
  it "coerces income.amount to integer" do
    expect(described_class.coerce_field("income", "amount", "9600000")).to(eq(9_600_000))
  end

  it "coerces income.from to year integer" do
    expect(described_class.coerce_field("income", "from", "2026")).to(eq(2026))
  end

  it "coerces asset.as_of to ISO date string" do
    expect(described_class.coerce_field("asset", "as_of", "2026-05-10")).to(eq("2026-05-10"))
  end

  it "coerces growth as decimal when numeric, otherwise string" do
    expect(described_class.coerce_field("income", "growth", "0.03")).to(eq(0.03))
    expect(described_class.coerce_field("income", "growth", "inflation")).to(eq("inflation"))
  end

  it "coerces booleans" do
    expect(described_class.coerce_field("asset", "liquid", "true")).to(be(true))
    expect(described_class.coerce_field("asset", "liquid", "no")).to(be(false))
  end

  it "rejects unknown fields" do
    expect do
      described_class.coerce_field("income", "bogus", "x")
    end.to(raise_error(Lifeplan::InvalidArguments))
  end

  it "rejects non-integer for integer fields" do
    expect do
      described_class.coerce_field("income", "amount", "abc")
    end.to(raise_error(Lifeplan::InvalidArguments))
  end

  it "coerces event.costs JSON object string to a hash" do
    result = described_class.coerce_field(
      "event", "costs", '{"broker_fee":870000,"co_owner_share":4350000}'
    )
    expect(result).to(eq({ "broker_fee" => 870_000, "co_owner_share" => 4_350_000 }))
  end
end
