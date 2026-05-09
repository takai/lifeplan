# Lifeplan CLI Interface Definition

## 1. Purpose

This document defines the command-line interface for Lifeplan CLI.

Lifeplan CLI is a tool for managing life planning data, running standard life planning calculations, validating assumptions, generating projections, comparing scenarios, and exporting results.

This document defines only the external CLI interface and user-facing behavior. It does not define internal architecture, storage format, libraries, algorithms, or implementation details.

## 2. Command Name

```bash
lifeplan
```

## 3. Interface Principles

Lifeplan CLI should provide predictable, scriptable commands.

The CLI should support both human users and LLM agents. Therefore, every command that returns meaningful data should support machine-readable output.

The CLI should separate reading, proposing, applying, validating, calculating, explaining, comparing, and exporting.

The CLI should avoid implicit destructive changes. Commands that modify planning data should support preview behavior.

## 4. Global Options

All commands should support the following global options where applicable.

```bash
lifeplan <command> [options]
```

| Option              | Description                                                        |
| ------------------- | ------------------------------------------------------------------ |
| `--project <path>`  | Use a specific life planning project directory                     |
| `--scenario <id>`   | Use a specific scenario                                            |
| `--format <format>` | Output format. Supported values: `text`, `json`, `csv`, `markdown` |
| `--quiet`           | Suppress non-essential output                                      |
| `--verbose`         | Show additional details                                            |
| `--no-color`        | Disable colored output                                             |
| `--help`            | Show help                                                          |
| `--version`         | Show version                                                       |

Default output format should be `text` for human-facing commands.

For LLM-agent usage, `--format json` should be available for all inspection, validation, forecast, explanation, comparison, and change-preview commands.

## 5. Exit Codes

| Code | Meaning                              |
| ---: | ------------------------------------ |
|  `0` | Success                              |
|  `1` | General error                        |
|  `2` | Invalid command or invalid arguments |
|  `3` | Validation failed                    |
|  `4` | Project not found or invalid project |
|  `5` | Record not found                     |
|  `6` | Scenario not found                   |
|  `7` | Change cannot be applied             |
|  `8` | Forecast cannot be generated         |

## 6. Output Formats

### 6.1 Text

Human-readable output for terminal use.

### 6.2 JSON

Machine-readable output for LLM agents and automation.

JSON output should clearly distinguish:

```text
data
warnings
errors
metadata
```

### 6.3 CSV

Tabular output for spreadsheet use.

Mainly used for forecasts, yearly tables, scenario comparisons, and calculation tables.

### 6.4 Markdown

Human-readable report output.

Mainly used for summaries, reports, explanations, and scenario comparisons.

---

# 7. Project Commands

## 7.1 `lifeplan init`

Create a new life planning project.

```bash
lifeplan init [path]
```

### Options

| Option                | Description                    |
| --------------------- | ------------------------------ |
| `--name <name>`       | Project name                   |
| `--start-year <year>` | First projection year          |
| `--end-year <year>`   | Last projection year           |
| `--currency <code>`   | Currency code. Example: `JPY`  |
| `--template <name>`   | Create project from a template |

### Behavior

Creates an empty project structure with required initial data.

In addition to `project.json`, `init` scaffolds documents and skills used by
LLM agents working in the project:

- `CLAUDE.md` — short navigation file pointing at the documents and skills.
- `docs/prd.md`, `docs/cli.md`, `docs/datamodel.md` — copied from the
  installed Lifeplan CLI as the source of truth for product scope, command
  interface, and data model.
- `.claude/skills/lifeplan-product/SKILL.md`,
  `.claude/skills/lifeplan-cli/SKILL.md`,
  `.claude/skills/lifeplan-data/SKILL.md` — task-scoped guidance for Claude
  Code.

Existing files at the destination are not overwritten.

### Example

```bash
lifeplan init ./my-lifeplan --name "Family Plan" --start-year 2026 --end-year 2065 --currency JPY
```

---

## 7.2 `lifeplan status`

Show current project status.

```bash
lifeplan status
```

### Output

Should include:

```text
Project name
Projection period
Currency
Current scenario
Record counts
Validation summary
Warnings
```

### Example

```bash
lifeplan status --format json
```

---

# 8. Schema Commands

## 8.1 `lifeplan schema`

Show supported record types and fields.

```bash
lifeplan schema [record-type]
```

### Record Types

```text
profile
income
expense
asset
liability
event
assumption
scenario
```

### Examples

