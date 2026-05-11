# frozen_string_literal: true

require "lifeplan/validation/issue"
require "lifeplan/schema"

module Lifeplan
  module Validation
    module Rules
      module Structural
        extend self

        def call(project)
          issues = []
          issues.concat(check_required_fields(project))
          issues.concat(check_duplicate_ids(project))
          issues.concat(check_enums(project))
          issues.concat(check_references(project))
          issues
        end

        def check_required_fields(project)
          issues = []
          each_record(project) do |type, record|
            Lifeplan::Schema.fields_for(type).each do |field|
              next unless field.required

              value = record.public_send(field.name)
              if value.nil? || (value.respond_to?(:empty?) && value.empty? && field.type != :array)
                issues << Issue.error(
                  "MISSING_REQUIRED_FIELD",
                  "#{type} '#{record.id}' is missing required field '#{field.name}'.",
                  record_type: type,
                  record_id: safe_id(record),
                  path: field.name.to_s,
                )
              end
            end
          end
          issues
        end

        def check_duplicate_ids(project)
          issues = []
          Lifeplan::Project::COLLECTIONS.each_value do |type|
            seen = {}
            project.collection(type).each do |record|
              if seen.key?(record.id)
                issues << Issue.error(
                  "DUPLICATE_ID",
                  "Duplicate #{type} id '#{record.id}'.",
                  record_type: type,
                  record_id: record.id,
                  path: "id",
                )
              else
                seen[record.id] = true
              end
            end
          end
          issues
        end

        def check_enums(project)
          issues = []
          each_record(project) do |type, record|
            Lifeplan::Schema.fields_for(type).each do |field|
              next unless field.allowed

              value = record.public_send(field.name)
              next if value.nil? || field.allowed.include?(value.to_s)

              issues << Issue.error(
                "INVALID_ENUM",
                "#{type} '#{record.id}' has invalid #{field.name} '#{value}'. " \
                  "Allowed: #{field.allowed.join(", ")}.",
                record_type: type,
                record_id: safe_id(record),
                path: field.name.to_s,
              )
            end
          end
          issues
        end

        def check_references(project)
          issues = []
          person_ids = (project.profile&.people || []).map(&:id)
          asset_ids = project.assets.map(&:id)
          assumption_ids = project.assumptions.map(&:id)

          each_record_with_person(project) do |type, record|
            next if record.person_id.nil? || person_ids.include?(record.person_id)

            issues << Issue.error(
              "MISSING_REFERENCE",
              "#{type} '#{record.id}' references unknown person '#{record.person_id}'.",
              record_type: type,
              record_id: record.id,
              path: "person_id",
            )
          end

          project.liabilities.each do |l|
            next if l.secured_by_asset_id.nil? || asset_ids.include?(l.secured_by_asset_id)

            issues << Issue.error(
              "MISSING_REFERENCE",
              "liability '#{l.id}' references unknown asset '#{l.secured_by_asset_id}'.",
              record_type: "liability",
              record_id: l.id,
              path: "secured_by_asset_id",
            )
          end

          issues.concat(check_contribution_refs(project, asset_ids))
          issues.concat(check_event_refs(project, asset_ids))
          issues.concat(check_assumption_refs(project, assumption_ids))
          issues
        end

        def check_event_refs(project, asset_ids)
          issues = []
          cash_id = project.assets.find { |a| a.category == "cash" }&.id

          project.events.each do |e|
            next unless e.impact_type == "asset_disposal"

            issues.concat(disposal_target_issues(e, asset_ids))
            issues.concat(disposal_proceeds_issues(e))
            issues.concat(disposal_destination_issues(e, asset_ids, cash_id))
          end
          issues
        end

        def disposal_target_issues(event, asset_ids)
          if event.target_asset_id.nil?
            [Issue.error(
              "MISSING_REQUIRED_FIELD",
              "event '#{event.id}' (asset_disposal) is missing required field 'target_asset_id'.",
              record_type: "event",
              record_id: event.id,
              path: "target_asset_id",
            )]
          elsif !asset_ids.include?(event.target_asset_id)
            [Issue.error(
              "MISSING_REFERENCE",
              "event '#{event.id}' references unknown asset '#{event.target_asset_id}'.",
              record_type: "event",
              record_id: event.id,
              path: "target_asset_id",
            )]
          else
            []
          end
        end

        def disposal_proceeds_issues(event)
          return [] unless event.proceeds.nil?

          [Issue.error(
            "MISSING_REQUIRED_FIELD",
            "event '#{event.id}' (asset_disposal) is missing required field 'proceeds'.",
            record_type: "event",
            record_id: event.id,
            path: "proceeds",
          )]
        end

        def disposal_destination_issues(event, asset_ids, cash_id)
          if event.proceeds_to_asset
            return [] if asset_ids.include?(event.proceeds_to_asset)

            [Issue.error(
              "MISSING_REFERENCE",
              "event '#{event.id}' references unknown asset '#{event.proceeds_to_asset}'.",
              record_type: "event",
              record_id: event.id,
              path: "proceeds_to_asset",
            )]
          elsif cash_id.nil?
            [Issue.error(
              "MISSING_REFERENCE",
              "event '#{event.id}' has no proceeds_to_asset and the project has no cash-category asset.",
              record_type: "event",
              record_id: event.id,
              path: "proceeds_to_asset",
            )]
          else
            []
          end
        end

        def check_contribution_refs(project, asset_ids)
          issues = []
          project.contributions.each do |c|
            [[:from_asset, c.from_asset], [:to_asset, c.to_asset]].each do |field, value|
              next if value.nil? || asset_ids.include?(value)

              issues << Issue.error(
                "MISSING_REFERENCE",
                "contribution '#{c.id}' references unknown asset '#{value}'.",
                record_type: "contribution",
                record_id: c.id,
                path: field.to_s,
              )
            end

            if c.from_asset && c.to_asset && c.from_asset == c.to_asset
              issues << Issue.error(
                "INVALID_REFERENCE",
                "contribution '#{c.id}' has identical from_asset and to_asset.",
                record_type: "contribution",
                record_id: c.id,
                path: "to_asset",
              )
            end
          end
          issues
        end

        def check_assumption_refs(project, assumption_ids)
          issues = []
          [[:incomes, :growth], [:expenses, :growth], [:assets, :return]].each do |coll, field|
            project.public_send(coll).each do |r|
              value = r.public_send(field)
              next unless value.is_a?(String) && !assumption_ids.include?(value)

              issues << Issue.error(
                "MISSING_REFERENCE",
                "#{r.class.type_name} '#{r.id}' #{field} references unknown assumption '#{value}'.",
                record_type: r.class.type_name,
                record_id: r.id,
                path: field.to_s,
              )
            end
          end
          issues
        end

        def each_record(project)
          Lifeplan::Project::COLLECTIONS.each_value do |type|
            project.collection(type).each { |record| yield(type, record) }
          end
          if project.profile
            yield("profile", project.profile)
            (project.profile.people || []).each { |p| yield("person", p) }
          end
        end

        def each_record_with_person(project)
          [:incomes, :expenses, :assets, :events, :contributions].each do |coll|
            project.public_send(coll).each do |record|
              type = Lifeplan::Project::COLLECTIONS[coll.to_s]
              yield(type, record)
            end
          end
        end

        def safe_id(record)
          record.respond_to?(:id) ? record.id : nil
        end
      end
    end
  end
end
