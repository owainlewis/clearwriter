# PAIR — Product Vision

## Positioning

**Agent-native online writing for SOPs, prompts, and skills.**

A minimalist markdown editor in the browser where humans get a beautiful share link and agents get a raw `.md` HTTP endpoint at the same URL. Markdown is the storage format and the wire format — no transformation anywhere in the pipeline.

Closest mental model: **GitHub Gist for the agent era, with a writing UX that doesn't make you cry.**

## Problem

People building with AI agents — Claude Code, Cursor, custom agents — write SOPs, system prompts, skill definitions, and runbooks constantly. These artifacts are all markdown. They get scattered across:

- **Obsidian** — great editor, local-only, no share story, no agent HTTP access
- **GitHub Gists** — great URL primitive, hostile editor, GitHub-only auth, no native agent affordances
- **Notion** — heavy, login-walled, agents can't read pages
- **Pastebins / Slack** — ephemeral, no edit, no auth

None of these treat "an agent fetches this document over HTTP" as a first-class operation. The user has to either keep markdown files scattered across their laptop or build their own publishing pipeline.

## Solution

One app where:

1. You write markdown in a beautiful, iA Writer–style browser editor.
2. You toggle "Share" and get a short URL (`usepair.ai/d/:token`).
3. Humans visiting the URL see rendered HTML; agents `curl` the same URL with `.md` appended and get raw markdown.
4. Authenticated agents can also read, create, update, and delete documents over an HTTP API with bearer tokens — the same backend, second client.

The browser editor and the HTTP API are co-equal first-class clients of the same data.

## Target audience

**Primary**: solo developers, indie hackers, and small-team builders who already use Claude Code, Cursor, or other AI agents day-to-day, and who want a persistent writing surface those tools can touch.

**Secondary**: anyone who currently uses Gist for sharing technical docs or SOPs and finds it ugly/clunky.

**Not target**: Notion users, Obsidian power users with deep vaults, knowledge-management enthusiasts who want graph view / backlinks / wikilinks.

## Competitive frame

| Tool | Editor | Share | Agent API | Price |
|---|---|---|---|---|
| **PAIR** | iA-Writer-style | One-click, opaque token | First-class HTTP + bearer tokens | $8/mo |
| Obsidian | Excellent | Obsidian Publish ($10/mo) | None | Free + $10 Publish |
| Obsidian Sync | Excellent | None | None | $4/mo |
| GitHub Gist | textarea, 2008 | Free | Raw URL only, no write API in spirit | Free |
| Notion | WYSIWYG | Login-walled | None native | $10+/mo |
| HackMD | Markdown WYSIWYG | Free | Limited | Free + $5/mo |
| iA Writer | Best-in-class | None (local app) | None | $50 one-time/device |

PAIR's only direct overlap is Obsidian Publish + Obsidian Sync combined ($14/mo). PAIR is $8/mo and adds the agent API neither of them has.

## Pricing

### Free

- **10 documents**
- **3 active public share links**
- Read-only API for **public** docs (the raw `.md` URL is already public — this is free as a side effect)
- No bearer-token write API
- "Made with PAIR" footer on share pages
- Email + password auth

### Pro — $8/mo, $80/yr (saves $16)

- **Unlimited documents** (soft-capped at 10,000; lifted by request — see "Abuse policy" below)
- Unlimited active public share links
- Full read/write API with bearer tokens
- No footer on share pages
- Custom subdomain for shares (when shipped — v1.1+)
- Priority email support (i.e., the founder replies)

### Team — not in v1

Defer until at least one customer explicitly asks. When built, likely $15/user/mo with shared documents and per-team API tokens.

## Pricing rationale

**Cost floor**: ~$32/mo of GCP overhead (Cloud SQL `db-g1-small` + Cloud Run min-instance + small extras).

**Per-user variable cost**: effectively zero. Markdown is tiny — even 10,000 docs at 20KB is 200MB of storage costing $0.03/month.

**Break-even**: 4 paid users at $8/mo. Achievable.

**Anchoring**: under Obsidian Publish ($10) and Notion Personal ($10), at the same point as HackMD Premium ($5) but with a real API and a better editor.

**Why $8 not $6**: the audience (developers using agents) is high-willingness-to-pay. Underpricing signals "hobby project" — $8 reads as serious-but-fair. Round number, easy to remember, no friction.