```bash
lifeplan schema
lifeplan schema income --format json
lifeplan schema expense --format json
```

### Behavior

Returns the expected fields, required fields, optional fields, accepted values, and examples for the specified record type.

---

# 9. Data Inspection Commands

## 9.1 `lifeplan list`

List records of a given type.

```bash
lifeplan list <record-type>
```

### Examples

```bash
lifeplan list incomes
lifeplan list expenses
lifeplan list assets
lifeplan list events
lifeplan list assumptions
```

### Options

| Option                  | Description                         |
| ----------------------- | ----------------------------------- |
| `--category <category>` | Filter by category                  |
| `--from <year>`         | Filter records active from year     |
| `--to <year>`           | Filter records active until year    |
| `--scenario <id>`       | List records in a specific scenario |

---

## 9.2 `lifeplan get`

Show a specific record.

```bash
lifeplan get <record-type> <id>
```

### Examples

```bash
lifeplan get income salary
lifeplan get expense living
lifeplan get asset securities
```

---

# 10. Data Change Commands

## 10.1 `lifeplan add`

Add a new record.

```bash
lifeplan add <record-type> [fields]
```

### Supported Record Types

```text
profile
income
expense
asset
liability
event
assumption
```

### Common Options

| Option                  | Description              |
| ----------------------- | ------------------------ |
| `--id <id>`             | Stable record ID         |
| `--name <name>`         | Human-readable name      |
| `--category <category>` | Category                 |
| `--amount <amount>`     | Amount                   |
| `--from <year>`         | Start year               |
| `--to <year>`           | End year                 |
| `--dry-run`             | Preview without applying |

### Examples

```bash
lifeplan add income \
  --id salary \
  --name "Salary" \
  --amount 9600000 \
  --from 2026 \
  --to 2045
```

```bash
lifeplan add expense \
  --id living \
  --name "Living expenses" \
  --amount 4200000 \
  --from 2026 \
  --to 2065 \
  --category living
```

```bash
lifeplan add asset \
  --id cash \
  --name "Cash" \
  --amount 7800000 \
  --as-of 2026-05-10
```

```bash
lifeplan add event \
  --id university-entry \
  --name "University entrance cost" \
  --year 2031 \
  --amount 1500000 \
  --category education
```

### Behavior

Adds a record if the input is valid.

If `--dry-run` is specified, returns a preview and does not change data.

---

## 10.2 `lifeplan set`

Update fields on an existing record.

```bash
lifeplan set <record-type> <id> <field> <value>
```

### Examples

```bash
lifeplan set income salary amount 10000000
lifeplan set expense living amount 4500000
lifeplan set assumption inflation 0.02
```

### Options

| Option      | Description              |
| ----------- | ------------------------ |
| `--dry-run` | Preview without applying |

---

## 10.3 `lifeplan remove`

Remove a record.

```bash
lifeplan remove <record-type> <id>
```

### Examples

```bash
lifeplan remove expense old-rent
lifeplan remove event unused-event
```

### Options

| Option      | Description                                  |
| ----------- | -------------------------------------------- |
| `--dry-run` | Preview without removing                     |
| `--force`   | Remove without confirmation where applicable |

---

# 11. Proposed Change Commands

These commands are intended for LLM-agent workflows.

## 11.1 `lifeplan propose`

Create a change proposal without applying it.

```bash
lifeplan propose <action> <record-type> [fields]
```

### Actions

```text
add
set
remove
```

### Examples

```bash
lifeplan propose add expense \
  --id university \
  --name "University costs" \
  --amount 1500000 \
  --from 2031 \
  --to 2034 \
  --category education \
  --format json
```

```bash
lifeplan propose set assumption inflation 0.03 --format json
```

### Output

Should include:

```text
Proposal ID
Summary
Action
Affected record
Before values, if applicable
After values, if applicable
Validation result
Potential forecast impact, if available
```

---

## 11.2 `lifeplan apply`

Apply a proposed change.

```bash
lifeplan apply <proposal-id>
```

### Options

| Option      | Description                  |
| ----------- | ---------------------------- |
| `--dry-run` | Preview application          |
| `--force`   | Apply even if warnings exist |

### Behavior

Applies a proposal only if it is still valid.

If the underlying data changed after the proposal was created, the command should report that the proposal may be stale.

---

## 11.3 `lifeplan proposals`

List pending proposals.

```bash
lifeplan proposals
```

---

## 11.4 `lifeplan discard`

Discard a proposal.

```bash
lifeplan discard <proposal-id>
```

---

# 12. Validation Commands

