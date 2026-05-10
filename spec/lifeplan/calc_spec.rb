# frozen_string_literal: true

require "lifeplan/calc"

RSpec.describe(Lifeplan::Calc) do
  describe ".future_value" do
    it "compounds annually" do
      result = Lifeplan::Calc.future_value(principal: 10_000_000, rate: 0.03, years: 20)
      expect(result).to(be_within(1).of(18_061_112))
    end

    it "returns principal when rate is zero" do
      expect(Lifeplan::Calc.future_value(principal: 1_000, rate: 0, years: 10)).to(eq(1_000))
    end
  end

  describe ".present_value" do
    it "is the inverse of future_value" do
      pv = Lifeplan::Calc.present_value(future: 18_061_112, rate: 0.03, years: 20)
      expect(pv).to(be_within(1).of(10_000_000))
    end
  end

  describe ".savings" do
    it "computes future value of yearly payments with initial" do
      result = Lifeplan::Calc.savings(
        payment: 1_000_000, rate: 0.03, years: 10, initial: 0, frequency: "yearly",
      )
      expect(result).to(be_within(1).of(11_463_879))
    end

    it "supports monthly frequency" do
      result = Lifeplan::Calc.savings(
        payment: 50_000, rate: 0.03, years: 10, frequency: "monthly",
      )
      expect(result).to(be_within(50).of(6_987_071))
    end

    it "handles zero rate as simple sum" do
      expect(
        Lifeplan::Calc.savings(payment: 1_000, rate: 0, years: 5, initial: 100),
      ).to(eq(5_100))
    end
  end

  describe ".required_savings" do
    it "is the inverse of savings for the periodic payment" do
      payment = Lifeplan::Calc.required_savings(
        target: 11_463_879, rate: 0.03, years: 10, frequency: "yearly",
      )
      expect(payment).to(be_within(1).of(1_000_000))
    end
  end

  describe ".withdrawal" do
    it "computes annuity payout" do
      result = Lifeplan::Calc.withdrawal(principal: 30_000_000, rate: 0.03, years: 30)
      expect(result).to(be_within(1).of(1_530_578))
    end

    it "splits evenly when rate is zero" do
      expect(Lifeplan::Calc.withdrawal(principal: 1_200, rate: 0, years: 10)).to(eq(120))
    end
  end

  describe ".loan" do
    it "computes monthly payment, totals and interest" do
      result = Lifeplan::Calc.loan(
        principal: 30_000_000, rate: 0.012, years: 30, frequency: "monthly",
      )
      expect(result[:periodic_payment]).to(be_within(1).of(99_273))
      expect(result[:periods]).to(eq(360))
      expect(result[:total_interest]).to(be_within(500).of(5_738_139))
    end
  end

  describe ".mortgage" do
    it "amortizes month-by-month and matches the FP-session example" do
      result = Lifeplan::Calc.mortgage(
        principal: 7_487_975, rate: 0.0059, payment: 76_754, frequency: "monthly", from: "2026-05",
      )
      expect(result[:final_year]).to(eq(2034))
      expect(result[:periods]).to(be_between(99, 101))
      expect(result[:total_interest]).to(be < 200_000)
    end

    it "applies rate changes at the start of the named year" do
      flat = Lifeplan::Calc.mortgage(
        principal: 1_000_000, rate: 0.01, payment: 50_000, from: "2030-01",
      )
      bumped = Lifeplan::Calc.mortgage(
        principal: 1_000_000,
        rate: 0.01,
        payment: 50_000,
        from: "2030-01",
        rate_changes: { 2031 => 0.05 },
      )
      expect(bumped[:total_interest]).to(be > flat[:total_interest])
    end

    it "accepts rate_changes as a 'YYYY:rate,...' string" do
      result = Lifeplan::Calc.mortgage(
        principal: 5_000_000,
        rate: 0.01,
        payment: 50_000,
        from: "2030-01",
        rate_changes: "2031:0.02,2032:0.03",
      )
      rates = result[:yearly].to_h { |row| [row["year"], row["rate"]] }
      expect(rates[2031]).to(eq(0.02))
      expect(rates[2032]).to(eq(0.03))
    end

    it "produces a yearly breakdown that sums to total interest/principal" do
      result = Lifeplan::Calc.mortgage(
        principal: 1_000_000, rate: 0.01, payment: 50_000, from: "2030-01",
      )
      sum_interest = result[:yearly].sum { |r| r["interest"] }
      sum_principal = result[:yearly].sum { |r| r["principal"] }
      expect(sum_interest).to(be_within(2).of(result[:total_interest]))
      expect(sum_principal).to(be_within(2).of(result[:total_principal]))
    end
  end

  describe ".inflation" do
    it "discounts to present value at inflation rate" do
      expect(Lifeplan::Calc.inflation(amount: 1_000_000, rate: 0.02, years: 10))
        .to(be_within(1).of(820_348))
    end
  end

  describe ".grow" do
    it "produces a year-by-year growth table" do
      table = Lifeplan::Calc.grow(amount: 1_000, rate: 0.05, years: 3)
      expect(table.size).to(eq(4))
      expect(table.first).to(eq("year" => 0, "value" => 1_000.0))
      expect(table.last["value"]).to(be_within(0.01).of(1_157.625))
    end
  end
end
