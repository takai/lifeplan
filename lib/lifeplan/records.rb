# frozen_string_literal: true

require "lifeplan/records/base"
require "lifeplan/schema"

module Lifeplan
  module Records
    Profile = Base.define("profile", Schema::PROFILE)
    Person = Base.define("person", Schema::PERSON)
    Income = Base.define("income", Schema::INCOME)
    Expense = Base.define("expense", Schema::EXPENSE)
    Asset = Base.define("asset", Schema::ASSET)
    Liability = Base.define("liability", Schema::LIABILITY)
    Event = Base.define("event", Schema::EVENT)
    Contribution = Base.define("contribution", Schema::CONTRIBUTION)
    Assumption = Base.define("assumption", Schema::ASSUMPTION)
    Scenario = Base.define("scenario", Schema::SCENARIO)

    BY_TYPE = {
      "profile" => Profile,
      "person" => Person,
      "income" => Income,
      "expense" => Expense,
      "asset" => Asset,
      "liability" => Liability,
      "event" => Event,
      "contribution" => Contribution,
      "assumption" => Assumption,
      "scenario" => Scenario,
    }.freeze

    class << self
      def class_for(type)
        BY_TYPE.fetch(Schema.canonical(type))
      end
    end
  end
end
