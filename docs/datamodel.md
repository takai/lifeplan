# Lifeplan CLI Data Structure Definition

## 1. Purpose

This document defines the logical data structures used by Lifeplan CLI.

Lifeplan CLI manages structured life planning data for humans and LLM agents. The data is used to store assumptions, generate forecasts, validate consistency, compare scenarios, explain results, and export reports.

This document defines data concepts and fields only. It does not define storage format, database schema, file layout, serialization format, or implementation details.

## 2. Data Model Overview

Lifeplan CLI uses the following primary data types.

```text
Project
Profile
Person
Income
Expense
Asset
Liability
Event
Contribution
Assumption
Scenario
ScenarioOverride
Forecast
ForecastYear
Proposal
ValidationIssue
Explanation
Report
```

The central model is:

```text
Project
  ├── Profile
  │     └── People
  ├── Incomes
  ├── Expenses
  ├── Assets
  ├── Liabilities
  ├── Events
  ├── Contributions
  ├── Assumptions
  ├── Scenarios
  ├── Proposals
  └── Forecasts
```

A `Scenario` does not need to duplicate all data. It may represent a named set of overrides against the base project data.

## 3. Common Field Conventions

All primary records should share the following common fields where applicable.

| Field         | Type            | Required | Description                        |
| ------------- | --------------- | -------: | ---------------------------------- |
| `id`          | string          |      Yes | Stable machine-readable identifier |
| `name`        | string          |      Yes | Human-readable name                |
| `description` | string          |       No | Optional explanation               |
| `category`    | string          |       No | User-defined classification        |
| `tags`        | array of string |       No | Optional labels                    |
| `notes`       | string          |       No | Free-form notes                    |
| `created_at`  | datetime        |       No | Creation timestamp                 |
| `updated_at`  | datetime        |       No | Last update timestamp              |

### ID Rules

`id` should be stable and unique within each record type.

Recommended format:

```text
lowercase-kebab-case
```

Examples:

```text
salary
living-expense
cash
securities
mortgage
university-cost
base
conservative
```

## 4. Primitive Value Types

The data model uses the following primitive value types.

| Type            | Description            | Example                     |
| --------------- | ---------------------- | --------------------------- |
| `string`        | Text value             | `"Salary"`                  |
| `integer`       | Whole number           | `9600000`                   |
| `decimal`       | Decimal number         | `0.03`                      |
| `boolean`       | True or false          | `true`                      |
| `year`          | Calendar year          | `2026`                      |
| `date`          | Calendar date          | `2026-05-10`                |
| `datetime`      | Date and time          | `2026-05-10T09:00:00+09:00` |
| `currency_code` | ISO-like currency code | `JPY`                       |
| `array`         | Ordered list           | `["education", "child"]`    |
| `object`        | Structured object      | `{ "value": 0.02 }`         |

## 5. Amount Representation

Money amounts should be represented as integer minor-free currency amounts unless otherwise specified.

For JPY, this means:

```text
1000000 = 1,000,000 JPY
```

The data model should avoid storing formatted strings such as:

```text
"1,000,000 yen"
"¥1,000,000"
```

### Amount Fields

| Field      | Type          | Description            |
| ---------- | ------------- | ---------------------- |
| `amount`   | integer       | Monetary amount        |
| `currency` | currency_code | Currency of the amount |

If `currency` is omitted, the project default currency is used.

## 6. Period Representation

Many records are active only during a certain period.

| Field   | Type | Required | Description                   |
| ------- | ---- | -------: | ----------------------------- |
| `from`  | year |       No | First active year             |
| `to`    | year |       No | Last active year              |
| `year`  | year |       No | Single occurrence year        |
| `as_of` | date |       No | Date of valuation or snapshot |

Rules:

A recurring record should generally use `from` and `to`.

A one-time event should generally use `year`.

An asset snapshot should generally use `as_of`.

If both `year` and `from` / `to` are present, validation should check that their meaning is not ambiguous.

## 7. Frequency Representation

Recurring income, expense, saving, withdrawal, or payment records may use `frequency`.

Allowed values:

```text
once
monthly
yearly
```

Optional future values:

```text
quarterly
semiannual
weekly
daily
```

For MVP, `monthly` and `yearly` are sufficient for most recurring records.

## 8. Growth Representation

Some values change over time.

| Field    | Type              | Description        |
| -------- | ----------------- | ------------------ |
| `growth` | decimal or string | Annual growth rule |

Examples:

```text
0.01
0.03
inflation
salary_growth
none
```

Meaning:

