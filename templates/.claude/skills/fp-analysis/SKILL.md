---
name: fp-analysis
description: Use when interpreting forecast output, identifying problem years or stressed metrics, comparing countermeasure scenarios, presenting recommendations, or conducting the annual review.
---

# fp-analysis — Finding Problems and Deciding Countermeasures

Speak to the client in Japanese. This skill is in English only to save tokens.

This skill covers procedure steps 8–10: 問題点の特定 / 対策の決定 / 年 1 回の見直し. Use it after `fp-scenarios` has produced a baseline and at least one alternative.

## 1. Identify problems by year, amount, and timing

"Anxious feeling" is not a problem. State problems with 年齢・金額・時期, e.g.:

- 「58〜65 歳に教育費と住宅費が重なり年間収支が年 −250 万円になる」
- 「2049 年（妻 64 歳）で液体資産が枯渇する」
- 「老後 30 年間で年間 80 万円の不足が累積する」

Tools to find them:

```
lifeplan check --project . --scenario <id> --format json
lifeplan explain year <year> --project . --scenario <id> --format json
lifeplan explain metric depletion_year --project . --scenario <id> --format json
lifeplan explain metric min_liquid_year --project . --scenario <id> --format json
lifeplan explain scenario-diff base conservative --year <Y> --project . --format json
lifeplan explain record income.<id> --project . --format json
lifeplan explain record expense.<id> --project . --format json
```

Patterns to look for:

- Assets going negative (枯渇).
- 住宅ローンが老後まで続いている.
- 現役期の投資が過大で生活費が不足.
- 現金が過剰でインフレに弱い.
- 保険料が家計比で重い.
- 老後の収支が継続的に赤字.
- 資産は足りているが「使う判断ができていない」=過剰節約.

## 2. Combine multiple small countermeasures

A single big fix is fragile. Combine 2–4 smaller changes:

- 支出を減らす (固定費削減 / 通信費 / 保険 / サブスク).
- 収入を増やす (転職 / 副業 / 配偶者の就労 / 給与交渉).
- 投資額を増減.
- 退職時期を 1〜3 年遅らせる.
- 住宅費の見直し (繰上返済 / 借換 / 売却 / 住み替え).
- 教育費の上限を決める (国公立中心 / 自宅通学).
- 現金 / 投資比率を変える.

Model each candidate as a scenario layer:

```
lifeplan scenario create plan-a --base base --name "対策A：固定費削減＋投資追加" --project .
lifeplan scenario set plan-a expense.fixed.amount <reduced> --project .
lifeplan scenario set plan-a assumption.savings_monthly.value <increased> --project .
```

Compare candidates:

```
lifeplan compare base plan-a plan-b plan-c --project . --format markdown
```

Present the trade-offs in Japanese with a small table: 対策 / 老後の最低資産 / 枯渇年 / 今年の負担増減.

## 3. Communicate recommendations

Structure every recommendation list in Japanese as three buckets so the client can act:

- **今年すること**: this month / this year — specific amounts and account moves.
- **3 年以内に決めること**: housing direction, education direction, savings target review.
- **長期で見直すこと**: retirement timing, asset allocation by age, inheritance.

Always pair recommendations with the numbers that justify them. Show the year-by-year impact via `compare` rather than asserting "this is better."

If the client agrees to enact a recommendation:

```
lifeplan propose set <type> <id> <field> <value> --project .
# client reviews summary, agrees
lifeplan apply <proposal-id> --project .
```

Or use `--dry-run` + confirm + run, depending on flow.

## 4. Reporting

For a written deliverable the client can keep:

```
lifeplan report --project . --scenario base --format markdown --output report.md
lifeplan export comparison --project . --scenario base conservative improvement --format markdown --output comparison.md
lifeplan export forecast --project . --scenario base --format csv --output forecast.csv
```

In the chat, summarize the report verbally in Japanese. Do not dump the file contents.

## 5. 年 1 回の見直し (annual review)

Update each year:

- 実際の収入 (前年実績).
- 実際の支出.
- 現在の資産残高 / 投資残高 / ローン残高.
- 子どもの進路の進捗 (受験結果, 進学先, 一人暮らしの有無).
- 働き方の変化 (転職, 育休復帰, 副業).
- 金利 / 物価 / 税制 / 制度変更で前提を変えるか.

Procedure:

1. `lifeplan list <type>` で現状を見せて、変わった点を一緒に拾う.
2. 変更を `set` または `propose`/`apply` で反映する (確認後).
3. 前年の見立てと実績の差分を `compare` で見せる (前年スナップショットを別シナリオで残しておくと比較しやすい).
4. 次の 1 年の予算 5 項目 (`fp-scenarios` の 「今年の予算」) を更新する.

## Discipline

- Recommendations are statements about numbers. If you don't have the number, run the right CLI command first.
- Avoid 商品名・銘柄名. Talk in categories (現金 / 株式インデックス / 債券 / 保険 など).
- 大きな変化があったら年次見直しを待たず、その都度シナリオを作り直す: 転職, 退職, 住宅購入, 出産, 進学, 介護, 相続.
- If you find the model itself is wrong (e.g., 退職金が抜けている), go back to `fp-intake` to fix data before continuing analysis.
