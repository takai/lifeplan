# frozen_string_literal: true

require "json"
require "lifeplan/cli"

RSpec.describe(Lifeplan::CLI) do
  describe "version" do
    it "prints the gem version" do
      expect { described_class.start(["version"]) }.to(output("#{Lifeplan::VERSION}\n").to_stdout)
    end

    it "is reachable via --version" do
      expect { described_class.start(["--version"]) }.to(output("#{Lifeplan::VERSION}\n").to_stdout)
    end
  end

  describe "init" do
    it "creates a project file" do
      with_tmp_project do |dir|
        expect do
          described_class.start([
            "init",
            dir,
            "--name",
            "Test Plan",
            "--start-year",
            "2026",
            "--end-year",
            "2065",
            "--currency",
            "JPY",
          ])
        end.to(output(/Initialized project/).to_stdout)
        expect(File.exist?(File.join(dir, "project.json"))).to(be(true))
      end
    end

    it "scaffolds the financial-planner persona and skills" do
      with_tmp_project do |dir|
        described_class.start(["init", dir, "--name", "Scaffold Plan"])

        expect(File.exist?(File.join(dir, "CLAUDE.md"))).to(be(true))
        expect(File.exist?(File.join(dir, ".claude/skills/fp-intake/SKILL.md"))).to(be(true))
        expect(File.exist?(File.join(dir, ".claude/skills/fp-scenarios/SKILL.md"))).to(be(true))
        expect(File.exist?(File.join(dir, ".claude/skills/fp-analysis/SKILL.md"))).to(be(true))
      end
    end

    it "does not copy internal developer docs into the workspace" do
      with_tmp_project do |dir|
        described_class.start(["init", dir, "--name", "No Internal Docs"])

        expect(File.exist?(File.join(dir, "docs/prd.md"))).to(be(false))
        expect(File.exist?(File.join(dir, "docs/cli.md"))).to(be(false))
        expect(File.exist?(File.join(dir, "docs/datamodel.md"))).to(be(false))
      end
    end

    it "copies templates verbatim from the gem" do
      with_tmp_project do |dir|
        described_class.start(["init", dir, "--name", "Verbatim Plan"])

        gem_claude_md = File.read(File.join(Lifeplan::ROOT, "templates/CLAUDE.md"))
        copied_claude_md = File.read(File.join(dir, "CLAUDE.md"))
        expect(copied_claude_md).to(eq(gem_claude_md))
      end
    end

    it "does not leave the legacy developer-oriented skills behind" do
      with_tmp_project do |dir|
        described_class.start(["init", dir, "--name", "No Legacy Skills"])

        expect(File.exist?(File.join(dir, ".claude/skills/lifeplan-product/SKILL.md"))).to(be(false))
        expect(File.exist?(File.join(dir, ".claude/skills/lifeplan-cli/SKILL.md"))).to(be(false))
        expect(File.exist?(File.join(dir, ".claude/skills/lifeplan-data/SKILL.md"))).to(be(false))
      end
    end

    it "rejects re-initialization" do
      with_tmp_project do |dir|
        described_class.start(["init", dir, "--name", "First"])
        expect do
          described_class.start(["init", dir, "--name", "Second"])
        end.to(raise_error(SystemExit) | output(/already exists/).to_stderr)
      end
    end
  end

  describe "status" do
    it "shows project info as text" do
      with_tmp_project do |dir|
        described_class.start([
          "init",
          dir,
          "--name",
          "Status Plan",
          "--start-year",
          "2026",
          "--end-year",
          "2030",
        ])
        expect do
          described_class.start(["status", "--project", dir])
        end.to(output(/Status Plan/).to_stdout)
      end
    end

    it "emits json envelope" do
      with_tmp_project do |dir|
        described_class.start(["init", dir, "--name", "JSON Plan"])
        captured = capture_stdout do
          described_class.start(["status", "--project", dir, "--format", "json"])
        end
        envelope = JSON.parse(captured)
        expect(envelope.keys).to(include("data", "warnings", "errors", "metadata"))
        expect(envelope["data"]["name"]).to(eq("JSON Plan"))
      end
    end
  end

  describe "schema" do
    it "lists record types when called bare" do
      expect { described_class.start(["schema"]) }.to(output(/income/).to_stdout)
    end

    it "shows fields for a type as json" do
      captured = capture_stdout do
        described_class.start(["schema", "income", "--format", "json"])
      end
      envelope = JSON.parse(captured)
      names = envelope["data"]["fields"].map { |f| f["name"] }
      expect(names).to(include("id", "amount", "frequency"))
    end
  end

  describe "list and get" do
    it "lists empty incomes after init" do
      with_tmp_project do |dir|
        described_class.start(["init", dir, "--name", "Plan"])
        expect do
          described_class.start(["list", "income", "--project", dir])
        end.to(output(/No income records/).to_stdout)
      end
    end

    it "raises RecordNotFound for missing id" do
      with_tmp_project do |dir|
        described_class.start(["init", dir, "--name", "Plan"])
        expect do
          described_class.start(["get", "income", "missing", "--project", dir])
        end.to(raise_error(SystemExit))
      end
    end
  end

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end
