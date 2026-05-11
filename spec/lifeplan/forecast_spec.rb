# frozen_string_literal: true

require "lifeplan/project"
require "lifeplan/records"
require "lifeplan/forecast/engine"

RSpec.describe(Lifeplan::Forecast::Engine) do
  def project_with(start: 2026, last: 2030, &block)
    project = Lifeplan::Project.new(
      path: "/tmp/x",
      id: "p",
      name: "Plan",
      currency: "JPY",
      start_year: start,
      end_year: last,
    )
    block&.call(project)
    project
  end

  def income(**attrs)
    Lifeplan::Records::Income.from_hash({
      "id" => "i", "name" => "I", "frequency" => "yearly",
    }.merge(attrs.transform_keys(&:to_s)))
  end

  def expense(**attrs)
    Lifeplan::Records::Expense.from_hash({
      "id" => "e", "name" => "E", "frequency" => "yearly",
    }.merge(attrs.transform_keys(&:to_s)))
  end

  def asset(**attrs)
    Lifeplan::Records::Asset.from_hash({
      "id" => "a", "name" => "A", "as_of" => "2026-01-01",
    }.merge(attrs.transform_keys(&:to_s)))
  end

  it "produces one row per year between start and end" do
    project = project_with
    result = described_class.new(project).call
    expect(result.years.map(&:year)).to(eq([2026, 2027, 2028, 2029, 2030]))
  end

  it "applies yearly income and expense to net cashflow and asset balance" do
    project = project_with do |p|
      p.incomes << income(amount: 1_000_000, from: 2026, to: 2030)
      p.expenses << expense(amount: 400_000, from: 2026, to: 2030)
      p.assets << asset(amount: 0)
    end

    result = described_class.new(project).call
    first = result.years.first
    expect(first.income).to(eq(1_000_000))
    expect(first.expense).to(eq(400_000))
    expect(first.net_cashflow).to(eq(600_000))
    expect(first.asset_balance).to(eq(600_000))

    expect(result.years.last.asset_balance).to(eq(3_000_000))
  end

  it "applies growth using assumption references" do
    project = project_with(start: 2026, last: 2027) do |p|
      p.assumptions << Lifeplan::Records::Assumption.from_hash({
        "id" => "inflation", "name" => "Inflation", "value" => 0.1,
      })
      p.expenses << expense(amount: 1_000_000, growth: "inflation", from: 2026, to: 2027)
    end

    result = described_class.new(project).call
    expect(result.years[0].expense).to(eq(1_000_000))
    expect(result.years[1].expense).to(eq(1_100_000))
  end

  it "applies lifestage transitions to expense amount and resets growth base year" do
    project = project_with(start: 2026, last: 2034) do |p|
      p.expenses << expense(
        amount: 6_400_000,
        from: 2026,
        to: 2034,
        growth: 0.1,
        transitions: [
          { "year" => 2033, "amount" => 5_400_000, "label" => "child independence" },
        ],
      )
    end

    result = described_class.new(project).call
    expect(result.years[0].expense).to(eq(6_400_000))
    expect(result.years[6].expense).to(eq((6_400_000 * 1.1**6).round))
    expect(result.years[7].expense).to(eq(5_400_000))
    expect(result.years[8].expense).to(eq((5_400_000 * 1.1).round))
  end

  it "transition growth override takes precedence over expense growth" do
    project = project_with(start: 2026, last: 2028) do |p|
      p.expenses << expense(
        amount: 1_000_000,
        from: 2026,
        to: 2028,
        growth: 0.1,
        transitions: [
          { "year" => 2027, "amount" => 500_000, "growth" => 0 },
        ],
      )
    end

    result = described_class.new(project).call
    expect(result.years[1].expense).to(eq(500_000))
    expect(result.years[2].expense).to(eq(500_000))
  end

  it "compounds asset returns and includes net cashflow in cash pool" do
    project = project_with(start: 2026, last: 2027) do |p|
      p.assets << asset(amount: 1_000_000, return: 0.05)
    end

    result = described_class.new(project).call
    expect(result.years[0].asset_balance).to(eq(1_000_000))
    expect(result.years[1].asset_balance).to(eq(1_050_000))
  end

  it "amortizes a liability with explicit yearly payment" do
    project = project_with(start: 2026, last: 2030) do |p|
      p.liabilities << Lifeplan::Records::Liability.from_hash({
        "id" => "loan",
        "name" => "Loan",
        "principal" => 1_000_000,
        "rate" => 0,
        "from" => 2026,
        "to" => 2030,
        "payment" => 200_000,
        "frequency" => "yearly",
      })
    end

    result = described_class.new(project).call
    expect(result.years.last.liability_balance).to(eq(0))
  end

  it "captures one-time event expenses" do
    project = project_with(start: 2026, last: 2030) do |p|
      p.events << Lifeplan::Records::Event.from_hash({
        "id" => "uni",
        "name" => "Univ",
        "year" => 2028,
        "amount" => 1_000_000,
        "impact_type" => "expense",
      })
    end

    result = described_class.new(project).call
    expect(result.years[2].event_expense).to(eq(1_000_000))
    expect(result.years[2].net_cashflow).to(eq(-1_000_000))
  end

  it "routes expense contributions into the named asset" do
    project = project_with(start: 2026, last: 2027) do |p|
      p.incomes << income(amount: 300_000, from: 2026, to: 2027)
      p.expenses << expense(
        id: "nisa_in", amount: 100_000, from: 2026, to: 2027, contribute_to: "nisa",
      )
      p.assets << asset(id: "cash", amount: 0, return: 0, category: "cash")
      p.assets << asset(id: "nisa", amount: 0, return: 0)
    end

    result = described_class.new(project).call
    year1 = result.years[0]
    year2 = result.years[1]
    expect(year1.expense).to(eq(100_000))
    expect(year1.net_cashflow).to(eq(200_000))
    expect(year1.asset_balance).to(eq(300_000))
    expect(year2.asset_balance).to(eq(600_000))
  end

  it "income contributions accrue to the asset without inflating cashflow" do
    project = project_with(start: 2026, last: 2026) do |p|
      p.incomes << income(
        id: "match", amount: 50_000, from: 2026, to: 2026, contribute_to: "dc",
      )
      p.assets << asset(id: "dc", amount: 0, return: 0)
    end

    result = described_class.new(project).call
    row = result.years.first
    expect(row.income).to(eq(0))
    expect(row.net_cashflow).to(eq(0))
    expect(row.asset_balance).to(eq(50_000))
  end

  it "applies asset_change events to the target asset" do
    project = project_with(start: 2026, last: 2026) do |p|
      p.assets << asset(id: "cash", amount: 1_000_000, return: 0)
      p.events << Lifeplan::Records::Event.from_hash({
        "id" => "windfall",
        "name" => "Windfall",
        "year" => 2026,
        "amount" => 500_000,
        "impact_type" => "asset_change",
        "target_asset_id" => "cash",
      })
    end

    result = described_class.new(project).call
    expect(result.years.first.asset_balance).to(eq(1_500_000))
    expect(result.years.first.net_cashflow).to(eq(0))
  end

  it "applies asset_disposal events: zeros the target, credits proceeds, and tracks book-value loss" do
    project = project_with(start: 2026, last: 2026) do |p|
      p.assets << asset(id: "cash", amount: 0, return: 0, category: "cash")
      p.assets << asset(id: "mother-condo", amount: 24_650_000, return: 0, category: "real_estate")
      p.events << Lifeplan::Records::Event.from_hash({
        "id" => "condo-sale",
        "name" => "Condo sale",
        "year" => 2026,
        "impact_type" => "asset_disposal",
        "target_asset_id" => "mother-condo",
        "proceeds" => 10_000_000,
        "proceeds_to_asset" => "cash",
      })
    end

    result = described_class.new(project, include_details: true).call
    row = result.years.first
    expect(row.net_cashflow).to(eq(0))
    expect(row.asset_balance).to(eq(10_000_000))
    expect(row.details["assets"]).to(include("cash" => 10_000_000, "mother-condo" => 0))
    disposal = row.details["asset_disposals"].first
    expect(disposal).to(include(
      "event_id" => "condo-sale",
      "asset_id" => "mother-condo",
      "proceeds_to" => "cash",
      "proceeds" => 10_000_000,
      "book_value" => 24_650_000,
      "book_value_loss" => 14_650_000,
    ))
  end

  it "defaults asset_disposal proceeds destination to the cash-category asset" do
    project = project_with(start: 2026, last: 2026) do |p|
      p.assets << asset(id: "wallet", amount: 0, return: 0, category: "cash")
      p.assets << asset(id: "stocks", amount: 5_000_000, return: 0, category: "securities")
      p.events << Lifeplan::Records::Event.from_hash({
        "id" => "liquidation",
        "name" => "Liquidation",
        "year" => 2026,
        "impact_type" => "asset_disposal",
        "target_asset_id" => "stocks",
        "proceeds" => 4_800_000,
      })
    end

    result = described_class.new(project, include_details: true).call
    expect(result.years.first.details["assets"]).to(include("wallet" => 4_800_000, "stocks" => 0))
    expect(result.years.first.details["asset_disposals"].first).to(include("proceeds_to" => "wallet"))
  end

  it "passes through asset_disposal costs into details" do
    project = project_with(start: 2026, last: 2026) do |p|
      p.assets << asset(id: "cash", amount: 0, return: 0, category: "cash")
      p.assets << asset(id: "condo", amount: 24_650_000, return: 0, category: "real_estate")
      p.events << Lifeplan::Records::Event.from_hash({
        "id" => "sale",
        "name" => "Sale",
        "year" => 2026,
        "impact_type" => "asset_disposal",
        "target_asset_id" => "condo",
        "proceeds" => 10_000_000,
        "proceeds_to_asset" => "cash",
        "costs" => {
          "broker_fee" => 870_000,
          "co_owner_share" => 4_350_000,
        },
      })
    end

    result = described_class.new(project, include_details: true).call
    disposal = result.years.first.details["asset_disposals"].first
    expect(disposal["costs"]).to(eq({ "broker_fee" => 870_000, "co_owner_share" => 4_350_000 }))
  end

  it "withdraws from investment assets when cash goes negative" do
    project = project_with(start: 2026, last: 2026) do |p|
      p.assumptions << Lifeplan::Records::Assumption.from_hash({
        "id" => "withdrawal_order",
        "name" => "Order",
        "value" => ["mutual"],
      })
      p.expenses << expense(amount: 600_000, from: 2026, to: 2026)
      p.assets << asset(id: "cash", amount: 0, return: 0, category: "cash")
      p.assets << asset(id: "mutual", amount: 1_000_000, return: 0, category: "investment")
    end

    result = described_class.new(project).call
    row = result.years.first
    expect(row.net_cashflow).to(eq(-600_000))
    expect(row.asset_balance).to(eq(400_000))
    expect(result.warnings).to(be_empty)
  end

  it "warns when withdrawal sources are exhausted" do
    project = project_with(start: 2026, last: 2026) do |p|
      p.assumptions << Lifeplan::Records::Assumption.from_hash({
        "id" => "withdrawal_order",
        "name" => "Order",
        "value" => ["mutual"],
      })
      p.expenses << expense(amount: 600_000, from: 2026, to: 2026)
      p.assets << asset(id: "cash", amount: 0, return: 0, category: "cash")
      p.assets << asset(id: "mutual", amount: 100_000, return: 0, category: "investment")
    end

    result = described_class.new(project).call
    expect(result.warnings).to(include(a_hash_including("year" => 2026, "code" => "WITHDRAWAL_SHORTFALL")))
  end

  it "include_details exposes per-asset balances on each year" do
    project = project_with(start: 2026, last: 2026) do |p|
      p.assets << asset(id: "cash", amount: 1_000_000, return: 0)
      p.assets << asset(id: "mutual", amount: 2_000_000, return: 0)
    end

    result = described_class.new(project, include_details: true).call
    details = result.years.first.details
    expect(details).to(include("assets"))
    expect(details["assets"]).to(include("cash" => 1_000_000, "mutual" => 2_000_000))
  end

  it "transfers periodic contributions between assets without touching cashflow" do
    project = project_with(start: 2026, last: 2027) do |p|
      p.assets << asset(id: "cash", amount: 5_000_000, return: 0, category: "cash")
      p.assets << asset(id: "mutual-funds", amount: 0, return: 0)
      p.contributions << Lifeplan::Records::Contribution.from_hash({
        "id" => "nisa",
        "name" => "NISA",
        "amount" => 1_200_000,
        "frequency" => "yearly",
        "from" => 2026,
        "to" => 2027,
        "from_asset" => "cash",
        "to_asset" => "mutual-funds",
        "tax_treatment" => "nisa",
      })
    end

    result = described_class.new(project, include_details: true).call
    year1 = result.years[0]
    expect(year1.net_cashflow).to(eq(0))
    expect(year1.details["assets"]).to(include("cash" => 3_800_000, "mutual-funds" => 1_200_000))
    contribution = year1.details["contributions"].find { |c| c["record_id"] == "nisa" }
    expect(contribution).to(include(
      "from_asset" => "cash",
      "to_asset" => "mutual-funds",
      "amount" => 1_200_000,
      "tax_treatment" => "nisa",
    ))

    year2 = result.years[1]
    expect(year2.details["assets"]).to(include("cash" => 2_600_000, "mutual-funds" => 2_400_000))
  end

  it "treats monthly contribution amounts as annualized" do
    project = project_with(start: 2026, last: 2026) do |p|
      p.assets << asset(id: "cash", amount: 1_000_000, return: 0, category: "cash")
      p.assets << asset(id: "dc-pension", amount: 0, return: 0)
      p.contributions << Lifeplan::Records::Contribution.from_hash({
        "id" => "ideco",
        "name" => "iDeCo",
        "amount" => 23_000,
        "frequency" => "monthly",
        "from" => 2026,
        "to" => 2026,
        "from_asset" => "cash",
        "to_asset" => "dc-pension",
      })
    end

    result = described_class.new(project, include_details: true).call
    expect(result.years.first.details["assets"]).to(include("dc-pension" => 276_000))
  end

  it "supports one-time 'all' transfers (e.g. DC pension lump-sum)" do
    project = project_with(start: 2026, last: 2027) do |p|
      p.assets << asset(id: "cash", amount: 0, return: 0, category: "cash")
      p.assets << asset(id: "dc-pension", amount: 5_000_000, return: 0)
      p.contributions << Lifeplan::Records::Contribution.from_hash({
        "id" => "dc-lumpsum",
        "name" => "DC Lump Sum",
        "amount" => "all",
        "year" => 2027,
        "from_asset" => "dc-pension",
        "to_asset" => "cash",
        "tax_treatment" => "retirement_income",
      })
    end

    result = described_class.new(project, include_details: true).call
    expect(result.years[0].details["assets"]).to(include("dc-pension" => 5_000_000, "cash" => 0))
    expect(result.years[1].details["assets"]).to(include("dc-pension" => 0, "cash" => 5_000_000))
  end

  def person(**attrs)
    Lifeplan::Records::Person.from_hash({
      "id" => "p", "name" => "P", "relationship" => "other",
    }.merge(attrs.transform_keys(&:to_s)))
  end

  def profile_with(people)
    Lifeplan::Records::Profile.from_hash({
      "id" => "h", "name" => "H", "people" => people,
    })
  end

  it "per_person is nil when include_per_person is false (default)" do
    project = project_with(start: 2026, last: 2026) do |p|
      p.incomes << income(amount: 1_000_000, from: 2026, to: 2026)
    end
    result = described_class.new(project).call
    expect(result.years.first.per_person).to(be_nil)
  end

  it "per_person buckets income, expense, and assets by person_id" do
    project = project_with(start: 2026, last: 2026) do |p|
      p.profile = profile_with([person(id: "self"), person(id: "spouse")])
      p.incomes << income(id: "salary", amount: 9_600_000, from: 2026, to: 2026, person_id: "self")
      p.incomes << income(id: "side", amount: 1_200_000, from: 2026, to: 2026, person_id: "spouse")
      p.expenses << expense(id: "self-tax", amount: 2_100_000, from: 2026, to: 2026, person_id: "self")
      p.expenses << expense(id: "spouse-misc", amount: 900_000, from: 2026, to: 2026, person_id: "spouse")
      p.expenses << expense(id: "shared", amount: 1_200_000, from: 2026, to: 2026)
      p.assets << asset(id: "self-cash", amount: 0, return: 0, category: "cash", person_id: "self")
      p.assets << asset(id: "spouse-cash", amount: 8_000_000, return: 0, person_id: "spouse")
      p.assets << asset(id: "joint", amount: 2_000_000, return: 0)
    end

    result = described_class.new(project, include_per_person: true).call
    pp = result.years.first.per_person
    expect(pp.keys).to(contain_exactly("self", "spouse", "_shared"))
    expect(pp["self"]["income"]).to(eq(9_600_000))
    expect(pp["spouse"]["income"]).to(eq(1_200_000))
    expect(pp["_shared"]["income"]).to(eq(0))
    expect(pp["self"]["expense"]).to(eq(2_100_000))
    expect(pp["spouse"]["expense"]).to(eq(900_000))
    expect(pp["_shared"]["expense"]).to(eq(1_200_000))

    household = result.years.first
    expect(pp.values.sum { |v| v["income"] }).to(eq(household.income))
    expect(pp.values.sum { |v| v["expense"] }).to(eq(household.expense))
    expect(pp.values.sum { |v| v["asset_balance"] }).to(eq(household.asset_balance))
    expect(pp.values.sum { |v| v["net_worth"] }).to(eq(household.net_worth))
  end

  it "per_person buckets event income/expense by event.person_id" do
    project = project_with(start: 2026, last: 2026) do |p|
      p.profile = profile_with([person(id: "self"), person(id: "spouse")])
      p.events << Lifeplan::Records::Event.from_hash({
        "id" => "bonus",
        "name" => "Bonus",
        "year" => 2026,
        "amount" => 500_000,
        "impact_type" => "income",
        "person_id" => "spouse",
      })
    end

    result = described_class.new(project, include_per_person: true).call
    pp = result.years.first.per_person
    expect(pp["spouse"]["income"]).to(eq(500_000))
    expect(pp["self"]["income"]).to(eq(0))
  end

  it "per_person includes a zero row for every profile.people[*].id" do
    project = project_with(start: 2026, last: 2026) do |p|
      p.profile = profile_with([person(id: "self"), person(id: "spouse")])
      p.incomes << income(amount: 1_000_000, from: 2026, to: 2026, person_id: "self")
    end
    result = described_class.new(project, include_per_person: true).call
    pp = result.years.first.per_person
    expect(pp["spouse"]).to(eq({
      "income" => 0, "expense" => 0, "asset_balance" => 0, "liability_balance" => 0, "net_worth" => 0,
    }))
  end

  it "per_person rolls liabilities into _shared (LIABILITY has no person_id today)" do
    project = project_with(start: 2026, last: 2026) do |p|
      p.profile = profile_with([person(id: "self")])
      p.liabilities << Lifeplan::Records::Liability.from_hash({
        "id" => "loan",
        "name" => "Loan",
        "principal" => 1_000_000,
        "rate" => 0,
        "from" => 2026,
        "to" => 2026,
        "payment" => 1_000_000,
        "frequency" => "yearly",
      })
    end
    result = described_class.new(project, include_per_person: true).call
    pp = result.years.first.per_person
    expect(pp["_shared"]["liability_balance"]).to(eq(result.years.first.liability_balance))
    expect(pp["self"]["liability_balance"]).to(eq(0))
  end

  it "summary tracks min, retirement, and totals" do
    project = project_with(start: 2026, last: 2030) do |p|
      person = Lifeplan::Records::Person.from_hash({
        "id" => "self",
        "name" => "Self",
        "relationship" => "self",
        "birth_year" => 1980,
        "retirement_age" => 50,
      })
      p.profile = Lifeplan::Records::Profile.from_hash({
        "id" => "h", "name" => "H", "people" => [person],
      })
      p.expenses << expense(amount: 100_000, from: 2026, to: 2030)
      p.assets << asset(amount: 1_000_000)
    end

    result = described_class.new(project).call
    expect(result.summary.retirement_year).to(eq(2030))
    expect(result.summary.total_expense).to(eq(500_000))
    expect(result.summary.minimum_asset_balance).to(eq(result.years.last.asset_balance))
  end
end