| Value           | Meaning                                          |
| --------------- | ------------------------------------------------ |
| `0.01`          | Increase by 1% per year                          |
| `inflation`     | Use the project or scenario inflation assumption |
| `salary_growth` | Use the salary growth assumption                 |
| `none`          | No growth                                        |

## 9. Project

Represents one life planning workspace.

### Fields

| Field         | Type                | Required | Description                     |
| ------------- | ------------------- | -------: | ------------------------------- |
| `id`          | string              |      Yes | Project ID                      |
| `name`        | string              |      Yes | Project name                    |
| `currency`    | currency_code       |      Yes | Default currency                |
| `start_year`  | year                |      Yes | First projection year           |
| `end_year`    | year                |      Yes | Last projection year            |
| `profile`     | Profile             |      Yes | Household or individual profile |
| `incomes`     | array of Income     |       No | Income records                  |
| `expenses`    | array of Expense    |       No | Expense records                 |
| `assets`      | array of Asset      |       No | Asset records                   |
| `liabilities` | array of Liability  |       No | Liability records               |
| `events`      | array of Event      |       No | Life event records              |
| `contributions` | array of Contribution | No | Asset-to-asset transfers (NISA, iDeCo, etc.) |
| `assumptions` | array of Assumption |       No | Planning assumptions            |
| `scenarios`   | array of Scenario   |       No | Scenario definitions            |
| `proposals`   | array of Proposal   |       No | Pending change proposals        |

### Example

```json
{
  "id": "family-plan",
  "name": "Family Life Plan",
  "currency": "JPY",
  "start_year": 2026,
  "end_year": 2065
}
```

## 10. Profile

Represents the household or planning subject.

### Fields

| Field               | Type            | Required | Description                 |
| ------------------- | --------------- | -------: | --------------------------- |
| `id`                | string          |      Yes | Profile ID                  |
| `name`              | string          |      Yes | Profile name                |
| `people`            | array of Person |      Yes | People included in the plan |
| `primary_person_id` | string          |       No | Main person                 |
| `household_type`    | string          |       No | Household type              |
| `notes`             | string          |       No | Notes                       |

### Household Type Values

```text
single
couple
family
retirement
other
```

## 11. Person

Represents a person in the plan.

### Fields

| Field            | Type    | Required | Description                          |
| ---------------- | ------- | -------: | ------------------------------------ |
| `id`             | string  |      Yes | Person ID                            |
| `name`           | string  |      Yes | Person name or label                 |
| `relationship`   | string  |      Yes | Relationship to primary person       |
| `birth_year`     | year    |       No | Birth year                           |
| `birth_date`     | date    |       No | Birth date                           |
| `current_age`    | integer |       No | Current age if birth year is unknown |
| `retirement_age` | integer |       No | Planned retirement age               |
| `dependent`      | boolean |       No | Whether this person is a dependent   |

### Relationship Values

Recommended values:

```text
self
spouse
child
parent
other
```

### Validation Rules

At least one `Person` should exist.

If `birth_year` and `current_age` both exist, they should not conflict.

If age-based events are used, `birth_year` or equivalent age information should exist.

## 12. Income

Represents money received.

### Fields

| Field           | Type              | Required | Description                    |
| --------------- | ----------------- | -------: | ------------------------------ |
| `id`            | string            |      Yes | Income ID                      |
| `name`          | string            |      Yes | Income name                    |
| `amount`        | integer           |      Yes | Amount per frequency           |
| `currency`      | currency_code     |       No | Currency                       |
| `frequency`     | string            |      Yes | `monthly`, `yearly`, or `once` |
| `from`          | year              |       No | Start year                     |
| `to`            | year              |       No | End year                       |
| `year`          | year              |       No | One-time income year           |
| `growth`        | decimal or string |       No | Annual growth rule             |
| `category`      | string            |       No | Income category                |
| `person_id`     | string            |       No | Related person                 |
| `tax_treatment` | string            |       No | Optional tax handling label    |
| `notes`         | string            |       No | Notes                          |

### Category Examples

```text
salary
business
pension
bonus
investment
rental
other
```

### Example

```json
{
  "id": "salary",
  "name": "Salary",
  "amount": 9600000,
  "frequency": "yearly",
  "from": 2026,
  "to": 2045,
  "growth": 0.01,
  "category": "salary",
  "person_id": "self"
}
```

### Validation Rules

`amount` must be non-negative.

Recurring income should have `from` and `to`.

One-time income should have `year`.

If `person_id` is provided, it should reference an existing person.

