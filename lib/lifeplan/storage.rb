# frozen_string_literal: true

require "json"
require "fileutils"
require "tempfile"
require "lifeplan/errors"

module Lifeplan
  module Storage
    PROJECT_FILE = "project.json"

    extend self

    def project_file(path)
      File.join(path, PROJECT_FILE)
    end

    def exist?(path)
      File.file?(project_file(path))
    end

    def read(path)
      raise ProjectNotFound, "Project not found at #{path}" unless exist?(path)

      JSON.parse(File.read(project_file(path)))
    rescue JSON::ParserError => e
      raise InvalidProject, "Invalid project file at #{path}: #{e.message}"
    end

    def write(path, data)
      FileUtils.mkdir_p(path)
      target = project_file(path)
      tmp = Tempfile.new(["project", ".json"], path)
      begin
        tmp.write(JSON.pretty_generate(data))
        tmp.write("\n")
        tmp.close
        File.rename(tmp.path, target)
      ensure
        tmp.close unless tmp.closed?
        File.unlink(tmp.path) if File.exist?(tmp.path)
      end
    end
  end
end
