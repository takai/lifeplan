# frozen_string_literal: true

require "fileutils"
require "json"
require "stringio"
require "lifeplan/cli"
require "lifeplan/version"

RSpec.describe("upgrade command") do
  let(:cli) { Lifeplan::CLI }
  let(:legacy_fixture_root) { File.expand_path("../fixtures/legacy_v0.1.0", __dir__) }

  def capture
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  def write_unversioned_project(dir)
    cli.start(["init", dir, "--name", "Plan", "--start-year", "2026", "--end-year", "2027"])
    path = File.join(dir, "project.json")
    data = JSON.parse(File.read(path))
    data.delete("lifeplan_version")
    File.write(path, JSON.pretty_generate(data))
  end

  def write_legacy_project(dir)
    cli.start(["init", dir, "--name", "Legacy Plan", "--start-year", "2026", "--end-year", "2027"])

    # Strip the current-version scaffold so the workspace looks like a v0.1.0
    # install (no fp-* skills, no current CLAUDE.md).
    FileUtils.rm_rf(File.join(dir, ".claude"))
    FileUtils.rm_f(File.join(dir, "CLAUDE.md"))

    # Overlay v0.1.0 fixtures (legacy CLAUDE.md, lifeplan-* skills, docs/).
    Dir.glob(File.join(legacy_fixture_root, "**/*"), File::FNM_DOTMATCH).each do |src|
      next unless File.file?(src)

      rel = src.delete_prefix("#{legacy_fixture_root}/")
      dest = File.join(dir, rel)
      FileUtils.mkdir_p(File.dirname(dest))
      FileUtils.cp(src, dest)
    end

    path = File.join(dir, "project.json")
    data = JSON.parse(File.read(path))
    data["lifeplan_version"] = "0.1.0"
    File.write(path, JSON.pretty_generate(data))
  end

  it "init stamps lifeplan_version on a fresh project" do
    with_tmp_project do |dir|
      cli.start(["init", dir, "--name", "Plan", "--start-year", "2026", "--end-year", "2027"])
      data = JSON.parse(File.read(File.join(dir, "project.json")))
      expect(data["lifeplan_version"]).to(eq(Lifeplan::VERSION))
    end
  end

  it "dry-run by default lists steps but does not modify the workspace" do
    with_tmp_project do |dir|
      write_unversioned_project(dir)
      out = capture do
        cli.start(["upgrade", "--project", dir, "--format", "json"])
      end
      data = JSON.parse(out)["data"]
      expect(data["from"]).to(be_nil)
      expect(data["to"]).to(eq(Lifeplan::VERSION))
      expect(data["dry_run"]).to(be(true))
      expect(data["applied"]).to(be(false))
      expect(data["steps"].first).to(include("path" => "lifeplan_version", "operation" => "add"))

      json = JSON.parse(File.read(File.join(dir, "project.json")))
      expect(json).not_to(have_key("lifeplan_version"))
    end
  end

  it "--apply writes the version stamp" do
    with_tmp_project do |dir|
      write_unversioned_project(dir)
      out = capture do
        cli.start(["upgrade", "--project", dir, "--apply", "--no-dry-run", "--format", "json"])
      end
      data = JSON.parse(out)["data"]
      expect(data["applied"]).to(be(true))

      json = JSON.parse(File.read(File.join(dir, "project.json")))
      expect(json["lifeplan_version"]).to(eq(Lifeplan::VERSION))
    end
  end

  it "reports up_to_date when version already matches" do
    with_tmp_project do |dir|
      cli.start(["init", dir, "--name", "Plan", "--start-year", "2026", "--end-year", "2027"])
      out = capture do
        cli.start(["upgrade", "--project", dir, "--format", "json"])
      end
      data = JSON.parse(out)["data"]
      expect(data["up_to_date"]).to(be(true))
      expect(data["steps"]).to(be_empty)
    end
  end

  describe "0.1.0 -> 0.2.0 template refresh" do
    it "plans file_replace / file_remove / file_add steps in dry-run" do
      with_tmp_project do |dir|
        write_legacy_project(dir)
        out = capture do
          cli.start(["upgrade", "--project", dir, "--format", "json"])
        end
        data = JSON.parse(out)["data"]

        expect(data["from"]).to(eq("0.1.0"))
        expect(data["to"]).to(eq("0.2.0"))
        expect(data["dry_run"]).to(be(true))
        expect(data["applied"]).to(be(false))

        ops = data["steps"].group_by { |s| s["operation"] }.transform_values { |v| v.map { |s| s["path"] } }

        expect(ops["file_replace"]).to(include("CLAUDE.md"))
        expect(ops["file_remove"]).to(include(
          ".claude/skills/lifeplan-product/SKILL.md",
          ".claude/skills/lifeplan-cli/SKILL.md",
          ".claude/skills/lifeplan-data/SKILL.md",
          "docs/prd.md",
          "docs/cli.md",
          "docs/datamodel.md",
        ))
        expect(ops["file_add"]).to(include(
          ".claude/skills/fp-intake/SKILL.md",
          ".claude/skills/fp-scenarios/SKILL.md",
          ".claude/skills/fp-analysis/SKILL.md",
        ))

        # Workspace is unchanged in dry-run.
        expect(File.exist?(File.join(dir, "docs/prd.md"))).to(be(true))
        expect(File.exist?(File.join(dir, ".claude/skills/lifeplan-product/SKILL.md"))).to(be(true))
        expect(File.exist?(File.join(dir, ".claude/skills/fp-intake/SKILL.md"))).to(be(false))
      end
    end

    it "--apply rewrites templates, removes legacy files, and stamps 0.2.0" do
      with_tmp_project do |dir|
        write_legacy_project(dir)
        capture do
          cli.start(["upgrade", "--project", dir, "--apply", "--no-dry-run", "--format", "json"])
        end

        # Legacy skill directories are gone.
        expect(File.exist?(File.join(dir, ".claude/skills/lifeplan-product/SKILL.md"))).to(be(false))
        expect(File.exist?(File.join(dir, ".claude/skills/lifeplan-cli/SKILL.md"))).to(be(false))
        expect(File.exist?(File.join(dir, ".claude/skills/lifeplan-data/SKILL.md"))).to(be(false))

        # Legacy docs are gone.
        expect(File.exist?(File.join(dir, "docs/prd.md"))).to(be(false))
        expect(File.exist?(File.join(dir, "docs/cli.md"))).to(be(false))
        expect(File.exist?(File.join(dir, "docs/datamodel.md"))).to(be(false))

        # New persona skills are present.
        expect(File.exist?(File.join(dir, ".claude/skills/fp-intake/SKILL.md"))).to(be(true))
        expect(File.exist?(File.join(dir, ".claude/skills/fp-scenarios/SKILL.md"))).to(be(true))
        expect(File.exist?(File.join(dir, ".claude/skills/fp-analysis/SKILL.md"))).to(be(true))

        # CLAUDE.md was replaced with the current bundled content.
        bundled = File.read(File.join(Lifeplan::ROOT, "templates/CLAUDE.md"))
        expect(File.read(File.join(dir, "CLAUDE.md"))).to(eq(bundled))

        json = JSON.parse(File.read(File.join(dir, "project.json")))
        expect(json["lifeplan_version"]).to(eq("0.2.0"))
      end
    end

    it "skips files the user has customized and preserves them on disk" do
      with_tmp_project do |dir|
        write_legacy_project(dir)
        custom = "# customized by user\n"
        File.write(File.join(dir, "CLAUDE.md"), custom)

        out = capture do
          cli.start(["upgrade", "--project", dir, "--apply", "--no-dry-run", "--format", "json"])
        end
        data = JSON.parse(out)["data"]

        skip_step = data["steps"].find { |s| s["path"] == "CLAUDE.md" && s["operation"] == "file_skip" }
        expect(skip_step).not_to(be_nil)
        expect(skip_step["severity"]).to(eq("warning"))

        # The user's customization survives the upgrade.
        expect(File.read(File.join(dir, "CLAUDE.md"))).to(eq(custom))

        # Version is still stamped to 0.2.0 (the other files migrated cleanly).
        json = JSON.parse(File.read(File.join(dir, "project.json")))
        expect(json["lifeplan_version"]).to(eq("0.2.0"))
      end
    end
  end
end