## 13. Expense

Represents money spent.

### Fields

| Field       | Type              | Required | Description                    |
| ----------- | ----------------- | -------: | ------------------------------ |
| `id`        | string            |      Yes | Expense ID                     |
| `name`      | string            |      Yes | Expense name                   |
| `amount`    | integer           |      Yes | Amount per frequency           |
| `currency`  | currency_code     |       No | Currency                       |
| `frequency` | string            |      Yes | `monthly`, `yearly`, or `once` |
| `from`      | year              |       No | Start year                     |
| `to`        | year              |       No | End year                       |
| `year`      | year              |       No | One-time expense year          |
| `growth`    | decimal or string |       No | Annual growth rule             |
| `category`  | string            |       No | Expense category               |
| `person_id` | string            |       No | Related person                 |
| `essential` | boolean           |       No | Whether expense is essential   |
| `transitions` | array of Transition |   No | Lifestage transitions for amount/growth |
| `notes`     | string            |       No | Notes                          |

### Transition

A transition replaces the expense's effective `amount` (and optionally `growth`) starting from a given `year`. Use transitions to model the same expense changing across life stages (e.g. child independence, retirement, late elderly) without duplicating records.

| Field    | Type              | Required | Description                                                |
| -------- | ----------------- | -------: | ---------------------------------------------------------- |
| `year`   | year              |      Yes | First year the transition applies                          |
| `amount` | integer           |      Yes | Amount per frequency from this year                        |
| `growth` | decimal or string |       No | Growth rule from this year (defaults to expense `growth`)  |
| `label`  | string            |       No | Human-readable label (e.g. `child independence`)           |

Rules:

Transitions must be sorted by `year` in strictly ascending order.

Each transition `year` should lie within the expense's `from`/`to` range.

Growth compounds from the transition's `year` (not from the expense's `from`).

### Category Examples

```text
living
housing
education
insurance
medical
tax
leisure
transport
other
```

### Example

```json
{
  "id": "living",
  "name": "Living Expenses",
  "amount": 4200000,
  "frequency": "yearly",
  "from": 2026,
  "to": 2065,
  "growth": "inflation",
  "category": "living"
}
```

### Example with lifestage transitions

```json
{
  "id": "living",
  "name": "Living Expenses",
  "amount": 6400000,
  "frequency": "yearly",
  "from": 2026,
  "to": 2089,
  "growth": "inflation",
  "category": "living",
  "transitions": [
    {"year": 2033, "amount": 5400000, "label": "child independence"},
    {"year": 2037, "amount": 4900000, "label": "retirement"},
    {"year": 2052, "amount": 2560000, "label": "late elderly"}
  ]
}
```

### Validation Rules

`amount` must be non-negative.

Recurring expense should have `from` and `to`.

One-time expense should have `year`.

If `growth` references an assumption, that assumption should exist.

## 14. Asset

Represents an owned financial or non-financial asset.

### Fields

| Field       | Type              | Required | Description                        |
| ----------- | ----------------- | -------: | ---------------------------------- |
| `id`        | string            |      Yes | Asset ID                           |
| `name`      | string            |      Yes | Asset name                         |
| `amount`    | integer           |      Yes | Current value                      |
| `currency`  | currency_code     |       No | Currency                           |
| `as_of`     | date              |      Yes | Valuation date                     |
| `category`  | string            |       No | Asset category                     |
| `return`    | decimal or string |       No | Expected annual return             |
| `liquid`    | boolean           |       No | Whether easily usable for cashflow |
| `person_id` | string            |       No | Owner or related person            |
| `notes`     | string            |       No | Notes                              |

### Category Examples

```text
cash
deposit
securities
retirement_account
real_estate
insurance_cash_value
other
```

### Example

```json
{
  "id": "securities",
  "name": "Securities Account",
  "amount": 21000000,
  "as_of": "2026-05-10",
  "category": "securities",
  "return": 0.04,
  "liquid": true
}
```

### Validation Rules

`amount` must be non-negative.

`as_of` should be present.

If `return` references an assumption, that assumption should exist.

## 15. Liability

Represents debt or future repayment obligation.

### Fields

