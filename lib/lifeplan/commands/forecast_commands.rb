# frozen_string_literal: true

require "csv"
require "lifeplan/commands/helpers"
require "lifeplan/forecast/engine"
require "lifeplan/forecast/year_builder"
require "lifeplan/scenarios/resolver"
require "lifeplan/scenarios/path"
require "lifeplan/validation/validator"

module Lifeplan
  module Commands
    module ForecastCommands
      include Helpers

      FORECAST_COLUMNS = [
        "year",
        "income",
        "expense",
        "event_income",
        "event_expense",
        "net_cashflow",
        "asset_balance",
        "liability_balance",
        "net_worth",
      ].freeze

      def forecast_payload(opts)
        project = resolved_project(opts)
        result = build_forecast(project, opts)
        by_person = !!(opts[:"by-person"] || opts[:by_person])

        rows = result.years.map(&:to_h)
        data = {
          "scenario_id" => result.scenario_id,
          "from" => result.from,
          "to" => result.to,
          "years" => rows,
          "summary" => result.summary.to_h,
        }
        payload(
          data: data,
          text: forecast_text(result, by_person: by_person),
          markdown: forecast_markdown(result, by_person: by_person),
          csv: by_person ? per_person_csv(result) : forecast_csv(rows),
        )
      end

      def explain_payload(target, args, opts)
        case target.to_s
        when "year"
          project = resolved_project(opts)
          result = build_forecast(project, opts.merge("include-details": true))
          explain_year(project, result, args.first&.to_i)
        when "metric"
          project = resolved_project(opts)
          result = build_forecast(project, opts.merge("include-details": true))
          explain_metric(project, result, args.first || opts[:metric], opts)
        when "scenario-diff", "scenario_diff"
          explain_scenario_diff(args, opts)
        when "record"
          project = resolved_project(opts)
          result = build_forecast(project, opts.merge("include-details": true))
          explain_record(project, result, args.first || opts[:record], opts)
        else
          raise InvalidArguments, "Unknown explain target: #{target}"
        end
      end

      private

      def resolved_project(opts)
        base = load_project
        scenario_id = opts[:scenario]
        return base if scenario_id.nil? || scenario_id == "base"

        Lifeplan::Scenarios::Resolver.new(base).call(scenario_id)
      end

      def build_forecast(project, opts)
        Lifeplan::Forecast::Engine.new(
          project,
          scenario_id: opts[:scenario] || "base",
          from: opts[:from]&.to_i,
          to: opts[:to]&.to_i,
          include_details: opts[:"include-details"] || opts[:include_details] || false,
          include_per_person: opts[:"by-person"] || opts[:by_person] || false,
        ).call
      end

      PER_PERSON_COLUMNS = [
        "income", "expense", "asset_balance", "liability_balance", "net_worth",
      ].freeze

      def forecast_text(result, by_person: false)
        header = format_row(FORECAST_COLUMNS)
        lines = [header, "-" * header.length]
        result.years.each do |row|
          lines << format_row(FORECAST_COLUMNS.map { |c| row[c.to_sym] })
        end
        lines << ""
        lines << "Summary:"
        result.summary.to_h.each { |k, v| lines << "  #{k}: #{v.inspect}" }
        if by_person
          lines << ""
          lines.concat(per_person_text_blocks(result))
        end
        lines.join("\n")
      end

      def forecast_csv(rows)
        CSV.generate do |csv|
          csv << FORECAST_COLUMNS
          rows.each { |row| csv << FORECAST_COLUMNS.map { |c| row[c] } }
        end
      end

      def forecast_markdown(result, by_person: false)
        lines = ["| " + FORECAST_COLUMNS.join(" | ") + " |"]
        lines << "|" + (["---"] * FORECAST_COLUMNS.size).join("|") + "|"
        result.years.each do |row|
          lines << "| " + FORECAST_COLUMNS.map { |c| row[c.to_sym].to_s }.join(" | ") + " |"
        end
        if by_person
          lines << ""
          lines.concat(per_person_markdown_blocks(result))
        end
        lines.join("\n")
      end

      def per_person_text_blocks(result)
        blocks = []
        result.years.each do |row|
          next unless row.per_person

          blocks << "Per-person breakdown for #{row.year}:"
          header_cols = ["person"] + PER_PERSON_COLUMNS
          blocks << format_row(header_cols)
          blocks << "-" * format_row(header_cols).length
          per_person_rows(row.per_person).each do |key, bucket|
            blocks << format_row([key] + PER_PERSON_COLUMNS.map { |c| bucket[c] })
          end
          blocks << ""
        end
        blocks
      end

      def per_person_markdown_blocks(result)
        blocks = []
        result.years.each do |row|
          next unless row.per_person

          blocks << "### Per-person breakdown for #{row.year}"
          blocks << "| person | " + PER_PERSON_COLUMNS.join(" | ") + " |"
          blocks << "|" + (["---"] * (PER_PERSON_COLUMNS.size + 1)).join("|") + "|"
          per_person_rows(row.per_person).each do |key, bucket|
            blocks << "| " + ([key] + PER_PERSON_COLUMNS.map { |c| bucket[c].to_s }).join(" | ") + " |"
          end
          blocks << ""
        end
        blocks
      end

      def per_person_csv(result)
        CSV.generate do |csv|
          csv << ["year", "person_id"] + PER_PERSON_COLUMNS
          result.years.each do |row|
            next unless row.per_person

            per_person_rows(row.per_person).each do |key, bucket|
              csv << [row.year, key] + PER_PERSON_COLUMNS.map { |c| bucket[c] }
            end
          end
        end
      end

      def per_person_rows(per_person)
        shared = per_person["_shared"]
        named = per_person.reject { |k, _| k == "_shared" }
        rows = named.to_a
        rows << ["_shared", shared] if shared
        rows
      end

      def format_row(values)
        values.map { |v| v.to_s.rjust(14) }.join(" ")
      end

      def explain_year(project, result, year)
        raise InvalidArguments, "year argument required" unless year

        row = result.years.find { |r| r.year == year }
        raise InvalidArguments, "year #{year} not in forecast range" unless row

        contributors = year_contributors(project, year, row.details)
        data = {
          "target_type" => "year",
          "target" => year,
          "scenario_id" => result.scenario_id,
          "year" => year,
          "summary" => "Year #{year}: income #{row.income}, expense #{row.expense}, " \
            "net cashflow #{row.net_cashflow}, assets #{row.asset_balance}.",
          "contributors" => contributors,
          "assumptions" => referenced_assumption_ids(project, contributors),
          "warnings" => relevant_warnings(project),
          "row" => row.to_h,
        }
        payload(data: data, text: render_explanation_text(data))
      end

      def explain_metric(project, result, metric, opts)
        raise InvalidArguments, "metric argument required" unless metric

        summary = result.summary.to_h
        unless summary.key?(metric) || metric == "depletion_year"
          raise InvalidArguments,
            "unknown metric '#{metric}'. Known: #{(summary.keys + ["depletion_year"]).uniq.join(", ")}"
        end

        data = case metric
        when "depletion_year"
          explain_depletion_year(project, result)
        when "first_negative_asset_year"
          explain_negative_asset_year(project, result, summary[metric])
        else
          explain_summary_metric(project, result, metric, summary[metric], opts)
        end

        payload(data: data, text: render_explanation_text(data))
      end

      def explain_depletion_year(project, result)
        depleted = result.years.find { |y| y.liquid_balance.negative? }
        year = depleted&.year
        contributors, totals = cumulative_record_contributors(project, result, year || result.to)

        summary = if year
          gap = totals[:expense] + totals[:withdrawals] - totals[:income]
          "Liquid balance first goes negative in #{year}. " \
            "From #{result.from}-#{year}: income #{totals[:income]}, " \
            "expense #{totals[:expense]}, gap #{gap} covered by withdrawals."
        else
          "Liquid balance never goes negative during the forecast (#{result.from}-#{result.to})."
        end

        {
          "target_type" => "metric",
          "target" => "depletion_year",
          "scenario_id" => result.scenario_id,
          "metric" => "depletion_year",
          "value" => year,
          "summary" => summary,
          "contributors" => contributors,
          "assumptions" => referenced_assumption_ids(project, contributors),
          "warnings" => relevant_warnings(project),
          "cumulative" => totals,
        }
      end

      def explain_negative_asset_year(project, result, year)
        contributors, totals = cumulative_record_contributors(project, result, year || result.to)
        summary = if year
          "Asset balance first turns negative in #{year}. " \
            "Cumulative #{result.from}-#{year}: income #{totals[:income]}, expense #{totals[:expense]}."
        else
          "Asset balance stays non-negative across the forecast."
        end
        {
          "target_type" => "metric",
          "target" => "first_negative_asset_year",
          "scenario_id" => result.scenario_id,
          "metric" => "first_negative_asset_year",
          "value" => year,
          "summary" => summary,
          "contributors" => contributors,
          "assumptions" => referenced_assumption_ids(project, contributors),
          "warnings" => relevant_warnings(project),
          "cumulative" => totals,
        }
      end

      def explain_summary_metric(project, result, metric, value, opts)
        year = opts[:year]&.to_i
        contributors, _totals = cumulative_record_contributors(project, result, year || result.to)
        {
          "target_type" => "metric",
          "target" => metric,
          "scenario_id" => result.scenario_id,
          "metric" => metric,
          "value" => value,
          "summary" => "#{metric} = #{value.inspect} (over #{result.from}-#{year || result.to}).",
          "contributors" => contributors,
          "assumptions" => referenced_assumption_ids(project, contributors),
          "warnings" => relevant_warnings(project),
        }
      end

      def explain_scenario_diff(args, opts)
        ids = args.first(2)
        raise InvalidArguments, "scenario-diff requires two scenario ids" if ids.size < 2

        base_project = load_project
        resolver = Lifeplan::Scenarios::Resolver.new(base_project)
        a_project = resolver.call(ids[0])
        b_project = resolver.call(ids[1])
        a = Lifeplan::Forecast::Engine.new(
          a_project, scenario_id: ids[0], from: opts[:from]&.to_i, to: opts[:to]&.to_i
        ).call
        b = Lifeplan::Forecast::Engine.new(
          b_project, scenario_id: ids[1], from: opts[:from]&.to_i, to: opts[:to]&.to_i
        ).call

        year = opts[:year]&.to_i || a.to
        a_row = a.years.find { |y| y.year == year }
        b_row = b.years.find { |y| y.year == year }

        deltas = ["asset_balance", "liquid_balance", "net_worth", "income", "expense"].to_h do |m|
          [m, (b_row&.send(m.to_sym) || 0) - (a_row&.send(m.to_sym) || 0)]
        end
        contributors = scenario_override_contributors(base_project, ids[0], ids[1])
        data = {
          "target_type" => "scenario_diff",
          "target" => "#{ids[0]}..#{ids[1]}",
          "scenario_id" => ids[1],
          "year" => year,
          "summary" => "Scenario #{ids[1]} vs #{ids[0]} at #{year}: " \
            "net_worth delta #{deltas["net_worth"]}, liquid delta #{deltas["liquid_balance"]}.",
          "deltas" => deltas,
          "contributors" => contributors,
          "assumptions" => [],
          "warnings" => relevant_warnings(base_project),
        }
        payload(data: data, text: render_explanation_text(data))
      end

      def explain_record(project, result, raw_path, _opts)
        raise InvalidArguments, "record argument required (e.g. income.salary)" unless raw_path

        path = Lifeplan::Scenarios::Path.parse(raw_path)
        record = project.find(path.type, path.id)
        per_year, total = record_yearly_contribution(project, result, path.type, record)
        data = {
          "target_type" => "record",
          "target" => "#{path.type}.#{path.id}",
          "scenario_id" => result.scenario_id,
          "record_type" => path.type,
          "record_id" => path.id,
          "summary" => "#{path.type} '#{path.id}' (#{record.respond_to?(:name) ? record.name : ""}) " \
            "contributes #{total} over #{result.from}-#{result.to}.",
          "value" => total,
          "per_year" => per_year,
          "contributors" => [{
            "record_type" => path.type,
            "record_id" => path.id,
            "name" => record.respond_to?(:name) ? record.name : nil,
            "amount" => total,
          }],
          "assumptions" => referenced_assumption_ids_for_record(record),
          "warnings" => relevant_warnings(project),
        }
        payload(data: data, text: render_explanation_text(data))
      end

      def cumulative_record_contributors(project, result, through_year)
        income_totals = Hash.new(0)
        expense_totals = Hash.new(0)
        running = { income: 0, expense: 0, withdrawals: 0 }

        result.years.each do |row|
          break if row.year > through_year

          project.incomes.each do |r|
            amount = Lifeplan::Forecast::YearBuilder.income_for(r, row.year, project.assumptions)
            next if amount.zero?

            income_totals[r.id] += amount
            running[:income] += amount unless r.contribute_to
          end
          project.expenses.each do |r|
            amount = Lifeplan::Forecast::YearBuilder.expense_for(r, row.year, project.assumptions)
            next if amount.zero?

            expense_totals[r.id] += amount
            running[:expense] += amount
          end
          (row.details&.dig("withdrawals") || []).each do |w|
            running[:withdrawals] += w["amount"].to_i
          end
        end

        contributors = []
        project.incomes.each do |r|
          amount = income_totals[r.id]
          next if amount.zero?

          contributors << { "record_type" => "income", "record_id" => r.id, "name" => r.name, "amount" => amount }
        end
        project.expenses.each do |r|
          amount = expense_totals[r.id]
          next if amount.zero?

          contributors << { "record_type" => "expense", "record_id" => r.id, "name" => r.name, "amount" => -amount }
        end
        [contributors, running]
      end

      def scenario_override_contributors(project, a_id, b_id)
        a_overrides = scenario_overrides(project, a_id)
        b_overrides = scenario_overrides(project, b_id)
        a_paths = a_overrides.to_h { |o| [o["path"], o["value"]] }
        b_paths = b_overrides.to_h { |o| [o["path"], o["value"]] }
        keys = (a_paths.keys + b_paths.keys).uniq
        keys.map do |path|
          { "path" => path, "from" => a_paths[path], "to" => b_paths[path] }
        end.reject { |c| c["from"] == c["to"] }
      end

      def scenario_overrides(project, scenario_id)
        return [] if scenario_id.nil? || scenario_id == "base"

        scenario = project.scenarios.find { |s| s.id == scenario_id }
        scenario ? Array(scenario.overrides).map { |o| o.transform_keys(&:to_s) } : []
      end

      def record_yearly_contribution(project, result, type, record)
        per_year = []
        total = 0
        result.years.each do |row|
          amount = case type
          when "income"
            Lifeplan::Forecast::YearBuilder.income_for(record, row.year, project.assumptions)
          when "expense"
            -Lifeplan::Forecast::YearBuilder.expense_for(record, row.year, project.assumptions)
          when "event"
            Lifeplan::Forecast::YearBuilder.event_amount(record, row.year) || 0
          when "asset"
            row.details&.dig("assets", record.id) || 0
          when "liability"
            row.details&.dig("liabilities", record.id) || 0
          else 0
          end
          per_year << { "year" => row.year, "amount" => amount } if amount.nonzero?
          total += amount if ["income", "expense", "event"].include?(type)
        end
        total = per_year.last&.dig("amount") || 0 if ["asset", "liability"].include?(type)
        [per_year, total]
      end

      def referenced_assumption_ids(project, contributors)
        ids = project.assumptions.map(&:id)
        used = []
        contributors.each do |c|
          record = find_record_for_contributor(project, c)
          next unless record

          field = record.respond_to?(:growth) ? record.growth : nil
          field = record.respond_to?(:return) ? record.return : field
          used << field if field.is_a?(String) && ids.include?(field)
        end
        used.uniq
      end

      def referenced_assumption_ids_for_record(record)
        ids = []
        ids << record.growth if record.respond_to?(:growth) && record.growth.is_a?(String)
        ids << record.return if record.respond_to?(:return) && record.return.is_a?(String)
        ids.uniq
      end

      def find_record_for_contributor(project, contributor)
        type = contributor["record_type"]
        return unless ["income", "expense", "asset"].include?(type)

        coll = project.collection(type)
        coll.find { |r| r.id == contributor["record_id"] }
      rescue ArgumentError
        nil
      end

      def relevant_warnings(project)
        Lifeplan::Validation::Validator.new.call(project).select(&:warning?).map(&:to_h)
      end

      def render_explanation_text(data)
        lines = [data["summary"]]
        contributors = data["contributors"]
        if contributors && !contributors.empty?
          lines << "Contributors:"
          contributors.each do |c|
            label = if c["path"]
              "#{c["path"]}: #{c["from"]} -> #{c["to"]}"
            else
              "#{c["record_type"]} #{c["record_id"]}: #{c["amount"]}"
            end
            lines << "  - #{label}"
          end
        end
        if data["assumptions"] && !data["assumptions"].empty?
          lines << "Assumptions: #{data["assumptions"].join(", ")}"
        end
        warnings = data["warnings"] || []
        unless warnings.empty?
          lines << "Warnings:"
          warnings.each { |w| lines << "  - #{w[:code] || w["code"]}: #{w[:message] || w["message"]}" }
        end
        lines.join("\n")
      end

      def year_contributors(project, year, details = nil)
        contributors = []
        project.incomes.each do |r|
          amount = Lifeplan::Forecast::YearBuilder.income_for(r, year, project.assumptions)
          next if amount.zero?

          contributors << contributor("income", r, amount)
        end
        project.expenses.each do |r|
          amount = Lifeplan::Forecast::YearBuilder.expense_for(r, year, project.assumptions)
          next if amount.zero?

          contributors << contributor("expense", r, -amount)
        end
        disposals_by_event = (details && details["asset_disposals"] || [])
          .to_h { |d| [d["event_id"], d] }
        project.events.each do |r|
          if r.impact_type == "asset_disposal"
            disposal = disposals_by_event[r.id]
            next unless disposal

            contributors.concat(disposal_contributors(r, disposal))
            next
          end

          amount = Lifeplan::Forecast::YearBuilder.event_amount(r, year)
          next if amount.zero?

          signed = r.impact_type == "expense" ? -amount : amount
          contributors << contributor("event", r, signed)
        end
        contributors
      end

      def disposal_contributors(event, disposal)
        [
          {
            "record_type" => "event",
            "record_id" => event.id,
            "name" => "#{event.name} (book value loss)",
            "amount" => -disposal["book_value_loss"].to_i,
            "kind" => "book_value_loss",
          },
          {
            "record_type" => "event",
            "record_id" => event.id,
            "name" => "#{event.name} (proceeds)",
            "amount" => disposal["proceeds"].to_i,
            "kind" => "proceeds",
          },
        ]
      end

      def contributor(type, record, amount)
        {
          "record_type" => type,
          "record_id" => record.id,
          "name" => record.name,
          "amount" => amount,
        }
      end
    end
  end
end
