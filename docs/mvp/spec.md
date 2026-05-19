# Clearwriter MVP

## What

**Clearwriter** (`clearwriter.app`) is agent-native online writing for SOPs, prompts, and skills. It's a minimalist browser-based markdown editor where the same document is reachable by humans as a beautiful share link and by agents as a raw `.md` HTTP endpoint. Storage *is* markdown — no AST, no blocks, no JSON wrapping anywhere in the pipeline. Browser editor and HTTP API are co-equal first-class clients of the same backend.

## Context

The author writes SOPs, prompts, and Claude skills constantly and currently shuffles them between Obsidian (great editor, no share story, no agent API), GitHub Gists (great URL primitive, terrible editor, GitHub-only auth), and ad-hoc pastebins. None of these treat "an agent fetches this document over HTTP" as a first-class operation. iA Writer has the typographic feel but is a per-device native app with no web surface.

The wedge is **gist's URL primitive + iA Writer's editor + a real API for agents**. The category is not "another Notion" or "another Obsidian" — it's "GitHub Gist for the agent era, with a writing UX that doesn't make you cry."

Greenfield project. Empty repo at `/Users/owainlewis/Code/mdwriter` (directory name predates the rename; keep or rename to `clearwriter` at scaffold time — author's call).

## Requirements

1. A signed-in user can create, edit, list, rename, and delete markdown documents.
2. The editor displays raw markdown characters (iA Writer style), not WYSIWYG. Syntax is dimmed/styled but markup stays visible.
3. The editor autosaves on a debounce — no save button.
4. A keyboard shortcut (⌘R, with ⌘⇧P as alias) toggles between edit and rendered preview of the current doc.
5. Each document has a stable opaque public token. When sharing is enabled on a doc, `GET /d/:token` renders a read-only HTML preview accessible without auth.
6. Each document is also reachable as raw markdown at `GET /d/:token.md` (returns `text/markdown; charset=utf-8`) when public. **The raw `.md` URL is the agent read endpoint for 80% of cases — no bearer token required for public docs.**
7. Authenticated agents can list, read, create, update, and delete the signed-in user's documents over HTTP using a bearer token, with markdown as the request and response body for read/write of document content. **The API is a co-equal first-class client of the backend, not a v2 feature.**
8. Auth supports both email + password and magic links. Either method produces the same `Session`.
9. The app runs as a single Rails process against Postgres, deployable to one small VPS.
10. The editor surface — font, line-height, max-width, focus styling — must feel deliberately typographic. Default to iA Writer Mono / Duo / Quattro stack with system mono fallback.
11. Document list is flat — no folders, no hierarchy. Organization happens through **tags** (multi-categorization, no parent/child) and **time-based filters** (default view, recent N days).
12. The dashboard surfaces a "Recent" view (docs created or updated in the last 7 days) as the default landing for signed-in users — better than dumping the full list on every visit.
13. The signed-out root URL (`/`) renders a public landing page describing the product. Authenticated users hitting `/` are redirected to their dashboard.

## Design

### Stack

- **Rails 8.x** (latest stable) generated with `--minimal --database=postgresql --css=tailwind`, then `actionmailer` and `hotwire-rails` added back.
- **Cloud SQL Postgres** (managed, GCP). Smallest viable tier in MVP (`db-g1-small`, ~$25–30/mo); upgrade when load demands. Solid Cache on the same Postgres. **No Solid Queue / Solid Cable in MVP** — Cloud Run is stateless/scale-to-zero, which fights an always-on worker.
- **Importmaps** for JS. **CodeMirror 6** loaded via importmap CDN pins for the editor with the `@codemirror/lang-markdown` package; plain `<textarea>` fallback if JS fails.
- **Turbo + Stimulus** for autosave debounce, edit↔preview toggle, and keyboard shortcuts. One Stimulus controller (`editor_controller.js`).
- **commonmarker** gem for server-side markdown → HTML (GitHub-flavored, safe mode).
- **Cloud Run** for the Rails app (containerized, scale-to-zero; optional `min-instances=1` to avoid cold starts).
- **Artifact Registry + Cloud Build** for image builds. Deploy via `gcloud run deploy --source .` (buildpacks) for MVP; switch to a hand-rolled Dockerfile if buildpacks become limiting.
- **Secret Manager** for `RAILS_MASTER_KEY`, DB password, Resend API key.
- **Cloud SQL Auth Proxy** (Cloud Run native integration) for DB connections.
- **Resend** API (HTTP, not SMTP) for transactional magic-link mail, sent **synchronously** in the request — no background queue needed for MVP volume.
- **Domain mapping**: Cloud Run domain mapping for `clearwriter.app` (or Google-managed external HTTPS LB if mapping limits bite).

### Data model

```
users
  id, email (unique, citext-like via lower-cased), password_digest (nullable), created_at, updated_at

sessions
  id, user_id, token (signed cookie value), user_agent, ip_address, created_at, updated_at
  (from `rails g authentication`)

documents
  id, user_id, title (string, derived from first H1 or filename), body (text, the markdown),
  tags (text[], default '{}', GIN-indexed),
  public_token (string, unique, 22-char base58, indexed), is_public (boolean, default false),
  created_at, updated_at

  Indexes: (user_id, updated_at DESC), (user_id, created_at DESC), GIN on tags.

api_tokens
  id, user_id, token_digest (unique, indexed), name (string), last_used_at, created_at
  (raw token shown once at creation; only digest stored)
```

`public_token` is generated at document creation regardless of sharing state, so toggling public on/off does not change the URL once shared.

### Routes

Marketing (HTML, no auth):

```
GET    /                        → landing page if signed out; redirect to /documents if signed in
```

Auth (HTML, no auth required to hit):

```
GET    /sign_in                 → password form + "email me a link" form
POST   /sign_in                 → password login
GET    /sign_up                 → email + optional password
POST   /sign_up
POST   /magic_links             → request magic link
GET    /magic_links/:token      → consume token, create session
DELETE /sign_out
```

App (HTML, session-authed):

```
GET    /documents               → list (?tag=…&since=7d), most recently edited first; default view = recent 7 days
POST   /documents               → create blank doc, redirect to edit
GET    /documents/:id/edit      → editor
PATCH  /documents/:id           → autosave (Turbo, returns 204); also updates tags
GET    /documents/:id/preview   → server-rendered HTML preview (Turbo Frame swap target)
DELETE /documents/:id
POST   /documents/:id/share     → set is_public=true
DELETE /documents/:id/share     → set is_public=false

GET    /tags                    → list of distinct tags for current_user with counts
GET    /settings/api_tokens     → list + create
POST   /settings/api_tokens
DELETE /settings/api_tokens/:id
```

Public (no auth):

```
GET    /d/:token                → read-only rendered HTML, 404 if !is_public
GET    /d/:token.md             → raw markdown, text/markdown
```

API (bearer-authed, JSON for metadata, raw markdown for content):

```
GET    /api/v1/documents                → JSON list (?tag=…&since=7d) of {id, title, tags, public_token, is_public, updated_at}
POST   /api/v1/documents                → JSON in (title, body) or raw markdown body, returns JSON
GET    /api/v1/documents/:id            → JSON metadata
GET    /api/v1/documents/:id/content    → raw markdown, text/markdown
PUT    /api/v1/documents/:id/content    → accepts raw markdown body, overwrites, 204
DELETE /api/v1/documents/:id
```

`PUT /api/v1/documents/:id/content` with `Content-Type: text/markdown` and `--data-binary @file.md` is the primary agent write path. No JSON wrapping, no base64.

### Editor flow

1. `GET /documents/:id/edit` renders a Turbo Frame containing the CodeMirror-enhanced textarea.
2. Stimulus `editor_controller` debounces `input` events (800ms) and `PATCH`es `body` as `application/x-www-form-urlencoded`. Server returns `204 No Content`.
3. ⌘R / ⌘⇧P: Stimulus fetches `/documents/:id/preview` and swaps the editor frame for the preview frame. Same shortcut toggles back.
4. Preview is server-rendered (commonmarker, safe mode, syntax highlighting via Rouge). No client-side markdown parser.

### Auth

- `rails g authentication` provides the password flow.
- Magic links: `MagicLinksController#create` looks up the user by email (creates one if signup-via-link is allowed — **Decision below**), generates `User.signed_id(purpose: :magic_link, expires_in: 15.minutes)`, mails the URL. `#show` calls `User.find_signed(token, purpose: :magic_link)` and creates a session.
- API: bearer token in `Authorization: Bearer <token>`. Stored as `token_digest = Digest::SHA256.hexdigest(token)`. Token is `"cw_" + SecureRandom.urlsafe_base64(24)`, shown once.

## Decisions

1. **Storage format = raw markdown string in a TEXT column.** Alternative: parsed AST or per-block rows. Chosen because storage *is* the wire format the user, the preview renderer, and the agent API all consume — no transformation needed anywhere. Reversible (can derive AST later).

2. **Server-rendered preview, no client markdown parser.** Alternative: ship markdown-it or similar to the client. Chosen to keep the JS bundle tiny and the renderer single-sourced (so share-link HTML and in-app preview cannot diverge). Reversible.

3. **Cloud Run + Cloud SQL Postgres on GCP.** Alternative: Kamal on a Hetzner VPS (cheaper, more ops), or Fly.io (similar tradeoff to Cloud Run). Chosen because author already runs GCP stack — minimizes new-platform overhead. Cost is ~$15–40/mo vs $6/mo for a VPS; accepted as the cost of "I never SSH into a box." Reversible (containerized Rails ports easily).

   `Assumption:` Magic-link emails sent synchronously via Resend API in MVP — no background worker needed. If volume or other async jobs appear, add **Cloud Tasks** (queue-as-a-service) over standing up an always-on Solid Queue worker.

4. **Magic links coexist with password auth, both produce the same `Session`.** Alternative: magic-link-only. Chosen because password is already free from the generator and some users will prefer it; the cost is one extra controller. Reversible.

5. **Public share via opaque per-document token, generated at create time, stable across toggling `is_public`.** Alternative: regenerate on each share, or use the integer ID. Chosen so links don't break if a user un-shares then re-shares; opaque so IDs aren't enumerable. Reversible (can rotate tokens).

6. **API uses raw `text/markdown` bodies for document content, JSON only for metadata.** Alternative: JSON-wrap everything. Chosen because agents and `curl` can pipe files directly with no encoding; aligns with the principle that markdown is the storage format. Reversible (can add JSON content endpoints alongside).

7. **CodeMirror 6 over a plain textarea.** Alternative: pure `<textarea>`. Chosen for subtle syntax highlighting and future typewriter-scroll / focus-mode features that define the iA Writer feel. The textarea is the no-JS fallback. Reversible.

8. **Magic-link requests for unknown emails: silently succeed without creating a user or sending mail.** Alternative: auto-create user, or return "no such account." Chosen to avoid email enumeration and to keep signup an explicit action. Reversible.

   `Assumption:` MVP signup is via a `/sign_up` form (email + optional password). Magic-link-only signup can be added later.

9. **Tags as a Postgres `text[]` column with a GIN index, not a separate `tags` table.** Alternative: normalized `tags` + `taggings` join table. Chosen because tags have no metadata of their own (no color, no description), array containment queries (`tags @> ARRAY['onboarding']`) are fast under GIN, and the API surface stays one resource instead of three. Reversible — promote to a table if tags ever need attributes.

10. **No full-text search in MVP.** Alternative: ship Postgres `tsvector` + GIN from day one. Cut because tags + "recent" filter + browse-by-list is enough for hundreds of docs, and search adds an indexed generated column, a search UI, and result-ranking decisions that are easier to make once we see real usage patterns. Reversible — add as a generated column later without a data migration.

11. **One Rails app, one domain (`clearwriter.app`), path-based split between marketing and app.** Alternative: `app.clearwriter.app` subdomain. Chosen because the most important URL in the product is the public share URL (`clearwriter.app/d/:token`) — shorter and cleaner without an `app.` prefix. Subdomain split adds ops surface (TLS, cross-subdomain cookies, two deploys) for benefits a solo dev doesn't yet need. Reversible.

12. **User identity is not in any URL.** Owner edit URLs (`/documents/:id`) are session-scoped; public share URLs (`/d/:token`) use opaque tokens with no username; API URLs are bearer-scoped. `/u/:username` is reserved for the future public profile page. Chosen for shorter URLs, no rename traps, and IDOR safety. Reversible.

## Versions

- **Ruby**: 3.3.x (current stable as of spec; verify latest patch at `rails new` time).
- **Rails**: 8.x latest stable.
- **Postgres**: Cloud SQL Postgres 16 (current default); 17 if Cloud SQL supports it at scaffold time.
- **CodeMirror**: 6.x via importmap pins to `https://esm.sh/@codemirror/...`.
- **commonmarker**: 2.x (libcmark-gfm backed).
- **gcloud CLI**: latest stable; `gcloud run`, `gcloud sql`, `gcloud secrets` commands used.

`Assumption:` Today is 2026-05-19; verify each version is still current at scaffolding time and pin in `Gemfile` / `.ruby-version` / `importmap.rb`.

## Invariants

- A document's `body` is exactly what the user typed — no normalization, no trimming, no re-serializing through an AST. Round-trip `GET .md` → `PUT .md` must be byte-identical.
- `public_token` is unique and never reused, even after document deletion.
- API tokens are never stored in plaintext after creation; only `token_digest`.
- Public routes (`/d/:token`, `/d/:token.md`) MUST return 404 (not 403) when `is_public = false`, to avoid leaking existence.
- Preview renderer runs commonmarker in safe mode — no raw HTML passthrough, no `javascript:` URLs.

## Error Behavior

- Autosave PATCH failure: Stimulus controller surfaces a small "unsaved" indicator and retries with exponential backoff up to 1 minute, then surfaces a persistent error.
- Magic link expired or already used: render a generic "this link is no longer valid, request a new one" page. Do not differentiate.
- API errors: JSON `{ "error": "<machine_code>", "message": "<human>" }` with appropriate 4xx/5xx. Content endpoints on 4xx return `text/plain` body with the message, not JSON, so `curl`'s output is readable.
- Markdown that fails to render (extremely unlikely with commonmarker): preview shows the raw markdown in a `<pre>` with a small banner. Never 500 the page.

## Testing Strategy

- Minitest (Rails default) added back after `--skip-test` if needed. System tests with Capybara for: sign-in (both methods), create → edit → autosave → preview toggle, share toggle and public URL access, API token create + bearer request round-trip.
- Model tests for `Document#public_token` uniqueness, `ApiToken` digest behavior, magic-link signed-id expiry.
- Request specs for the API covering auth failure, 404 on other users' docs, and the byte-identical round-trip invariant.
- No JS unit tests for the Stimulus controller — covered by system tests.

## Out of Scope

**Permanently out** (fights the gist-like positioning):
- Folders, wikilinks, backlinks, graph view. Flat list + tags is correct.
- Realtime collaborative editing.
- Comments on shared docs.
- WYSIWYG editing.
- Obsidian vault import.

**Out for MVP, likely v1.1+** (fits the agent-native angle, just not day one):
- **Full-text search** across a user's docs (Postgres `tsvector` + GIN). Tags + recent filter cover MVP; add search when usage demands it.
- **Frontmatter parsing.** Claude skills and many SOPs have YAML frontmatter; parse it and expose as structured metadata in the API alongside the body.
- **Expiring share links** (`public_until` timestamp). Solves the "I shared this with an agent for one task" use case cleanly.
- **Immutable version URLs** (`/d/:token@v3` + `latest` alias). Matters once agents start pulling docs into context — you want pinning.
- **Per-doc API tokens** (not just per-user). Lets users give one agent access to one doc.
- **Webhooks** (`document.updated`) for agent loops.
- **MCP server** wrapping the HTTP API so Claude Code / Cursor can mount docs as a filesystem.
- **Public user index** (`/u/:username`) of someone's shared SOPs. Discovery/distribution mechanism.
- **Custom subdomains** for share links (`yourname.clearwriter.app/d/...`).

**Out for MVP, undecided** (revisit when product has users):
- Offline / PWA.
- Native mobile.
- Image uploads (markdown can reference external URLs in the meantime).
- Per-edit version history.
- Auto-deleting docs (destructive TTL). Distinct from expiring share links above.
- Billing, plans, teams. Single-tier and free until something demands it.
