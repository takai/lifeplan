# frozen_string_literal: true

require "lifeplan/exit_codes"

module Lifeplan
  class Error < StandardError
    def exit_code
      ExitCodes::GENERAL_ERROR
    end
  end

  class ProjectNotFound < Error
    def exit_code
      ExitCodes::PROJECT_NOT_FOUND
    end
  end

  class InvalidProject < Error
    def exit_code
      ExitCodes::PROJECT_NOT_FOUND
    end
  end

  class RecordNotFound < Error
    def exit_code
      ExitCodes::RECORD_NOT_FOUND
    end
  end

  class ScenarioNotFound < Error
    def exit_code
      ExitCodes::SCENARIO_NOT_FOUND
    end
  end

  class ValidationFailed < Error
    def exit_code
      ExitCodes::VALIDATION_FAILED
    end
  end

  class InvalidArguments < Error
    def exit_code
      ExitCodes::INVALID_ARGUMENTS
    end
  end
end
