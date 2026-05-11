---
description: Use when changing Lifeplan CLI data structures, record fields, validation rules, or examples.
---

# Lifeplan Data Model Skill

Read `docs/datamodel.md` before changing data structures.

## Rules

- Treat `docs/datamodel.md` as the source of truth for logical records and fields.
- Do not introduce new record types without updating the data model document.
- Keep stored money amounts as integers.
- Keep income, expense, and event amounts non-negative unless the data model explicitly allows otherwise.
- Represent direction using record type or `impact_type`, not negative stored amounts.
- Add or update validation rules when adding new fields.
