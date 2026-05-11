# CLAUDE.md

## Project Overview

This directory holds a Lifeplan CLI project. Lifeplan CLI is a command-line tool for LLM-assisted life planning work.

It helps agents and humans manage structured planning data, run deterministic calculations, validate assumptions, compare scenarios, and export explainable results.

## Read These Documents

- `docs/prd.md` — Product scope, goals, non-goals, user stories, and release criteria.
- `docs/cli.md` — Public CLI interface and command behavior.
- `docs/datamodel.md` — Logical data structures, records, fields, and validation rules.

## Skills

Task-scoped guidance for Claude Code lives in `.claude/skills/`:

- `lifeplan-product` — product scope and MVP boundaries.
- `lifeplan-cli` — CLI command surface and output rules.
- `lifeplan-data` — record types, fields, and validation rules.

## Working Rules

- Do not add financial advice or product recommendation features unless explicitly requested.
- Keep implementation consistent with `docs/cli.md`.
- Keep data structures consistent with `docs/datamodel.md`.
- When changing CLI behavior, update `docs/cli.md`.
- When changing records, fields, or validation rules, update `docs/datamodel.md`.
- Prefer small, explicit changes.
- Run tests before reporting completion.
