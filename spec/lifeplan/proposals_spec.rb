# frozen_string_literal: true

require "json"
require "stringio"
require "lifeplan/cli"

RSpec.describe("proposal commands") do
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
  end

  def capture
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  it "propose set persists a pending proposal without mutating data" do
    with_tmp_project do |dir|
      init(dir)
      cli.start([
        "propose",
        "set",
        "income",
        "salary",
        "amount",
        "1500000",
        "--project",
        dir,
        "--id",
        "p1",
      ])
      project = Lifeplan::Project.load(dir)
      expect(project.proposals.size).to(eq(1))
      expect(project.proposals.first["status"]).to(eq("pending"))
      expect(project.find("income", "salary").amount).to(eq(1_000_000))
    end
  end

  it "apply mutates and marks proposal applied" do
    with_tmp_project do |dir|
      init(dir)
      cli.start([
        "propose",
        "set",
        "income",
        "salary",
        "amount",
        "1500000",
        "--project",
        dir,
        "--id",
        "p1",
      ])
      cli.start(["apply", "p1", "--project", dir])
      project = Lifeplan::Project.load(dir)
      expect(project.find("income", "salary").amount).to(eq(1_500_000))
      expect(project.proposals.first["status"]).to(eq("applied"))
    end
  end

  it "apply --dry-run leaves project unchanged" do
    with_tmp_project do |dir|
      init(dir)
      cli.start([
        "propose",
        "set",
        "income",
        "salary",
        "amount",
        "1500000",
        "--project",
        dir,
        "--id",
        "p1",
      ])
      cli.start(["apply", "p1", "--project", dir, "--dry-run"])
      project = Lifeplan::Project.load(dir)
      expect(project.find("income", "salary").amount).to(eq(1_000_000))
      expect(project.proposals.first["status"]).to(eq("pending"))
    end
  end

  it "discard marks proposal as discarded" do
    with_tmp_project do |dir|
      init(dir)
      cli.start([
        "propose",
        "set",
        "income",
        "salary",
        "amount",
        "1500000",
        "--project",
        dir,
        "--id",
        "p1",
      ])
      cli.start(["discard", "p1", "--project", dir])
      project = Lifeplan::Project.load(dir)
      expect(project.proposals.first["status"]).to(eq("discarded"))
    end
  end

  it "apply detects stale proposals" do
    with_tmp_project do |dir|
      init(dir)
      cli.start([
        "propose",
        "set",
        "income",
        "salary",
        "amount",
        "1500000",
        "--project",
        dir,
        "--id",
        "p1",
      ])
      cli.start(["set", "income", "salary", "amount", "1200000", "--project", dir])
      expect { cli.start(["apply", "p1", "--project", dir]) }
        .to(raise_error(SystemExit) { |e| expect(e.status).to(eq(7)) })
    end
  end

  it "diff --proposal shows the change" do
    with_tmp_project do |dir|
      init(dir)
      cli.start([
        "propose",
        "set",
        "income",
        "salary",
        "amount",
        "1500000",
        "--project",
        dir,
        "--id",
        "p1",
      ])
      out = capture { cli.start(["diff", "--proposal", "p1", "--project", dir]) }
      expect(out).to(include("salary"))
      expect(out).to(include("1500000"))
    end
  end

  it "proposals lists pending proposals" do
    with_tmp_project do |dir|
      init(dir)
      cli.start([
        "propose",
        "set",
        "income",
        "salary",
        "amount",
        "1500000",
        "--project",
        dir,
        "--id",
        "p1",
      ])
      out = capture { cli.start(["proposals", "--project", dir]) }
      expect(out).to(include("p1"))
      expect(out).to(include("pending"))
    end
  end

  it "propose add stages a new record without applying" do
    with_tmp_project do |dir|
      init(dir)
      cli.start([
        "propose",
        "add",
        "expense",
        "--project",
        dir,
        "--id",
        "p1",
        "--id",
        "living",
        "--name",
        "Living",
        "--amount",
        "200000",
        "--frequency",
        "yearly",
        "--from",
        "2026",
        "--to",
        "2028",
      ])
      project = Lifeplan::Project.load(dir)
      expect(project.expenses).to(be_empty)
      expect(project.proposals.size).to(eq(1))
    end
  end
end
