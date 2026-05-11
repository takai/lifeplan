# frozen_string_literal: true

require "json"
require "stringio"
require "lifeplan/cli"
require "lifeplan/version"

RSpec.describe("upgrade command") do
  let(:cli) { Lifeplan::CLI }

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
end