| Field                 | Type          | Required | Description                                 |
| --------------------- | ------------- | -------: | ------------------------------------------- |
| `id`                  | string        |      Yes | Liability ID                                |
| `name`                | string        |      Yes | Liability name                              |
| `principal`           | integer       |      Yes | Outstanding principal or original principal |
| `currency`            | currency_code |       No | Currency                                    |
| `rate`                | decimal       |       No | Annual interest rate                        |
| `from`                | year          |       No | Repayment start year                        |
| `to`                  | year          |       No | Repayment end year                          |
| `years`               | integer       |       No | Repayment duration                          |
| `payment`             | integer       |       No | Payment amount per frequency                |
| `frequency`           | string        |       No | Payment frequency                           |
| `category`            | string        |       No | Liability category                          |
| `secured_by_asset_id` | string        |       No | Related asset                               |
| `notes`               | string        |       No | Notes                                       |

### Category Examples

```text
mortgage
education_loan
car_loan
personal_loan
credit
other
```

### Example

```json
{
  "id": "mortgage",
  "name": "Mortgage",
  "principal": 45000000,
  "rate": 0.007,
  "from": 2026,
  "years": 35,
  "frequency": "monthly",
  "category": "mortgage"
}
```

### Validation Rules

`principal` must be non-negative.

At least one repayment definition should exist, such as `payment`, `years`, or `to`.

If `secured_by_asset_id` is provided, it should reference an existing asset.

## 16. Event

Represents a major one-time or limited-period life event.

### Fields

| Field         | Type          | Required | Description                     |
| ------------- | ------------- | -------: | ------------------------------- |
| `id`          | string        |      Yes | Event ID                        |
| `name`        | string        |      Yes | Event name                      |
| `year`        | year          |       No | Occurrence year                 |
| `from`        | year          |       No | Start year for multi-year event |
| `to`          | year          |       No | End year for multi-year event   |
| `amount`      | integer       |       No | Financial impact                |
| `currency`    | currency_code |       No | Currency                        |
| `category`    | string        |       No | Event category                  |
| `person_id`   | string        |       No | Related person                  |
| `impact_type` | string        |       No | Financial direction             |
| `notes`       | string        |       No | Notes                           |

### Impact Type Values

```text
income
expense
asset_change
liability_change
informational
```

### Category Examples

```text
education
retirement
housing
car
medical
inheritance
career
family
other
```

### Example

```json
{
  "id": "university-entry",
  "name": "University Entrance Cost",
  "year": 2031,
  "amount": 1500000,
  "category": "education",
  "impact_type": "expense",
  "person_id": "child-1"
}
```

### Validation Rules

Either `year` or `from` / `to` should exist.

If `impact_type` is `income`, `expense`, `asset_change`, or `liability_change`, `amount` should exist.

If `person_id` is provided, it should reference an existing person.

## 16a. Contribution

Represents an explicit transfer between two assets, such as a NISA or iDeCo
contribution from cash into an investment asset, or a lump-sum distribution
back into cash.

A `Contribution` differs from an `Expense` with `contribute_to`: it has no
cashflow effect (it is a pure asset-to-asset transfer) and carries explicit
`from_asset`, `to_asset`, and `tax_treatment` fields.

### Fields

| Field           | Type                  | Required | Description                                   |
| --------------- | --------------------- | -------: | --------------------------------------------- |
| `id`            | string                |      Yes | Contribution ID                               |
| `name`          | string                |      Yes | Human-readable name                           |
| `amount`        | integer or `"all"`    |      Yes | Per-frequency amount, or `"all"` to drain     |
| `currency`      | currency_code         |       No | Currency                                      |
| `frequency`     | string                |       No | `once`, `monthly`, `yearly`                   |
| `from`          | year                  |       No | Start year for periodic transfers             |
| `to`            | year                  |       No | End year for periodic transfers               |
| `year`          | year                  |       No | One-time transfer year                        |
| `from_asset`    | string                |      Yes | Source asset id (debited)                     |
| `to_asset`      | string                |      Yes | Destination asset id (credited)               |
| `tax_treatment` | string                |       No | Tax handling label                            |
| `person_id`     | string                |       No | Related person                                |
| `notes`         | string                |       No | Notes                                         |

### Tax Treatment Examples

```text
nisa
ideco_deduction
retirement_income
none
```

### Forecast Behavior

In the annual forecast:

- `amount` is debited from `from_asset` and credited to `to_asset`.
- `monthly` frequency is annualized (`amount * 12`).
- A periodic contribution is active when `from <= year <= to`.
- A one-time transfer applies in `year` only.
- If `amount` is the literal string `"all"`, the full current `from_asset`
  balance is transferred.

A contribution does **not** affect `income`, `expense`, or `net_cashflow`.

### Examples

