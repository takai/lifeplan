---
name: fp-scenarios
description: Use when running the baseline forecast, organizing cash vs. investment buckets, deciding this year's budget, or building alternative scenarios such as conservative or improvement cases.
---

# fp-scenarios — Building Forecasts and Scenarios

Speak to the client in Japanese. This skill is in English only to save tokens.

This skill covers procedure steps 4–7: キャッシュフロー表 / 資金の置き場所 / 今年の予算 / 複数シナリオ. Use it once the intake is in good enough shape to project.

## 1. Baseline forecast

Run the base scenario first. Show the client a small, readable slice — do not dump the whole JSON.

```
lifeplan forecast --project . --scenario base --format json
lifeplan forecast --project . --scenario base --from <Y1> --to <Y2> --format table
```

What to highlight in Japanese:

- 今年〜3 年: actual-feeling numbers; verify with the client that this matches their lived sense.
- 5〜10 年: identify the year of any large dip or rebound.
- 退職前後: peak assets, then drawdown shape.
- 90 歳付近: does the plan stay solvent.

If the CLI reports validation issues, fix the data via `set` / `propose` (never by editing files) before discussing results.

Use `--by-person` when income/expense responsibility differs between spouses and the client wants to see that split.

## 2. 資金の置き場所 (cash vs. investment)

Translate the procedure book's rule of thumb into the model:

- 数年以内に使うお金 (生活防衛資金 / 近い教育費 / 引っ越し / 車検 / 旅行) → 現金で保持.
- 10 年以内に使う可能性のあるお金 → 現金厚めに、一部だけ投資.
- 15 年以上先のお金 (老後 / 遠い教育費) → 投資中心.

In the data this maps to:

- The split between cash-type `asset` records and return-bearing `asset` records.
- `assumption.investment_return.value` for the return-bearing portion.
- Liquidity is reflected in the `liquid_balance` column of the forecast.

When the client's current allocation is mismatched (e.g., a big chunk in stocks but a tuition bill in 3 years), surface that explicitly and propose a rebalance as a scenario change rather than a recommendation in isolation.

## 3. 今年の予算

The most important deliverable of this phase. Always produce the following five lines, in Japanese, for the standard scenario:

- 今年いくら貯めるか (現金積み増し額).
- 今年いくら投資するか.
- 今年いくら使ってよいか (生活費の上限).
- 今年どの支出を見直すか (具体的に固定費名で).
- 今年どの資金を現金で残すか.

Derive these numbers from the forecast and the cash/investment split, not from gut feel.

If 投資 が生活を圧迫しているなら減らす提案、老後が不足なら固定費見直しを提案、というように手順書の "毎月数万円改善" の発想で具体化する。

## 4. シナリオ作成

Always build at least three: 標準 / 保守 / 改善.

```
lifeplan scenario list --project . --format json
lifeplan scenario create conservative --base base --name "保守ケース" --project .
lifeplan scenario create improvement --base base --name "改善ケース" --project .
```

Then layer overrides. Use paths like `assumption.<id>.value`, `income.<id>.to`, `expense.<id>.amount`, `event.<id>.year`.

```
lifeplan scenario set conservative assumption.investment_return.value 0.01 --project .
lifeplan scenario set conservative assumption.inflation.value 0.03 --project .
lifeplan scenario set improvement expense.living.amount <reduced> --project .
lifeplan scenario set improvement assumption.savings_monthly.value <increased> --project .
```

Suggested override patterns:

- 保守ケース: 投資利回り 低め / 物価上昇率 高め / 給与伸び 0 / 退職 早まる / 教育費 高め.
- 改善ケース: 固定費 削減 / 投資額 増加 / 退職 遅らせる / 副業.
- 必要なら "住宅購入あり" "賃貸継続" のような構造ケース.

After making overrides, confirm with `lifeplan scenario list` and verify the overrides took effect via `lifeplan forecast --scenario <id>`.

## 5. 比較と感度

```
lifeplan compare base conservative improvement --project . --format markdown
```

For two-axis exploration (e.g., 物価上昇率 × 投資利回り, 教育費 × 退職年齢):

```
lifeplan sensitivity \
  --project . \
  --base-scenario base \
  --x-axis "assumption.inflation.value" --x-values 0.01,0.02,0.03,0.04 \
  --y-axis "assumption.investment_return.value" --y-values 0.02,0.03,0.04,0.05 \
  --metric depletion_year \
  --format markdown
```

Bring the table back to the client in Japanese: 「物価が 3%, 利回り 2% の場合、資産は 2058 年に底をつきます」.

## Discipline

- Every scenario mutation is confirmed before applying. Prefer `--dry-run` or the propose/apply flow.
- Do not duplicate base data into derived scenarios. Use overrides only — that is what the scenario system is for.
- When showing forecasts to the client, narrate the **shape** first (rising, plateau, drawdown, depletion) and only then quote individual numbers.

## When this skill ends

Once the client has a standard + at least one alternative scenario and an agreed this-year budget, switch to `fp-analysis` to identify problems and decide countermeasures.