## 12.1 `lifeplan validate`

Validate the current project or scenario.

```bash
lifeplan validate
```

### Options

| Option              | Description                  |
| ------------------- | ---------------------------- |
| `--scenario <id>`   | Validate a specific scenario |
| `--strict`          | Treat warnings as failures   |
| `--format <format>` | `text` or `json`             |

### Behavior

Checks whether the project data is internally consistent.

### Validation Categories

```text
Required fields
Invalid amounts
Invalid year ranges
Duplicate IDs
Missing referenced records
Events outside projection period
Scenario overrides pointing to missing records
Forecast-blocking errors
Potentially suspicious assumptions
```

### JSON Output Shape

```json
{
  "valid": false,
  "errors": [
    {
      "severity": "error",
      "code": "MISSING_REQUIRED_FIELD",
      "message": "Income amount is required.",
      "record_type": "income",
      "record_id": "salary",
      "path": "amount"
    }
  ],
  "warnings": []
}
```

---

# 13. Forecast Commands

## 13.1 `lifeplan forecast`

Generate an annual life planning projection.

```bash
lifeplan forecast
```

### Options

| Option              | Description                       |
| ------------------- | --------------------------------- |
| `--from <year>`     | Start year                        |
| `--to <year>`       | End year                          |
| `--scenario <id>`   | Scenario to forecast              |
| `--format <format>` | `text`, `json`, `csv`, `markdown` |
| `--include-details` | Include item-level breakdown      |

### Output Columns

At minimum, forecast output should include:

```text
year
income
expense
event
net_cashflow
asset_balance
liability_balance
net_worth
```

If profile age data exists, output may also include:

```text
age
spouse_age
child_age
```

### Example

```bash
lifeplan forecast --scenario base --from 2026 --to 2065 --format csv
```

---

## 13.2 `lifeplan explain`

Explain a forecast result.

```bash
lifeplan explain <target>
```

### Targets

```text
year
metric
scenario-diff
```

### Examples

```bash
lifeplan explain year 2031
lifeplan explain metric asset_balance --year 2045
lifeplan explain scenario-diff base conservative --metric asset_balance
```

### Output

Should include:

```text
Requested year or metric
Input records contributing to the result
Assumptions used
Calculated result
Warnings or limitations
```

---

# 14. Scenario Commands

## 14.1 `lifeplan scenario list`

List scenarios.

```bash
lifeplan scenario list
```

---

## 14.2 `lifeplan scenario create`

Create a new scenario.

```bash
lifeplan scenario create <id>
```

### Options

| Option                 | Description                      |
| ---------------------- | -------------------------------- |
| `--name <name>`        | Human-readable name              |
| `--base <scenario-id>` | Create from an existing scenario |

### Example

```bash
lifeplan scenario create conservative --base base --name "Conservative Case"
```

---

## 14.3 `lifeplan scenario set`

Set an override in a scenario.

```bash
lifeplan scenario set <scenario-id> <path> <value>
```

### Examples

```bash
lifeplan scenario set conservative assumptions.investment_return 0.01
lifeplan scenario set conservative assumptions.inflation 0.03
lifeplan scenario set early-retirement incomes.salary.to 2040
```

### Options

| Option      | Description              |
| ----------- | ------------------------ |
| `--dry-run` | Preview without applying |

---

## 14.4 `lifeplan scenario remove`

Remove a scenario.

```bash
lifeplan scenario remove <scenario-id>
```

---

## 14.5 `lifeplan compare`

Compare two scenarios.

```bash
lifeplan compare <base-scenario> <target-scenario>
```

### Options

| Option              | Description                       |
| ------------------- | --------------------------------- |
| `--from <year>`     | Start year                        |
| `--to <year>`       | End year                          |
| `--metric <metric>` | Compare a specific metric         |
| `--format <format>` | `text`, `json`, `csv`, `markdown` |

### Output

Should include:

```text
Changed assumptions
Changed records
Yearly differences
Key metric differences
First negative asset year, if any
Minimum asset balance
Asset balance at retirement, if available
```

---

# 15. Calculation Commands

Calculation commands are stateless utilities. They do not require project data unless explicitly connected to a scenario.

## 15.1 `lifeplan calc future-value`

Calculate future value.

```bash
lifeplan calc future-value --principal <amount> --rate <rate> --years <years>
```

### Alias

```bash
lifeplan calc fv
```

### Example

```bash
lifeplan calc fv --principal 10000000 --rate 0.03 --years 20
```

---

