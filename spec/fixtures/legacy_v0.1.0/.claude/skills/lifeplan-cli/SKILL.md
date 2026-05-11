---
description: Use when changing Lifeplan CLI commands, options, outputs, exit codes, or command behavior.
---

# Lifeplan CLI Interface Skill

Read `docs/cli.md` before changing command behavior.

## Rules

- Keep public command behavior consistent with `docs/cli.md`.
- All inspection, validation, forecast, explanation, comparison, and proposal commands should support JSON output.
- Destructive or high-impact changes should support preview behavior.
- Prefer stable, scriptable output over conversational output.
- Do not expose implementation details in user-facing CLI help.