**Why not freemium with metered API calls**: complexity for no upside at MVP scale. Rate limits + soft caps cover abuse without inventing a billing dimension users have to think about.

## Abuse policy ("unlimited" with soft caps)

"Unlimited" in marketing means "no hard cap on the happy path." It does not mean "literally infinite, please DDOS me."

**Soft caps** (silent; never shown in UI):

- **10,000 documents per Pro user** — hidden ceiling. If anyone hits it, they get an email asking what they're doing and the cap is lifted (or we have a conversation about a Team plan).
- **5MB per document** — markdown is tiny; anything bigger is being misused as a file host.
- **100 documents created per user per day** — rate limit on creation, prevents drive-by spam.
- **60 API requests per token per minute** — standard rate-limit ceiling, well above legitimate use.
- **1000 public share link views per minute per token** — CDN-fronted, so this rarely matters; if it does, it's viral, which is fine.

**Hard floors** (visible in ToS):

- No hosting binaries, no image hosting, no using documents as a file store.
- No automated bulk import of third-party content (RSS scrapes, etc.).
- Standard "we may rate-limit or contact you" language.

Abuse mitigation is a code concern (rate limiter + caps in the model layer), not a billing concern. See tech spec for implementation.

## What success looks like

**Year 1 floor (sustaining)**: 10 paid users = $80/mo. Covers GCP + domain + Resend. Project doesn't lose money.

**Year 1 target (encouraging)**: 50 paid users = $400/mo. Pays for design tools, domain renewals, and small ad spend. Signal that the wedge is real.

**Year 1 ceiling (genuinely working)**: 200 paid users = $1,600/mo MRR. Replaces a side-project consulting day per month. Justifies full product investment.

**Failure mode**: <5 paid users after 6 months of being public. Indicates the agent-builder niche doesn't currently care enough about a hosted markdown surface. At that point: either pivot the audience (broaden to writers, drop the API angle) or shut it down and let GCP billing stop.

## What we are deliberately not doing

See the tech spec's Out of Scope section for the engineering version. Commercially:

- **No free trial of Pro.** Free tier is good enough to evaluate; Pro is "I've decided this is useful."
- **No annual lock-in discount above ~17%.** $80/yr vs $96/yr is fair; cutting deeper attracts cheapskates who churn.
- **No enterprise sales motion.** This is a self-serve PLG product. If a company wants 50 seats, we'll talk; we won't pursue.
- **No content marketing flywheel as the primary growth bet.** Growth bet is: the share-link URL itself is the marketing. Every shared doc is an ad.
- **No multi-language UI in v1.** English only.

## Risks

1. **Crowded category**: lots of markdown editors exist. Mitigation: the wedge is the agent API, not the editor. Lead with that.
2. **GCP fixed costs while idle**: $32/mo whether anyone uses it or not. Mitigation: GCP billing alert at $50/mo. If usage doesn't justify, tear down.
3. **Solo-dev capacity**: easy to burn out maintaining. Mitigation: tight scope (the Out of Scope section in tech spec is the contract with future-self).
4. **Audience may not pay for hosted markdown** when self-hosting alternatives exist. Mitigation: free tier wide enough to convert habituated users; the agent API is the paid hook.

## Roadmap (post-MVP)

Ordered roughly by likely build sequence. Each item is a hypothesis, not a commitment — re-evaluate against real usage before building.

### v1.1 — Sharpening the MVP

- **Magic-link auth** as a second sign-in option alongside password.
- **Frontmatter parsing** — Claude skills and SOPs commonly carry YAML frontmatter; expose as structured metadata in the API.
- **Full-text search** — Postgres `tsvector` + GIN. Add when tag + recent filter stop being enough.
- **Expiring share links** (`public_until` timestamp) — solves "I gave an agent access for one task."
- **Per-doc API tokens** — give an agent access to one doc, not the whole vault.

### v1.2 — Templates

A **Template** is a markdown document that other users (or the same user) can clone as a starting point for a new document. Examples:

- "YouTube video launch checklist" — a checklist of pre-record, record, edit, publish steps.
- "SOP template" — sections for purpose, scope, procedure, owner, last reviewed.
- "Newsletter outline" — hook, body, three takeaways, CTA.
- "Bug triage script" — questions an on-call engineer should walk through.