```json
{
  "id": "nisa-contribution",
  "name": "NISA Contribution",
  "amount": 1200000,
  "frequency": "yearly",
  "from": 2026,
  "to": 2032,
  "from_asset": "cash",
  "to_asset": "mutual-funds",
  "tax_treatment": "nisa",
  "person_id": "self"
}
```

```json
{
  "id": "ideco-contribution",
  "name": "iDeCo Contribution",
  "amount": 23000,
  "frequency": "monthly",
  "from": 2026,
  "to": 2042,
  "from_asset": "cash",
  "to_asset": "dc-pension",
  "tax_treatment": "ideco_deduction",
  "person_id": "self"
}
```

```json
{
  "id": "dc-lumpsum",
  "name": "DC Pension Lump Sum",
  "year": 2037,
  "amount": "all",
  "from_asset": "dc-pension",
  "to_asset": "cash",
  "tax_treatment": "retirement_income"
}
```

### Validation Rules

`from_asset` and `to_asset` must reference existing assets.

`from_asset` and `to_asset` must differ.

If `person_id` is provided, it should reference an existing person.

Either `year` or `from`/`to` should be provided for periodic transfers.

## 17. Assumption

Represents a named planning assumption.

### Fields

| Field         | Type                        | Required | Description           |
| ------------- | --------------------------- | -------: | --------------------- |
| `id`          | string                      |      Yes | Assumption ID         |
| `name`        | string                      |      Yes | Human-readable name   |
| `value`       | decimal, integer, or string |      Yes | Assumption value      |
| `unit`        | string                      |       No | Unit of value         |
| `category`    | string                      |       No | Assumption category   |
| `description` | string                      |       No | Meaning of assumption |
| `source`      | string                      |       No | Source or rationale   |
| `notes`       | string                      |       No | Notes                 |

### Category Examples

```text
inflation
return
income_growth
retirement
education
housing
other
```

### Common Assumption IDs

```text
inflation
cash_return
investment_return
salary_growth
retirement_age
```

### Example

```json
{
  "id": "inflation",
  "name": "Inflation Rate",
  "value": 0.02,
  "unit": "annual_rate",
  "category": "inflation",
  "description": "Default annual inflation rate used for inflation-linked expenses."
}
```

### Validation Rules

Referenced assumptions should exist.

Rate assumptions should generally be decimal values.

Age assumptions should generally be integer values.

## 18. Scenario

Represents a named planning case.

A scenario may be the base case or an alternative case with overrides.

### Fields

| Field         | Type                      | Required | Description               |
| ------------- | ------------------------- | -------: | ------------------------- |
| `id`          | string                    |      Yes | Scenario ID               |
| `name`        | string                    |      Yes | Human-readable name       |
| `base`        | string                    |       No | Base scenario ID          |
| `overrides`   | array of ScenarioOverride |       No | Scenario-specific changes |
| `description` | string                    |       No | Scenario explanation      |
| `tags`        | array of string           |       No | Optional labels           |

### Example

```json
{
  "id": "conservative",
  "name": "Conservative Case",
  "base": "base",
  "overrides": [
    {
      "path": "assumptions.investment_return.value",
      "value": 0.01
    },
    {
      "path": "assumptions.inflation.value",
      "value": 0.03
    }
  ]
}
```

### Validation Rules

If `base` is present, it should reference an existing scenario.

Each override path should reference a valid field or valid add/remove operation.

Circular scenario inheritance is invalid.

## 19. ScenarioOverride

Represents a scenario-specific change.

### Fields

| Field         | Type   | Required | Description                    |
| ------------- | ------ | -------: | ------------------------------ |
| `op`          | string |       No | Operation type                 |
| `path`        | string |      Yes | Path to target field or record |
| `value`       | any    |       No | New value                      |
| `before`      | any    |       No | Optional previous value        |
| `description` | string |       No | Explanation                    |

### Operation Values

```text
set
add
remove
```

If `op` is omitted, `set` is assumed.

### Example

```json
{
  "op": "set",
  "path": "incomes.salary.to",
  "value": 2040,
  "description": "Early retirement scenario"
}
```

## 20. Forecast

Represents calculated projection output.

Forecasts are derived data. They should be reproducible from project data and assumptions.

### Fields

| Field          | Type                     | Required | Description               |
| -------------- | ------------------------ | -------: | ------------------------- |
| `scenario_id`  | string                   |      Yes | Scenario used             |
| `from`         | year                     |      Yes | Forecast start year       |
| `to`           | year                     |      Yes | Forecast end year         |
| `years`        | array of ForecastYear    |      Yes | Yearly results            |
| `summary`      | ForecastSummary          |       No | Key metrics               |
| `warnings`     | array of ValidationIssue |       No | Forecast-related warnings |
| `generated_at` | datetime                 |       No | Generation timestamp      |

