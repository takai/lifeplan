# lifeplan

Lifeplan CLI helps humans and LLM agents manage life planning data.

## Directory Structure

Ruby 4.0, conventional gem-style layout.

- `bin/` - CLI entrypoints.
- `lib/` - Application/library code.
- `lib/lifeplan.rb` - `require "lifeplan"` entrypoint.
- `lib/lifeplan/` - Modules, commands, and domain logic.
- `spec/` - RSpec tests.

## Documentation

- `docs/prd.md` - PRD.
- `docs/cli.md` - CLI spec.
- `docs/datamodel.md` - Data model spec.

## Commands

- `mise run test` - Run tests.
- `mise run fix` - Run lint/fix.

## Development Guidelines

- Use red/green/refactor TDD.
- Use `git ai-commit --context "<short English summary>"`  to create commits.

## Pull Request Workflow

1. Always work on a feature branch.
2. Update documentation alongside code changes.
3. Close the original issue from the PR.
