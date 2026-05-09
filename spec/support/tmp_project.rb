# frozen_string_literal: true

require "fileutils"
require "tmpdir"

module TmpProject
  def with_tmp_project(&block)
    Dir.mktmpdir("lifeplan-spec", &block)
  end
end

RSpec.configure do |config|
  config.include(TmpProject)
end
