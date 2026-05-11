# frozen_string_literal: true

require "csv"
require "lifeplan/commands/helpers"
require "lifeplan/forecast/engine"
require "lifeplan/scenarios/resolver"

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
        project = resolved_project(opts)
        result = build_forecast(project, opts.merge("include-details": true))

        case target.to_s
        when "year" then explain_year(project, result, args.first&.to_i)
        when "metric" then explain_metric(result, args.first, opts)
        when "scenario-diff", "scenario_diff"
          explain_scenario_diff_stub
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
          "row" => row.to_h,
        }
        text = data["summary"] + "\nContributors:\n" + contributors.map { |c|
          "  - #{c["record_type"]} #{c["record_id"]}: #{c["amount"]}"
        }.join("\n")
        payload(data: data, text: text)
      end

      def explain_metric(result, metric, opts)
        raise InvalidArguments, "metric argument required" unless metric

        summary = result.summary.to_h
        unless summary.key?(metric)
          raise InvalidArguments,
            "unknown metric '#{metric}'. Known: #{summary.keys.join(", ")}"
        end

        year = opts[:year]&.to_i
        row = year ? result.years.find { |r| r.year == year } : nil

        data = {
          "target_type" => "metric",
          "target" => metric,
          "scenario_id" => result.scenario_id,
          "year" => year,
          "value" => summary[metric],
          "summary" => "#{metric} = #{summary[metric].inspect}",
          "row" => row&.to_h,
        }
        payload(data: data, text: data["summary"])
      end

      def explain_scenario_diff_stub
        data = {
          "target_type" => "scenario_diff",
          "summary" => "scenario-diff explanation requires Phase 5 scenario resolver.",
          "available" => false,
        }
        payload(data: data, text: data["summary"])
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