Mechanics:

- Any document can be marked as a template (flag on Document, or a separate Template model — decide before building).
- "Use this template" → new Document seeded with the template's body and tags.
- Templates have their own public URL so they're shareable like any other doc.
- A user's own template library (`/templates`) lists everything they've created or starred.

Why this is on the agent-native roadmap, not just a generic-SaaS feature:

- A template is just markdown — fits the storage model exactly, no new primitive.
- **Agents can work through a template *with* the user**: agent fetches the template, walks the user through each section or checkbox, fills in answers, and saves the result as a new document. This is exactly the kind of structured-but-flexible workflow the agent-native positioning is built for.
- Public templates become marketing: every "Use this template" link is a share + a signup funnel.
- Optional later: community gallery of public templates (curated, voted on, etc.).

Open design questions:

- Template-as-flag vs template-as-its-own-type. Leaning flag (\`is_template: true\`) — same storage, same API, lower complexity.
- Does cloning copy tags? Author? Frontmatter? Default: copy body + tags, drop frontmatter author fields.
- How does an agent know "this is a template, walk me through it"? Probably a frontmatter convention (\`type: template\`) + an MCP/API hint.

### v1.3 — Collections (content bundles)

A **Collection** is an ordered, named set of documents — many-to-many with `Document`. Two use cases drive this:

1. **Saved category** — "all my Claude skills," "all my onboarding SOPs." Functionally a tag-with-order, but with a shareable URL.
2. **Content bundle** — one unit of work that ships as multiple artifacts. Example: a YouTube video → 1 description + 1 LinkedIn post + 1 newsletter draft + 5 tweets. All live as separate documents (so each can be edited, shared, agent-edited individually), but ship together as one collection.

Why this is on the roadmap, not in MVP:
- It's a new primitive with its own share scope, ordering, and API surface decisions.
- The agent angle is strong — "give me everything in this collection" → one URL, one fetch.
- Likely valuable to content creators and to anyone running repeated multi-artifact workflows.

Open design questions to resolve before building:
- Many-to-many (album model) vs single-parent (folder model). Leaning many-to-many — preserves the flat-list philosophy and avoids hierarchy creep.
- Collection sharing scope: share the collection (one URL → TOC), or auto-share each doc? Probably: collection sharing implies the docs inside become public via collection-scoped tokens.
- API shape: `GET /api/v1/collections/:id` returns ordered list of doc metadata; `GET /api/v1/collections/:id/bundle.md` returns concatenated markdown with separators (for agents who want one blob).

### v1.4+ — Distribution

- **Public user index** at `/u/:username` — a person's published docs and collections in one place.
- **Custom subdomain** for share links (`yourname.usepair.ai/d/...`).
- **MCP server** wrapping the HTTP API so Claude Code / Cursor can mount docs as a filesystem.
- **Webhooks** (`document.updated`) for agent loops.

### Unsorted / parking lot

- Image uploads or attachments. Probably out forever — markdown can link external URLs.
- Per-edit version history.
- Auto-deleting docs (destructive TTL).
- Team plans + shared collections.
- Mobile app / PWA.
- Native desktop client.

## Competitors to track

### Spiral — https://writewithspiral.com

- **Category**: AI writing partner (LLM-driven drafting via interview-style prompts).
- **Pricing**: $25/mo Personal (50 sessions), $35/seat Teams (min 3 seats, 100 sessions/seat), $30/mo via the "Every Bundle" suite.
- **Has**: brand-voice writing styles, multi-angle drafts, file uploads for context.
- **Lacks**: markdown editor, share links, HTTP API. Sessions-based, not document-based.
- **Read on overlap**: **complementary, not directly competitive.** Spiral generates drafts; PAIR hosts and shares the resulting docs and exposes them to agents. A user could plausibly use both — draft in Spiral, store and share in PAIR.
- **Pricing signal**: their $25 personal tier proves the writing-tool audience pays serious money. PAIR's lower price reflects different unit economics (no LLM cost), not weaker value — but it does suggest $8 is a floor, not a ceiling, if positioning shifts.

### To add as encountered

- Track HackMD, Obsidian Publish/Sync, and any new "agent-readable docs" entrants here.

## Related documents

- [Technical MVP spec](../mvp/spec.md) — what we build first
