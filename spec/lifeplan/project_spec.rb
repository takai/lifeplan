# frozen_string_literal: true

require "json"
require "lifeplan/project"

RSpec.describe(Lifeplan::Project) do
  it "saves and reloads a project" do
    with_tmp_project do |dir|
      project = described_class.new(
        path: dir, id: "p", name: "P", currency: "JPY", start_year: 2026, end_year: 2065,
      )
      project.profile = Lifeplan::Records::Profile.from_hash(
        "id" => "default", "name" => "Default", "people" => [],
      )
      project.save

      reloaded = described_class.load(dir)
      expect(reloaded.id).to(eq("p"))
      expect(reloaded.start_year).to(eq(2026))
      expect(reloaded.profile.name).to(eq("Default"))
    end
  end

  it "raises ProjectNotFound when missing" do
    with_tmp_project do |dir|
      expect { described_class.load(dir) }.to(raise_error(Lifeplan::ProjectNotFound))
    end
  end

  it "round-trips records through JSON" do
    with_tmp_project do |dir|
      project = described_class.new(
        path: dir, id: "p", name: "P", currency: "JPY", start_year: 2026, end_year: 2065,
      )
      project.incomes = [
        Lifeplan::Records::Income.from_hash(
          "id" => "salary",
          "name" => "Salary",
          "amount" => 9_600_000,
          "frequency" => "yearly",
          "from" => 2026,
          "to" => 2045,
        ),
      ]
      project.save

      json = JSON.parse(File.read(File.join(dir, "project.json")))
      expect(json["incomes"].first["id"]).to(eq("salary"))
      expect(described_class.load(dir).incomes.first.amount).to(eq(9_600_000))
    end
  end

  it "round-trips household_aggregation through JSON" do
    with_tmp_project do |dir|
      project = described_class.new(
        path: dir, id: "p", name: "P", currency: "JPY", start_year: 2026, end_year: 2027,
      )
      project.household_aggregation = "merged"
      project.save

      json = JSON.parse(File.read(File.join(dir, "project.json")))
      expect(json["household_aggregation"]).to(eq("merged"))
      expect(described_class.load(dir).household_aggregation).to(eq("merged"))
    end
  end

  it "omits household_aggregation from JSON when unset" do
    with_tmp_project do |dir|
      project = described_class.new(
        path: dir, id: "p", name: "P", currency: "JPY", start_year: 2026, end_year: 2027,
      )
      project.save

      json = JSON.parse(File.read(File.join(dir, "project.json")))
      expect(json).not_to(have_key("household_aggregation"))
      expect(described_class.load(dir).household_aggregation).to(be_nil)
    end
  end

  it "looks up records by id" do
    with_tmp_project do |dir|
      project = described_class.new(path: dir)
      project.assets = [
        Lifeplan::Records::Asset.from_hash(
          "id" => "cash", "name" => "Cash", "amount" => 1_000_000, "as_of" => "2026-05-10",
        ),
      ]
      expect(project.find("asset", "cash").name).to(eq("Cash"))
      expect { project.find("asset", "missing") }.to(raise_error(Lifeplan::RecordNotFound))
    end
  end
end
