# frozen_string_literal: true

require "json"
require "lifeplan/cli"

RSpec.describe("mutation commands") do
  let(:cli) { Lifeplan::CLI }

  def init(dir)
    cli.start(["init", dir, "--name", "Plan", "--start-year", "2026", "--end-year", "2065"])
  end

  describe "add" do
    it "adds an income record and persists it" do
      with_tmp_project do |dir|
        init(dir)
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
          "9600000",
          "--frequency",
          "yearly",
          "--from",
          "2026",
          "--to",
          "2045",
        ])

        project = Lifeplan::Project.load(dir)
        income = project.find("income", "salary")
        expect(income.amount).to(eq(9_600_000))
        expect(income.from).to(eq(2026))
      end
    end

    it "rejects duplicate ids" do
      with_tmp_project do |dir|
        init(dir)
        cli.start([
          "add",
          "income",
          "--project",
          dir,
          "--id",
          "s",
          "--name",
          "S",
          "--amount",
          "100",
          "--frequency",
          "yearly",
        ])
        expect do
          cli.start([
            "add",
            "income",
            "--project",
            dir,
            "--id",
            "s",
            "--name",
            "S",
            "--amount",
            "200",
            "--frequency",
            "yearly",
          ])
        end.to(raise_error(SystemExit))
      end
    end

    it "supports --dry-run without writing" do
      with_tmp_project do |dir|
        init(dir)
        cli.start([
          "add",
          "expense",
          "--project",
          dir,
          "--dry-run",
          "--id",
          "living",
          "--name",
          "Living",
          "--amount",
          "4200000",
          "--frequency",
          "yearly",
          "--from",
          "2026",
          "--to",
          "2065",
        ])
        expect(Lifeplan::Project.load(dir).expenses).to(be_empty)
      end
    end

    it "requires --id and --name" do
      with_tmp_project do |dir|
        init(dir)
        expect do
          cli.start(["add", "income", "--project", dir, "--amount", "1", "--frequency", "yearly"])
        end.to(raise_error(SystemExit))
      end
    end
  end

  describe "set" do
    it "updates a single field" do
      with_tmp_project do |dir|
        init(dir)
        cli.start([
          "add",
          "income",
          "--project",
          dir,
          "--id",
          "s",
          "--name",
          "S",
          "--amount",
          "100",
          "--frequency",
          "yearly",
        ])
        cli.start(["set", "income", "s", "amount", "200", "--project", dir])
        expect(Lifeplan::Project.load(dir).find("income", "s").amount).to(eq(200))
      end
    end

    it "raises RecordNotFound for missing id" do
      with_tmp_project do |dir|
        init(dir)
        expect do
          cli.start(["set", "income", "missing", "amount", "1", "--project", dir])
        end.to(raise_error(SystemExit))
      end
    end
  end

  describe "remove" do
    it "removes a record" do
      with_tmp_project do |dir|
        init(dir)
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
          "1000",
          "--as-of",
          "2026-05-10",
        ])
        cli.start(["remove", "asset", "cash", "--project", dir])
        expect(Lifeplan::Project.load(dir).assets).to(be_empty)
      end
    end

    it "honors --dry-run" do
      with_tmp_project do |dir|
        init(dir)
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
          "1000",
          "--as-of",
          "2026-05-10",
        ])
        cli.start(["remove", "asset", "cash", "--project", dir, "--dry-run"])
        expect(Lifeplan::Project.load(dir).assets.size).to(eq(1))
      end
    end
  end
end
