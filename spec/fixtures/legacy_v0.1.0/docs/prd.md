# PRD: Lifeplan CLI for LLM-Assisted Financial Planning

## 1. Product Summary

Lifeplan CLI is a command-line tool that helps humans and LLM agents create, maintain, validate, and explain life planning data.

The product is not a full financial planning application that attempts to replace human judgment. Instead, it provides a structured working environment for recurring life planning tasks: organizing assumptions, managing planning data, running standard calculations, checking consistency, comparing scenarios, and exporting results.

The primary user is an LLM agent acting on behalf of a human planner. The human remains responsible for decisions, assumptions, and final interpretation. The CLI provides reliable structure, repeatable calculations, and auditable outputs.

## 2. Problem

Life planning work often involves repeated manual tasks:

People collect family, income, expense, asset, liability, and event data. They convert that data into annual projections. They manually apply assumptions such as inflation, salary growth, investment returns, retirement timing, education costs, and housing costs. They compare scenarios, check for inconsistencies, and prepare human-readable summaries.

These tasks are repetitive and error-prone, especially when performed in spreadsheets or documents without strong validation.

LLM agents can help with interviews, summarization, and explanation, but they are not reliable enough to directly edit structured financial planning files or perform all calculations unaudited. They need a stable tool that can store data, validate inputs, perform deterministic calculations, and return machine-readable results.

## 3. Target Users

The primary user is an LLM agent assisting a human with life planning.

The secondary user is a human planner, engineer, financial advisor, or individual user who wants a text-based, reproducible way to manage life planning assumptions and calculations.

The product is especially useful for users who prefer CLI workflows, Git-managed files, structured data, Markdown reports, CSV exports, or agent-assisted planning workflows.

## 4. Goals

The product should make life planning work more structured, repeatable, and auditable.

It should allow an LLM agent to safely inspect existing planning data, propose changes, validate those changes, run projections, explain results, and produce human-readable outputs.

It should reduce manual spreadsheet work for common tasks such as annual cashflow projection, inflation adjustment, retirement asset projection, education cost scheduling, loan repayment estimation, and scenario comparison.

It should make assumptions explicit so that a human can review what changed and why.

## 5. Non-Goals

The product will not provide financial advice.

The product will not decide the correct life plan for the user.

The product will not optimize investments, recommend financial products, or automatically select tax strategies.

The product will not attempt to fully model tax, pension, inheritance, insurance, or legal systems in the first version.

The product will not replace spreadsheets, documents, or human review. It will support them.

## 6. Product Principles

The product should be agent-friendly first.

Every important operation should be inspectable, validateable, and explainable. The CLI should assume that an LLM agent may misunderstand user intent, so destructive or high-impact changes should be previewable before application.

The product should be deterministic.

Given the same data and assumptions, the same command should produce the same result.

The product should be transparent.

Outputs should show not only final numbers but also the assumptions and source data behind them.

The product should stay focused.

It should manage planning data and calculations, not become a general personal finance, budgeting, accounting, or investment management platform.

## 7. Core Use Cases

### Use Case 1: Create a new planning workspace

A user or LLM agent starts a new life planning project and creates an initial structure for profile data, assumptions, incomes, expenses, assets, liabilities, events, and scenarios.

Expected outcome: the project has a valid initial data structure that can be inspected and extended.

### Use Case 2: Add structured planning data

An LLM agent interviews the human and adds data such as salary income, living expenses, current savings, investment assets, education costs, retirement timing, or housing-related liabilities.

Expected outcome: the data is stored in a structured form and can be listed, reviewed, updated, or removed.

### Use Case 3: Validate planning data

An LLM agent checks whether the current plan has missing fields, inconsistent periods, duplicate IDs, unrealistic values, or assumptions that conflict with registered events.

Expected outcome: the CLI returns clear validation results with severity, affected data path, and suggested next action.

### Use Case 4: Generate annual projections

A user or agent generates a year-by-year projection of income, expenses, net cashflow, asset balances, liabilities, and major life events.

Expected outcome: the CLI outputs a projection that can be read by a human or consumed by an agent.

### Use Case 5: Explain a number

A human asks why assets drop in a certain year, why retirement assets changed, or why one scenario differs from another.

Expected outcome: the CLI can explain which income, expense, event, asset return, or liability item contributed to the result.

### Use Case 6: Compare scenarios

A user wants to compare a base scenario with alternatives such as lower investment return, higher inflation, earlier retirement, private university costs, or housing purchase.

Expected outcome: the CLI produces a concise comparison showing changed assumptions and key financial impact.

### Use Case 7: Export planning outputs

A user wants to copy results into a spreadsheet, report, or proposal.

Expected outcome: the CLI can export projections, scenario comparisons, and summaries in formats suitable for human review and external editing.

## 8. MVP Scope

The MVP should include the minimum product surface needed for an LLM agent to safely support life planning work.

### Data Management

The product should support structured records for:

Profile
Income
Expense
Asset
Liability
Event
Assumption
Scenario

Each record should have a stable identifier, human-readable name, amount where applicable, active period where applicable, and category where applicable.

### Agent-Oriented Inspection

The product should provide commands or interactions equivalent to:

Show project status
List records by type
Get a specific record
Show schema or expected fields
Show current assumptions
Show available scenarios

The agent should be able to understand what exists before proposing changes.

### Safe Change Workflow

The product should support previewing changes before applying them.

An LLM agent should be able to propose an addition, update, or deletion and receive a structured summary of what would change.

The human or controlling workflow should be able to apply the change only after review.