## 15.2 `lifeplan calc present-value`

Calculate present value.

```bash
lifeplan calc present-value --future <amount> --rate <rate> --years <years>
```

### Alias

```bash
lifeplan calc pv
```

---

## 15.3 `lifeplan calc savings`

Calculate recurring savings projection.

```bash
lifeplan calc savings \
  --payment <amount> \
  --rate <rate> \
  --years <years>
```

### Options

| Option                    | Description           |
| ------------------------- | --------------------- |
| `--initial <amount>`      | Initial amount        |
| `--frequency <frequency>` | `monthly` or `yearly` |

---

## 15.4 `lifeplan calc required-savings`

Calculate required savings amount for a target.

```bash
lifeplan calc required-savings \
  --target <amount> \
  --rate <rate> \
  --years <years>
```

### Options

| Option                    | Description           |
| ------------------------- | --------------------- |
| `--initial <amount>`      | Initial amount        |
| `--frequency <frequency>` | `monthly` or `yearly` |

---

## 15.5 `lifeplan calc withdrawal`

Estimate withdrawal amount.

```bash
lifeplan calc withdrawal \
  --principal <amount> \
  --rate <rate> \
  --years <years>
```

### Options

| Option                    | Description           |
| ------------------------- | --------------------- |
| `--frequency <frequency>` | `monthly` or `yearly` |

---

## 15.6 `lifeplan calc loan`

Calculate loan repayment.

```bash
lifeplan calc loan \
  --principal <amount> \
  --rate <rate> \
  --years <years>
```

### Options

| Option                     | Description                       |
| -------------------------- | --------------------------------- |
| `--frequency <frequency>`  | `monthly` or `yearly`             |
| `--bonus-payment <amount>` | Bonus repayment amount            |
| `--format <format>`        | `text`, `json`, `csv`, `markdown` |

---

## 15.7 `lifeplan calc inflation`

Calculate inflation-adjusted value.

```bash
lifeplan calc inflation \
  --amount <amount> \
  --rate <rate> \
  --years <years>
```

---

## 15.8 `lifeplan calc grow`

Generate a growth table.

```bash
lifeplan calc grow \
  --amount <amount> \
  --rate <rate> \
  --years <years>
```

### Options

| Option              | Description                       |
| ------------------- | --------------------------------- |
| `--format <format>` | `text`, `json`, `csv`, `markdown` |

---

# 16. Report and Export Commands

## 16.1 `lifeplan export`

Export structured data or calculated results.

```bash
lifeplan export <target>
```

### Targets

```text
data
forecast
scenario
comparison
validation
```

### Examples

```bash
lifeplan export forecast --scenario base --format csv
lifeplan export data --format json
lifeplan export comparison --scenario conservative --format markdown
```

---

## 16.2 `lifeplan report`

Generate a human-readable report.

```bash
lifeplan report
```

### Options

| Option                  | Description                 |
| ----------------------- | --------------------------- |
| `--scenario <id>`       | Scenario to report          |
| `--from <year>`         | Start year                  |
| `--to <year>`           | End year                    |
| `--format <format>`     | `markdown` or `text`        |
| `--include-validation`  | Include validation summary  |
| `--include-assumptions` | Include assumptions         |
| `--include-scenarios`   | Include scenario comparison |

### Example

```bash
lifeplan report --scenario base --format markdown
```

---

# 17. Check Commands

## 17.1 `lifeplan check`

Run higher-level planning checks.

```bash
lifeplan check
```

### Difference from `validate`

`validate` checks whether the data is structurally valid.

`check` looks for planning risks or suspicious patterns.

### Example Checks

```text
Assets become negative
Retirement income is missing
Expenses stop unexpectedly
Education costs overlap incorrectly
Loan continues beyond projection period
Inflation-sensitive expenses are not linked to inflation
Large one-time events are missing categories
Scenario assumptions differ but forecast is unchanged
```

### Options

| Option              | Description       |
| ------------------- | ----------------- |
| `--scenario <id>`   | Scenario to check |
| `--format <format>` | `text` or `json`  |

---

# 18. History and Diff Commands

## 18.1 `lifeplan diff`

Show differences between current data and another state, scenario, or proposal.

```bash
lifeplan diff
```

### Examples

```bash
lifeplan diff --scenario base conservative
lifeplan diff --proposal proposal_001
```

---

## 18.2 `lifeplan history`

Show change history if available.

```bash
lifeplan history
```

### Output

Should include:

```text
Change ID
Timestamp
Summary
Affected records
```

