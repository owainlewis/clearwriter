# CLAUDE.md

This file guides Claude Code when working in this repository.

**Read [AGENTS.md](AGENTS.md) first** — it is the canonical guide for working here
(architecture, stack, commands, conventions, and the invariants you must not break). The
notes below are Claude-specific additions; everything in AGENTS.md applies.

## Quick reference

- Run the app: `bin/dev`
- Before finishing a change, run the same gates CI does:
  `bin/rails test test/models test/controllers test/integration`, `bin/rubocop`, `bin/brakeman --no-pager`.
- Style: rubocop-rails-omakase. Use `bin/rubocop -a` to auto-correct.

## Claude-specific notes

- A `rails` skill is available for Rails 8 / Hotwire / ActiveRecord work — prefer it for scaffolding and Rails idioms.
- This is Hotwire + importmap + vendored JS. Do **not** introduce npm, a JS bundler, or a client-side markdown parser.
- Keep the three client surfaces (HTML, public share, `/api/v1`) thin; put logic in models/services.
- Honor the invariants in AGENTS.md, especially: byte-identical markdown round-trip, safe-mode rendering via `PairMarkdown`, and 404 (not 403) on private public-routes.