## 21. ForecastYear

Represents one year of forecast output.

### Fields

| Field               | Type    | Required | Description                           |
| ------------------- | ------- | -------: | ------------------------------------- |
| `year`              | year    |      Yes | Calendar year                         |
| `ages`              | object  |       No | Person ages by person ID              |
| `income`            | integer |      Yes | Total income                          |
| `expense`           | integer |      Yes | Total expense                         |
| `event_income`      | integer |       No | One-time event income                 |
| `event_expense`     | integer |       No | One-time event expense                |
| `net_cashflow`      | integer |      Yes | Income minus expense and event impact |
| `asset_balance`     | integer |      Yes | Total asset balance                   |
| `liability_balance` | integer |       No | Total liability balance               |
| `net_worth`         | integer |       No | Assets minus liabilities              |
| `details`           | object  |       No | Item-level breakdown                  |

### Example

```json
{
  "year": 2031,
  "ages": {
    "self": 50,
    "child-1": 18
  },
  "income": 9800000,
  "expense": 6500000,
  "event_expense": 1500000,
  "net_cashflow": 1800000,
  "asset_balance": 38100000,
  "liability_balance": 0,
  "net_worth": 38100000
}
```

## 22. ForecastSummary

Represents key metrics from a forecast.

### Fields

| Field                        | Type         | Description                       |
| ---------------------------- | ------------ | --------------------------------- |
| `minimum_asset_balance`      | integer      | Lowest asset balance              |
| `minimum_asset_balance_year` | year         | Year of lowest asset balance      |
| `first_negative_asset_year`  | year or null | First year assets become negative |
| `asset_at_retirement`        | integer      | Asset balance at retirement       |
| `retirement_year`            | year         | Retirement year                   |
| `total_income`               | integer      | Total income over forecast        |
| `total_expense`              | integer      | Total expense over forecast       |
| `final_asset_balance`        | integer      | Final asset balance               |

## 23. Proposal

Represents a pending change created by an agent or user.

### Fields

| Field        | Type                     | Required | Description              |
| ------------ | ------------------------ | -------: | ------------------------ |
| `id`         | string                   |      Yes | Proposal ID              |
| `summary`    | string                   |      Yes | Human-readable summary   |
| `status`     | string                   |      Yes | Proposal status          |
| `changes`    | array of ProposedChange  |      Yes | Proposed changes         |
| `validation` | array of ValidationIssue |       No | Validation result        |
| `impact`     | object                   |       No | Optional forecast impact |
| `created_by` | string                   |       No | Creator                  |
| `created_at` | datetime                 |       No | Creation timestamp       |
| `applied_at` | datetime                 |       No | Application timestamp    |

### Status Values

```text
pending
applied
discarded
stale
failed
```

## 24. ProposedChange

Represents one change inside a proposal.

### Fields

| Field         | Type   | Required | Description               |
| ------------- | ------ | -------: | ------------------------- |
| `op`          | string |      Yes | `add`, `set`, or `remove` |
| `record_type` | string |      Yes | Target record type        |
| `record_id`   | string |       No | Target record ID          |
| `path`        | string |       No | Target field path         |
| `before`      | any    |       No | Value before change       |
| `after`       | any    |       No | Value after change        |
| `description` | string |       No | Change explanation        |

### Example

```json
{
  "op": "set",
  "record_type": "assumption",
  "record_id": "inflation",
  "path": "value",
  "before": 0.02,
  "after": 0.03,
  "description": "Increase inflation assumption for conservative scenario."
}
```

## 25. ValidationIssue

Represents an error, warning, or informational issue.

### Fields

| Field           | Type   | Required | Description                     |
| --------------- | ------ | -------: | ------------------------------- |
| `severity`      | string |      Yes | Severity                        |
| `code`          | string |      Yes | Stable issue code               |
| `message`       | string |      Yes | Human-readable message          |
| `record_type`   | string |       No | Related record type             |
| `record_id`     | string |       No | Related record ID               |
| `path`          | string |       No | Related field path              |
| `suggested_fix` | object |       No | Machine-readable fix suggestion |

### Severity Values

```text
error
warning
info
```

### Example

```json
{
  "severity": "warning",
  "code": "INCOME_AFTER_RETIREMENT",
  "message": "Salary income continues after the configured retirement age.",
  "record_type": "income",
  "record_id": "salary",
  "path": "to",
  "suggested_fix": {
    "set": 2045
  }
}
```

