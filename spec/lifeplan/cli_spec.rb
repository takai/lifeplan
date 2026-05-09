# frozen_string_literal: true

require "lifeplan/cli"

RSpec.describe(Lifeplan::CLI) do
  describe "version command" do
    it "prints the gem version" do
      expect { described_class.start(["version"]) }.to(output("#{Lifeplan::VERSION}\n").to_stdout)
    end

    it "is reachable via --version" do
      expect { described_class.start(["--version"]) }.to(output("#{Lifeplan::VERSION}\n").to_stdout)
    end
  end
end
