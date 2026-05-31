# Agent Coding Playbook

How a single, well-defined ticket goes from "ready" to "merged" when an AI agent
does the work and a human stays on the high-leverage gates. **Product planning and
ticket creation are a separate, upstream step** — this playbook starts once a ticket
is *ready*.

## Principles

1. **Separate planning from execution.** Tickets are written and scoped before an
   agent picks them up. The execution agent argues against a fixed spec; it does not
   invent scope.
2. **Spend human attention at the two hardest-to-reverse points:** approving the plan
   and merging. Automate everything in between.
3. **Review in a clean context.** The agent that wrote the code is biased about it. A
   fresh-context reviewer catches what the author is blind to.
4. **Match each step's mechanism to how costly it is to skip.** Judgment → prompt/skill
   (soft). Orchestration → workflow (deterministic). Non-negotiable gates → hooks
   (harness-enforced, un-skippable). See Appendix B.
5. **Close the loop.** Recurring review findings become rules, so the same class of bug
   is *prevented* next time, not re-caught.

---

## Phase 0 — Ticket readiness (upstream; gate)

A ticket may not be picked up until it has:

- A clear problem statement and **acceptance criteria**.
- **Scope boundaries** (an explicit "out of scope").
- **Relevant files / entry points.**
- **Which invariants apply** (the project's must-not-break rules).

> If a ticket can't clear this bar, it goes back to planning. Garbage ticket → garbage
> output, regardless of how good the execution loop is.

## Phase 1 — Pick up & plan  ·  *human gate*

- Pull the ticket; read it and the code it touches.
- Produce a short **implementation plan**: approach, files to change, risks, test plan.
- Surface **clarifying questions now**, before any code.
- **Human approves the plan.** Do not branch or write code before approval.

## Phase 2 — Branch

- Cut a traceable branch off the latest default branch (e.g. `feature/<slug>`).

## Phase 3 — Implement

- Make the **smallest complete change** that satisfies the acceptance criteria.
- Match the surrounding code's style and conventions.
- Write clean code as you go — don't defer all quality to a later refactor.

## Phase 4 — Self-verify

- Add/adjust tests for the behavior changed, including ownership/auth boundaries and
  any applicable invariants.
- Run the **full project gate** (tests + lint + security scan). Must be green before
  review.

## Phase 5 — Clean-context review  ·  *fresh subagent*

- Hand the diff to a reviewer with **no prior context**.
- Review is **adversarial and multi-lens**:
  - **Correctness** — does it do what the ticket says; edge cases.
  - **Security & ownership** — auth boundaries, scoping, the project's invariants
    (check the diff against the invariant list explicitly).
  - **Tests** — do the tests actually exercise the behavior, or just pass?
- Output: a list of findings, each with a verdict (real / not).

## Phase 6 — Refactor  ·  *conditional, after review*

- **Only if** review flagged shape issues or the diff is genuinely messy.
- Behavior-preserving simplification, scoped to the change.
- Skip it for small, clean diffs — a forced refactor is churn and risk.

## Phase 7 — Re-verify

- Re-run the full gate after addressing review + any refactor.
- For UI/behavior changes, **run the app and observe** — green tests ≠ feature works.

## Phase 8 — Open PR & report

- Open the PR **ready for review**, linked to the ticket (`Closes #N`).
- Report: what changed, why, design decisions and trade-offs, what the reviewer should
  look at, and how it was verified.

## Phase 9 — CI review loop

- CI runs an automated review (e.g. CodeRabbit / a cloud review).
- **Triage** each comment: implement valid fixes, push back on noise, reply where useful.
- Re-run gates after changes.

## Phase 10 — Merge  ·  *human gate*

- **Human merges.** This is the irreversible step; keep a person on it.
- Rebase onto the latest default branch first if it has moved; resolve conflicts;
  re-run gates before merging.

## Phase 11 — Capture learnings

- If review found a recurring issue, record it as a rule/checklist item so it's
  prevented on the next ticket.

---

## Appendix A — Claude Code mapping

| Phase | Mechanism |
|---|---|
| 0 Ticket readiness | Done in planning; `spec` / `plan` skills can draft tickets |
| 1 Plan + gate | **Plan mode** (present plan, human approves); `AskUserQuestion` for clarifications |
| 2 Branch | `branch` skill |
| 3 Implement | `implement` skill (or `tdd` for test-first) |
| 4 Self-verify | `coverage` skill; project gate commands |
| 5 Clean-context review | `review` / `code-review` skills, or a fresh subagent (`Agent`) — ideally a fan-out Workflow, one reviewer per lens |
| 6 Refactor | `simplify` (quality-only) or `refactor` skill |
| 7 Re-verify | gate commands; `verify` / `browser-verify` skills |
| 8 PR & report | `gh pr create` |
| 9 CI review loop | `address-pr-feedback` / `coderabbit:autofix` |
| 10 Merge | manual (`gh pr merge`) |
| 11 Capture learnings | memory |

## Appendix B — Running it consistently (layering)

No single mechanism makes this reliable. A hand-written prompt gets ~80% and drifts as
context fills. Layer by how costly it is to skip a step:

- **Soft — skill / slash command.** Encode this playbook as `/ticket <issue#>`. Same
  text every time, versioned. Right for the judgment steps (plan, implement, address
  feedback). The agent still interprets, so it can still drift.
- **Medium — dynamic Workflow.** A script whose control flow is code, not model
  judgment. Right for the **orchestration spine and the verification tail**: fan out the
  clean-context review by lens, gate the refactor on the review verdict
  (`if review.hasShapeIssues`), re-verify, emit a PR-ready summary. *Not* for the
  `implement` step — that wants interactive steering in the main session, not a
  background subagent.
- **Hard — hooks (`settings.json`).** Executed by the harness, not the model, so they
  **cannot be skipped**. Right for non-negotiable gates: run tests + lint + security
  scan, and block PR creation on failure.
- **Persistent — memory.** Standing preferences applied automatically every session.

**Recommended split:** plan + implement *interactively* (soft layer, with the plan
gate) → hand the "I think it's done" tail to a Workflow (medium) → hooks (hard) enforce
that gates pass before a PR can open → memory holds the standing rules.

> Portability note for other agents: the transferable design is the layering itself —
> soft prompt for judgment, deterministic script for orchestration, harness-enforced
> gate for the non-negotiables. The tools differ per platform; the hardness model does
> not.
