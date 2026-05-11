---
name: fp-intake
description: Use when interviewing the client about their current household state, family timeline, or upcoming large expenses, and when recording any of that information through the lifeplan CLI.
---

# fp-intake — Gathering the Client's Current State

Speak to the client in Japanese. This skill is in English only to save tokens.

This skill covers procedure steps 1–3: 現在地の把握 / 家族年表 / 大きな支出の見積もり. Use it whenever you are entering or updating data.

## What to ask

Cover these areas in roughly this order. Stay conversational; do not interrogate.

- **Income**
  - 手取り年収 / 手取り月収 (separate bonus from monthly).
  - Sources: salary, side income, business, pension, rental.
  - Each source: who earns it, expected period, growth assumption.
- **Expenses**
  - 固定費: rent or mortgage, utilities, communications, insurance, subscriptions.
  - 変動費: groceries, household goods, dining out, leisure, clothing, beauty, hobbies.
  - 特別費: travel, appliances, smartphones, ceremonies, family visits, car inspection, taxes.
  - Differences of even ¥10,000/month matter over decades — push for accuracy.
- **Assets**
  - 普通預金 / 定期預金 / 証券口座 / NISA / iDeCo / 個別株 / 暗号資産 / 不動産.
  - Aggregate totals; note rough allocation between cash and risk assets.
- **Liabilities**
  - 住宅ローン / 自動車ローン / 奨学金 / カードローン / リボ払い.
  - Outstanding balance, interest rate, end year.
- **Household**
  - 自分・配偶者・子・親 — names or initials, birth years, relationship.
  - Pending or hypothetical members (e.g., 第二子予定) — record as 仮置き.
- **Upcoming life events**
  - 住宅購入・リフォーム・修繕, 進学・受験・大学・一人暮らし, 親の介護, 車買い替え, 転職・退職・早期リタイア, 旅行, 独立, 相続.

Tell the client up front: 未確定でも仮置きで構いません. We will revise.

## How to record it via the CLI

Strict rule: do not edit `project.json` or any file under the workspace. Always go through the CLI.

When you need to know what fields a record accepts, look it up live:

```
lifeplan schema profile --format json
lifeplan schema income --format json
lifeplan schema expense --format json
lifeplan schema asset --format json
lifeplan schema liability --format json
lifeplan schema event --format json
lifeplan schema assumption --format json
```

When you need to see what's currently stored:

```
lifeplan list <type> --project . --format json
lifeplan get <type> <id> --project . --format json
```

### Family

Use `lifeplan add profile` (or the equivalent under the profile records command). Include each person's name, birth year, and relationship. Confirm the spelling of names in Japanese with the client before saving.

### Income / expenses

Use `lifeplan add income` and `lifeplan add expense` with `--dry-run` first. Confirm:

- 金額が手取りか / 月額か年額か.
- 期間 (`--from` / `--to`) — when does this start, when does it stop? Default `--to` to retirement year for salary.
- 伸び率や物価連動 (`--growth`) — if unknown, ask whether to leave at 0% or link to inflation.
- カテゴリ (`--category`).

After the client agrees, re-run without `--dry-run`. Or prefer `lifeplan propose add income ...` followed by `lifeplan apply <id>` once consent is on record.

### Assets and liabilities

Use `lifeplan add asset` / `lifeplan add liability`. For each asset, capture its current value and whether it is liquid cash or a return-bearing investment — this matters in `fp-scenarios` when you bucket funds.

### Big expenses

Major one-off events (車の買い替え, 大学入学金, リフォーム, 家具家電のまとめ買い) go in as `event`s with the year. Continuous large costs (大学 4 年間の学費, 介護期間の費用) go in as `expense` records with `--from` / `--to` years.

If you are unsure whether something is an `event` or an `expense`, run `lifeplan schema event` and `lifeplan schema expense` and choose based on whether the cost is single-year or multi-year.

### Assumptions

Inflation, 投資利回り, 給与上昇率, 退職年齢 などは `lifeplan add assumption`. Default to conservative numbers (e.g., inflation 2%, investment return 3%) and tell the client what you chose and why.

## Discipline

- Confirm every mutation in Japanese before applying. Show the client what amount, what years, what frequency you are about to save.
- If the CLI rejects your input, do not work around it by editing files. Re-check `schema`, fix the arguments, retry.
- After recording a batch of items, run `lifeplan validate --project . --format json` and `lifeplan list <type> --project . --format json` to verify the data is in. Translate the results into a short Japanese recap for the client.
- Note any 仮置き items so they can be revisited.

## When this skill ends

Once the basic picture (家族構成 + 主要な収入 / 支出 / 資産 / 負債 + 直近 10 年の大きな支出) is in, switch to `fp-scenarios` to run the first forecast.
