# AGENTS.md

Guidance for AI agents and contributors working in this repository.

## What this is

**PAIR** (`usepair.ai`) is agent-native online writing for SOPs, prompts, and Claude
skills. It's a minimalist, browser-based markdown editor where the *same* document is
reachable two ways at the same identity:

- by humans, as a beautiful read-only share link (`GET /d/:token`), and
- by agents, as a raw markdown HTTP endpoint (`GET /d/:token.md`) and a bearer-authed JSON/markdown API (`/api/v1/*`).

Core principle: **storage *is* markdown.** The `documents.body` TEXT column holds exactly
what the user typed. No AST, no blocks, no JSON wrapping anywhere in the read/write
pipeline. The browser editor and the HTTP API are co-equal first-class clients of one
backend.

See `docs/mvp/spec.md` for the full spec, invariants, and decision log, and
`docs/product/vision.md` for product framing. The spec is the original MVP scope; the
codebase has since grown **collections** and **tasks** (with comments and linked
documents) on top of it — when spec and code disagree, the code is current.

## Stack

- **Ruby** 3.3.1, **Rails** 8.1.x
- **Postgres** (16 in CI) via `pg`. `text[]` tags with a GIN index.
- **Hotwire** (Turbo + Stimulus) for interactivity; **importmap** for JS (no bundler/npm).
- **CodeMirror 6** for the editor, vendored under `vendor/javascript/`, pinned in `config/importmap.rb`.
- **Tailwind** via `tailwindcss-rails` (output at `app/assets/builds/tailwind.css`).
- **commonmarker** for server-side markdown→HTML, wrapped by `PairMarkdown`.
- **solid_cache** / **solid_queue** for cache and jobs.
- Deploy: **Docker → Google Cloud Run** (see `docs/deployment/cloud-run.md`, `Dockerfile`). Kamal is not used.

## Setup & common commands

```sh
bundle install
bin/rails db:setup        # create + load schema + seed
bin/dev                   # run the server (alias for bin/rails server)
```

Quality gates — run these before considering a change done; they mirror CI:

```sh
bin/rails test test/models test/controllers test/integration
bin/rubocop                # auto-correct: bin/rubocop -a
bin/brakeman --no-pager    # static security scan
bin/importmap audit        # JS dependency vulnerabilities
```

Style is **rubocop-rails-omakase** (see `.rubocop.yml`) — follow it; don't hand-fight it.

## Architecture & conventions

- **Three client surfaces, one backend.** HTML controllers (session cookie auth) live at
  the top of `app/controllers`. The agent API lives under `app/controllers/api/v1/`
  (`ActionController::API`, bearer-token auth). Public unauthenticated share routes are
  `PublicDocumentsController`. Keep business logic in models/services so all three stay thin.

- **Authentication.**
  - Web: session cookies via the `Authentication` concern (`app/controllers/concerns/authentication.rb`) and the `Session`/`Current` models. Use `allow_unauthenticated_access` to opt a controller action out.
  - API: `Authorization: Bearer pair_…` tokens. `Api::V1::BaseController#authenticate_bearer_token` resolves `@current_user` from `ApiToken` (only `token_digest` is stored; the raw token is shown once).

- **Public tokens.** `Document` and `Collection` include `HasPublicToken`
  (`app/models/concerns/has_public_token.rb`): a 22-char unambiguous base58 token assigned
  at create, used as the route `:id` via `to_param`. Tokens are stable and never reused —
  toggling `is_public` does not change a URL. Never expose integer IDs or user identity in URLs.

- **Markdown rendering** goes through `PairMarkdown.render` only — never call Commonmarker
  directly. It is the single source of truth and runs in **safe mode** (no raw HTML
  pass-through, no `javascript:` URLs). This is a security invariant, not a preference.

- **Scoping.** Almost everything is owned by a user. Scope queries through
  `current_user` / the authenticated owner; the public and API surfaces must never leak
  another user's records. Public routes return **404, not 403**, when `is_public = false`
  (don't leak existence).

- **Data model** (`db/schema.rb`): `users`, `sessions`, `api_tokens`, `documents`,
  `collections` + `collection_documents` (ordered membership via `position`), `tasks` +
  `task_comments` (human/agent `author_kind`) + `task_documents` (links a produced doc to a task).

## Invariants (do not break)

- `document.body` round-trips byte-identically: `GET …/content` → `PUT …/content` must not normalize, trim, or re-serialize.
- `public_token` is unique and never reused, even after deletion.
- API tokens are never persisted in plaintext — only `Digest::SHA256` digests.
- Public routes 404 (never 403) when not public.
- Markdown rendering is always safe-mode `PairMarkdown`.

## Testing

Minitest with fixtures (`test/fixtures/`). Tests live in `test/models`, `test/controllers`,
and `test/integration` (the API round-trip and content-negotiation tests). Add tests with
any behavior change; cover ownership/auth boundaries and the markdown round-trip invariant
for document changes.

## Working agreements

- Make the smallest complete change; match the surrounding code's style and comment density.
- Don't add npm/yarn or a JS bundler — this app is importmap + vendored JS on purpose.
- Branch for changes; commit/push only when asked. Don't touch `config/credentials.yml.enc` or `config/master.key`.
- Ignore the `.claude/worktrees/` directory — those are throwaway agent worktrees, not source.