## 26. Explanation

Represents an explanation of a forecast value, year, metric, or scenario difference.

### Fields

| Field          | Type                            | Required | Description                    |
| -------------- | ------------------------------- | -------: | ------------------------------ |
| `target_type`  | string                          |      Yes | Explanation target type        |
| `target`       | string                          |      Yes | Target identifier              |
| `scenario_id`  | string                          |       No | Scenario                       |
| `year`         | year                            |       No | Related year                   |
| `metric`       | string                          |       No | Related metric                 |
| `summary`      | string                          |      Yes | Human-readable explanation     |
| `contributors` | array of ExplanationContributor |       No | Records contributing to result |
| `assumptions`  | array of string                 |       No | Assumption IDs used            |
| `warnings`     | array of ValidationIssue        |       No | Related warnings               |

### Target Type Values

```text
year
metric
scenario_diff
record
```

## 27. ExplanationContributor

Represents a data record that contributed to an explanation.

### Fields

| Field         | Type    | Description                 |
| ------------- | ------- | --------------------------- |
| `record_type` | string  | Record type                 |
| `record_id`   | string  | Record ID                   |
| `name`        | string  | Record name                 |
| `amount`      | integer | Contribution amount         |
| `description` | string  | Explanation of contribution |

## 28. Report

Represents a generated human-readable output.

### Fields

| Field          | Type                   | Required | Description          |
| -------------- | ---------------------- | -------: | -------------------- |
| `id`           | string                 |       No | Report ID            |
| `title`        | string                 |      Yes | Report title         |
| `scenario_id`  | string                 |      Yes | Scenario             |
| `from`         | year                   |      Yes | Start year           |
| `to`           | year                   |      Yes | End year             |
| `sections`     | array of ReportSection |      Yes | Report sections      |
| `generated_at` | datetime               |       No | Generation timestamp |

## 29. ReportSection

Represents a section in a generated report.

### Fields

| Field | Type | Description |
|---|---|
| `title` | string | Section title |
| `kind` | string | Section type |
| `content` | string or object | Section content |

### Section Kind Values

```text
summary
assumptions
forecast
validation
scenario_comparison
explanation
notes
```

## 30. Record Type Names

Canonical singular record type names:

```text
profile
person
income
expense
asset
liability
event
assumption
scenario
proposal
forecast
report
```

Canonical plural names:

```text
profiles
people
incomes
expenses
assets
liabilities
events
assumptions
scenarios
proposals
forecasts
reports
```

CLI commands may accept plural aliases, but data structures should use canonical singular names when referring to a record type.

## 31. Path Syntax

Paths are used for scenario overrides, proposed changes, validation issues, and explanations.

Recommended path format:

```text
<record-type>.<record-id>.<field>
```

Examples:

```text
income.salary.amount
expense.living.growth
asset.securities.return
assumption.inflation.value
scenario.conservative.overrides
```

For nested values:

```text
profile.people.self.birth_year
forecast.2031.asset_balance
```

## 32. Data Relationship Rules

The following references should be validated.

| Source           | Field                 | Target                        |
| ---------------- | --------------------- | ----------------------------- |
| Income           | `person_id`           | Person                        |
| Expense          | `person_id`           | Person                        |
| Asset            | `person_id`           | Person                        |
| Event            | `person_id`           | Person                        |
| Liability        | `secured_by_asset_id` | Asset                         |
| Contribution     | `from_asset`          | Asset                         |
| Contribution     | `to_asset`            | Asset                         |
| Contribution     | `person_id`           | Person                        |
| Scenario         | `base`                | Scenario                      |
| ScenarioOverride | `path`                | Existing or valid target path |
| Growth field     | string value          | Assumption                    |
| Return field     | string value          | Assumption                    |

## 33. Validation Rules

The data model should support at least the following validation rules.

### Structural Validation

```text
Required fields exist
IDs are unique within record type
Referenced records exist
Field types are valid
Enum values are valid
```

### Period Validation

```text
from <= to
year is within project start_year and end_year
Recurring records have a valid period
One-time records have a valid year
Asset valuation date exists
```

### Financial Validation

```text
Amounts are non-negative unless explicitly allowed
Rates are within reasonable bounds
Liability repayment information is sufficient
Currency is valid or inherited from project
```

### Scenario Validation

```text
Base scenario exists
Scenario inheritance has no cycles
Override paths are valid
Scenario changes do not create invalid data
```

### Forecast Validation