---

# 19. Template Commands

## 19.1 `lifeplan template list`

List available templates.

```bash
lifeplan template list
```

---

## 19.2 `lifeplan template show`

Show a template.

```bash
lifeplan template show <template-id>
```

---

## 19.3 `lifeplan template apply`

Apply a template to the current project.

```bash
lifeplan template apply <template-id>
```

### Options

| Option            | Description                  |
| ----------------- | ---------------------------- |
| `--dry-run`       | Preview changes              |
| `--scenario <id>` | Apply to a specific scenario |

### Example Templates

```text
single
couple
family-with-child
retirement-planning
mortgage-and-education
```

---

# 20. Record Type Definitions

## 20.1 Profile

Represents people and basic planning period information.

Common fields:

```text
id
name
birth_year
relationship
planning_start_year
planning_end_year
currency
```

---

## 20.2 Income

Represents recurring or one-time income.

Common fields:

```text
id
name
amount
frequency
from
to
growth
category
```

---

## 20.3 Expense

Represents recurring or one-time expense.

Common fields:

```text
id
name
amount
frequency
from
to
growth
category
```

---

## 20.4 Asset

Represents current or projected asset.

Common fields:

```text
id
name
amount
as_of
return
category
```

---

## 20.5 Liability

Represents debt or future repayment obligation.

Common fields:

```text
id
name
principal
rate
from
to
years
payment
category
```

---

## 20.6 Event

Represents a major life event.

Common fields:

```text
id
name
year
amount
category
description
```

---

## 20.7 Assumption

Represents a planning assumption.

Common fields:

```text
id
name
value
unit
description
```

Examples:

```text
inflation
investment_return
cash_return
salary_growth
retirement_age
```

---

## 20.8 Scenario

Represents a set of overrides against base data.

Common fields:

```text
id
name
base
overrides
description
```

---

# 21. Minimum Required Command Set for MVP

The MVP should include at least the following commands.

```bash
lifeplan init
lifeplan status
lifeplan schema
lifeplan list
lifeplan get
lifeplan add
lifeplan set
lifeplan remove
lifeplan validate
lifeplan check
lifeplan forecast
lifeplan explain
lifeplan scenario list
lifeplan scenario create
lifeplan scenario set
lifeplan compare
lifeplan calc fv
lifeplan calc pv
lifeplan calc savings
lifeplan calc required-savings
lifeplan calc withdrawal
lifeplan calc loan
lifeplan calc inflation
lifeplan calc grow
lifeplan export
lifeplan report
```

Agent-oriented MVP should additionally include:

```bash
lifeplan propose
lifeplan apply
lifeplan proposals
lifeplan discard
lifeplan diff
```

---

# 22. Example Agent Workflow

An LLM agent should be able to use the CLI in the following sequence.

```bash
lifeplan status --format json
lifeplan schema income --format json
lifeplan list incomes --format json
lifeplan propose add income --id salary --name "Salary" --amount 9600000 --from 2026 --to 2045 --format json
lifeplan validate --format json
lifeplan apply proposal_001
lifeplan forecast --scenario base --format json
lifeplan explain year 2031 --format json
lifeplan report --scenario base --format markdown
```

This workflow allows the agent to inspect, propose, validate, apply, forecast, explain, and report without directly editing project data.

---

# 23. Example Human Workflow

A human user should be able to use the CLI directly.

```bash
lifeplan init ./plan --name "My Life Plan" --start-year 2026 --end-year 2065
lifeplan add income --id salary --name "Salary" --amount 9600000 --from 2026 --to 2045
lifeplan add expense --id living --name "Living Expenses" --amount 4200000 --from 2026 --to 2065
lifeplan add asset --id cash --name "Cash" --amount 7800000 --as-of 2026-05-10
lifeplan validate
lifeplan forecast --format csv
lifeplan report --format markdown
```

---

# 24. Interface Boundary

Lifeplan CLI defines interfaces for:

```text
Project creation
Data inspection
Data changes
Change proposal and application
Validation
Forecasting
Explanation
Scenario management
Scenario comparison
Standard calculations
Export
Report generation
Templates
Diff and history
```

Lifeplan CLI does not define interfaces for:

```text
Investment recommendations
Financial product selection
Tax filing
Legal advice
Insurance diagnosis
Bank account synchronization
Brokerage synchronization
Daily household accounting
Receipt import
Cloud account management
Multi-user permissions
```

The CLI should remain focused on structured life planning work, deterministic calculations, validation, explanation, and export.
