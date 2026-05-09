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

          issues.concat(check_assumption_refs(project, assumption_ids))
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
          [:incomes, :expenses, :assets, :events].each do |coll|
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