```text
Forecast period is within project period
Forecast can be calculated from available data
No blocking validation errors exist
Referenced assumptions are available
```

## 34. Sign Convention

Stored `amount` values for income, expense, and events should generally be non-negative.

Direction should be represented by record type or `impact_type`, not by negative numbers.

Examples:

```text
Income amount:  9600000
Expense amount: 4200000
Event amount:   1500000 with impact_type = expense
```

Calculated outputs may use signed values where useful.

Example:

```text
net_cashflow = income - expense - event_expense + event_income
```

This convention reduces ambiguity and helps LLM agents avoid sign mistakes.

## 35. Required MVP Data Structures

For MVP, the following structures are required.

```text
Project
Profile
Person
Income
Expense
Asset
Liability
Event
Contribution
Assumption
Scenario
ScenarioOverride
Forecast
ForecastYear
ForecastSummary
Proposal
ProposedChange
ValidationIssue
Explanation
ExplanationContributor
```

The following structures can be added later.

```text
Report
ReportSection
Template
AuditLog
DataSource
```

## 36. Out-of-Scope Data Structures for MVP

The MVP should not define detailed structures for:

```text
Tax return data
Insurance policy diagnosis
Investment product recommendations
Bank transactions
Credit card transactions
Receipts
Daily household accounting
Brokerage holdings
Legal documents
Estate planning documents
Advisor-client permissions
```

These may be added later only if the product scope expands.

## 37. Example Minimal Project Data

```json
{
  "id": "family-plan",
  "name": "Family Life Plan",
  "currency": "JPY",
  "start_year": 2026,
  "end_year": 2065,
  "profile": {
    "id": "default",
    "name": "Default Profile",
    "people": [
      {
        "id": "self",
        "name": "Self",
        "relationship": "self",
        "birth_year": 1981,
        "retirement_age": 60
      },
      {
        "id": "child-1",
        "name": "Child 1",
        "relationship": "child",
        "birth_year": 2010,
        "dependent": true
      }
    ]
  },
  "assumptions": [
    {
      "id": "inflation",
      "name": "Inflation Rate",
      "value": 0.02,
      "unit": "annual_rate"
    },
    {
      "id": "investment_return",
      "name": "Investment Return",
      "value": 0.04,
      "unit": "annual_rate"
    }
  ],
  "incomes": [
    {
      "id": "salary",
      "name": "Salary",
      "amount": 9600000,
      "frequency": "yearly",
      "from": 2026,
      "to": 2045,
      "growth": 0.01,
      "category": "salary",
      "person_id": "self"
    }
  ],
  "expenses": [
    {
      "id": "living",
      "name": "Living Expenses",
      "amount": 4200000,
      "frequency": "yearly",
      "from": 2026,
      "to": 2065,
      "growth": "inflation",
      "category": "living"
    }
  ],
  "assets": [
    {
      "id": "cash",
      "name": "Cash",
      "amount": 7800000,
      "as_of": "2026-05-10",
      "category": "cash",
      "return": 0.001,
      "liquid": true
    },
    {
      "id": "securities",
      "name": "Securities Account",
      "amount": 21000000,
      "as_of": "2026-05-10",
      "category": "securities",
      "return": "investment_return",
      "liquid": true
    }
  ],
  "events": [
    {
      "id": "university-entry",
      "name": "University Entrance Cost",
      "year": 2031,
      "amount": 1500000,
      "category": "education",
      "impact_type": "expense",
      "person_id": "child-1"
    }
  ],
  "scenarios": [
    {
      "id": "base",
      "name": "Base Case"
    },
    {
      "id": "conservative",
      "name": "Conservative Case",
      "base": "base",
      "overrides": [
        {
          "op": "set",
          "path": "assumption.investment_return.value",
          "value": 0.01
        },
        {
          "op": "set",
          "path": "assumption.inflation.value",
          "value": 0.03
        }
      ]
    }
  ]
}
```

## 38. Data Structure Boundary

Lifeplan CLI data structures define:

```text
Planning subjects
Recurring income and expenses
Current assets
Current and future liabilities
Major life events
Planning assumptions
Scenarios and overrides
Forecast outputs
Validation issues
Change proposals
Explanations
Reports
```

Lifeplan CLI data structures do not define:

```text
Actual bank transaction history
Detailed accounting ledger
Tax filing records
Insurance policy recommendation data
Investment product universe
Legal advice records
Medical records
Receipt-level spending data
Cloud user accounts
Advisor-client access control
```

The model should remain focused on life planning assumptions, deterministic calculations, validation, explanation, and scenario comparison.