### Validation

The MVP should detect common planning issues:

Missing required fields
Invalid amounts
Invalid date or year ranges
Duplicate IDs
Events outside the planning period
Income ending before the planning period starts
Expenses without a period
Assets with missing valuation date
Liabilities with missing repayment assumptions
Scenarios that reference missing records
Forecasts that cannot be calculated from available data

### Forecasting

The MVP should generate annual projections using registered data and assumptions.

The projection should show:

Year
Age where available
Income
Expenses
Events
Net cashflow
Assets
Liabilities
Net worth or financial assets, depending on configured view

### Basic Calculations

The MVP should include standard calculations needed in life planning:

Future value
Present value
Recurring savings projection
Required savings for a target amount
Withdrawal estimate
Loan repayment estimate
Inflation-adjusted amount
Growth table

These calculations should be usable independently and also as part of projections where appropriate.

### Scenario Comparison

The MVP should allow a user or agent to create a scenario from a base scenario, override selected assumptions or records, and compare results.

The comparison should show changed assumptions, key result differences, and major risk points.

### Explanation

The MVP should support explaining projection results for a selected year or metric.

For example, the tool should be able to answer:

Why is cashflow negative in this year?
Which records contributed to this year’s expenses?
Why does this scenario produce lower assets at retirement?
Which assumption has the largest visible impact?

### Export

The MVP should support human-readable and machine-readable exports.

Minimum required outputs:

JSON for LLM agents
CSV for spreadsheets
Markdown for reports

## 9. Out of Scope for MVP

Detailed tax calculation
Detailed pension system modeling
Insurance product analysis
Investment product recommendation
Automatic asset allocation advice
Household budget tracking
Bank account or brokerage integration
Receipt import
Daily transaction management
Regulatory compliance features
PDF generation
Cloud sync
Multi-user collaboration
Advisor-client workflow management

## 10. User Stories

As an LLM agent, I want to inspect the current life planning data before making changes, so that I do not overwrite or duplicate existing assumptions.

As an LLM agent, I want to propose changes separately from applying them, so that the human can review important financial assumptions before they become part of the plan.

As a human user, I want to see which assumptions produced a projection, so that I can decide whether the result is reasonable.

As a human user, I want to compare multiple scenarios, so that I can understand the impact of retirement age, education costs, inflation, or investment returns.

As an LLM agent, I want validation errors to include precise locations and suggested fixes, so that I can correct structured data reliably.

As a human user, I want to export results to CSV and Markdown, so that I can continue working in spreadsheets or documents.

## 11. Key Product Requirements

The product must keep planning data structured and reviewable.

The product must support both human-readable and agent-readable output.

The product must allow projections to be regenerated from stored assumptions.

The product must make scenario differences explicit.

The product must make validation results actionable.

The product must avoid making financial recommendations as if they were authoritative advice.

The product must clearly distinguish input assumptions, calculated results, warnings, and explanations.

## 12. Agent-Specific Requirements

The product should assume that an LLM agent may use it as a tool.

Therefore, the product should prioritize stable command behavior, structured responses, non-ambiguous error messages, and dry-run workflows.

Validation messages should include:

Severity
Error or warning code
Human-readable message
Affected record or field
Suggested correction where possible

Change previews should include:

Type of change
Affected record
Before and after values
Potential projection impact where available

Forecast outputs should include enough metadata for an agent to explain the result without inventing unsupported reasoning.

## 13. Success Metrics

The product is successful if an LLM agent can complete a basic life planning workflow with minimal manual file editing.

Potential success metrics:

A new user can create a valid first plan within 15 minutes.

An LLM agent can add or update planning assumptions without directly editing raw files.

A projection can be regenerated consistently from stored data.

Validation catches common mistakes before report generation.

A human can understand why a major year or scenario changed.

A spreadsheet-ready CSV and human-readable Markdown report can be produced from the same data.

## 14. Release Criteria

The MVP is ready when it can support the following end-to-end workflow:

Create a new planning project.
Add profile, income, expense, asset, liability, event, and assumption data.
Validate the data.
Generate an annual projection.
Explain a selected year.
Create a second scenario.
Compare the second scenario with the base scenario.
Export the result to CSV and Markdown.

The release should not require users to understand implementation details.

## 15. Risks and Open Questions

The largest product risk is scope creep. Life planning touches taxes, pensions, insurance, investments, housing, education, inheritance, and legal systems. The product must stay focused on structured planning data and deterministic calculations.

Another risk is false confidence. The product should avoid presenting projections as predictions. It should frame outputs as scenario-based estimates derived from explicit assumptions.

A third risk is LLM overreach. The agent may present assumptions as facts or make changes without adequate user review. The product should support workflows that separate proposed changes from applied changes.

Open questions:

Should the default data model be optimized for individual users, households, or advisor-client workflows?

Should the first version focus on Japanese life planning assumptions, or remain country-neutral?

How much built-in sample data should be included?

Should education, retirement, and housing templates be included in MVP, or added later?

How strongly should the product encourage scenario comparison before report export?

## 16. Positioning

Lifeplan CLI is a structured life planning workbench for humans and LLM agents.

It is not a spreadsheet replacement.
It is not a financial advisor.
It is not a household accounting app.

It is a reliable command-line layer for managing assumptions, running standard life planning calculations, validating planning data, and producing explainable outputs.

## 17. One-Line Product Description

Lifeplan CLI helps LLM agents and humans manage life planning data, run repeatable calculations, validate assumptions, compare scenarios, and export explainable financial projections.
