# frozen_string_literal: true

require "thor"
require "lifeplan/version"

module Lifeplan
  class CLI < Thor
    class << self
      def exit_on_failure?
        true
      end
    end

    map ["--version", "-v"] => :version

    desc "version", "Show version"
    def version
      puts Lifeplan::VERSION
    end
  end
end
