# frozen_string_literal: true

require "lifeplan/records"
require "lifeplan/storage"
require "lifeplan/errors"

module Lifeplan
  class Project
    COLLECTIONS = {
      "incomes" => "income",
      "expenses" => "expense",
      "assets" => "asset",
      "liabilities" => "liability",
      "events" => "event",
      "contributions" => "contribution",
      "assumptions" => "assumption",
      "scenarios" => "scenario",
    }.freeze

    attr_accessor :id,
      :name,
      :currency,
      :start_year,
      :end_year,
      :household_aggregation,
      :profile,
      :incomes,
      :expenses,
      :assets,
      :liabilities,
      :events,
      :contributions,
      :assumptions,
      :scenarios,
      :proposals
    attr_reader :path

    def initialize(path:, id: nil, name: nil, currency: nil, start_year: nil, end_year: nil)
      @path = path
      @id = id
      @name = name
      @currency = currency
      @start_year = start_year
      @end_year = end_year
      @household_aggregation = nil
      @profile = nil
      @incomes = []
      @expenses = []
      @assets = []
      @liabilities = []
      @events = []
      @contributions = []
      @assumptions = []
      @scenarios = []
      @proposals = []
    end

    class << self
      def load(path)
        data = Storage.read(path)
        project = new(
          path: path,
          id: data["id"],
          name: data["name"],
          currency: data["currency"],
          start_year: data["start_year"],
          end_year: data["end_year"],
        )
        project.household_aggregation = data["household_aggregation"]
        project.profile = build_profile(data["profile"]) if data["profile"]
        COLLECTIONS.each do |key, type|
          klass = Records.class_for(type)
          items = (data[key] || []).map { |raw| klass.from_hash(raw) }
          project.public_send("#{key}=", items)
        end
        project.proposals = data["proposals"] || []
        project
      end

      def build_profile(raw)
        raw = raw.transform_keys(&:to_s)
        people = (raw["people"] || []).map { |p| Records::Person.from_hash(p) }
        Records::Profile.from_hash(raw.merge("people" => people))
      end
    end

    def save
      Storage.write(@path, to_h)
    end

    def to_h
      result = {
        "id" => id,
        "name" => name,
        "currency" => currency,
        "start_year" => start_year,
        "end_year" => end_year,
      }
      result["household_aggregation"] = household_aggregation if household_aggregation
      result["profile"] = serialize_profile if profile
      COLLECTIONS.each_key do |key|
        items = public_send(key)
        result[key] = items.map { |r| stringify(r.to_h) } if items.any?
      end
      result["proposals"] = proposals if proposals.any?
      result
    end

    def collection(type)
      key = Schema.plural(type)
      raise ArgumentError, "No collection for #{type}" unless COLLECTIONS.key?(key)

      public_send(key)
    end

    def find(type, id)
      collection(type).find { |r| r.id == id } ||
        raise(RecordNotFound, "#{Schema.canonical(type)} '#{id}' not found")
    end

    private

    def serialize_profile
      hash = stringify(profile.to_h)
      if profile.people
        hash["people"] = profile.people.map { |p| stringify(p.to_h) }
      end
      hash
    end

    def stringify(hash)
      hash.transform_keys(&:to_s)
    end
  end
end
