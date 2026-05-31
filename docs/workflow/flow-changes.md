# Flow extension — change list to make it production-grade

Concrete changes to `pi-dynamic-workflows/index.ts`, grounded in the current source.
Ordered by impact. Each says *what*, *why*, and *where in the code*.

Today Flow is a **linear** runner: `runFlow` walks `flow.steps` in a `for` loop and
fail-stops. `parseFlowYaml` is a hand-rolled line parser with a fixed field allowlist.
Adding a feature = (1) extend the `FlowStep` interface, (2) add the field to the parser's
allowlist + validation in `finish()`, (3) handle it in `runFlow`. That's the whole
surface — it's small and clean.

---

## Change 1 — Conditional steps (`when:`)  ·  *small, high value*

**What:** any step may carry a `when:` shell command. The step runs only if `when` exits
0; otherwise it's marked `skipped`.

**Why:** unlocks "refactor only if the review found issues" — the conditional-refactor
pattern. Today `refine` always runs.

```yaml
- name: refine
  type: agent
  when: grep -q "ISSUE" "{{ .RunDir }}/REVIEW.md"   # only if review flagged something
  prompt: prompts/REFINE.md
```

**Where:**
- `FlowStep`: add `when?: string`.
- `parseFlowYaml`: add `when` to the prop regex allowlist (the
  `(name|type|label|prompt|run|tools|timeoutSeconds)` alternation).
- `runFlow`: before running a step, if `step.when` is set, `runShell(when, …)`; on
  non-zero exit set `steps[i].status = "skipped"` and `continue`. Reuse the existing
  `runShell` + `renderTemplate`.

---

## Change 2 — Artifact assertion (`expect:`)  ·  *small, high value*

**What:** an agent step may declare `expect: REVIEW.md`. After the agent finishes, the
runner asserts that file exists and is non-empty; if not, the step fails.

**Why:** an agent step currently "passes" if the **process exits 0** — a weak signal. An
agent can exit clean having produced nothing. This makes "the agent actually produced its
artifact" a deterministic gate without authoring a separate command step every time.

```yaml
- name: review
  type: agent
  tools: read,bash
  prompt: prompts/REVIEW.md
  expect: REVIEW.md          # fail if REVIEW.md is missing/empty after the step
```

**Where:**
- `FlowStep`: add `expect?: string`.
- `parseFlowYaml`: allowlist `expect`.
- `runFlow`: after the agent branch resolves, if `step.expect`, check
  `fs.statSync(path.join(absoluteRunDir, step.expect)).size > 0`; throw on failure.

> Rule of thumb to teach in the README: **every artifact-producing agent step should be
> followed by a gate** — `expect:` is the one-liner version.

---

## Change 3 — Guarded loop (`type: loop`)  ·  *the big one*

**What:** a new step type that runs an agent body repeatedly until a deterministic gate
passes, with a hard cap, a no-progress abort, and frozen paths. This is the **test → fix
→ green** primitive. Critically, the YAML can only express the *safe* form — there is no
bare `while`.

```yaml
- name: fix_until_green
  type: loop
  prompt: prompts/FIX.md        # the body — reuses existing agent machinery
  tools: read,bash,edit
  until: npm test               # deterministic gate; exit 0 = done
  maxIterations: 4              # REQUIRED — no unbounded loops
  freeze: "test/ spec/"        # paths the body must not modify (anti-reward-hacking)
```

**Semantics (implement in `runFlow`):**
1. Run `until` **first**. If it exits 0 → step passes, body never runs. *(This also gives
   you "skip if already satisfied" for free.)*
2. Else run the body agent (same code path as a normal agent step).
3. **Freeze check:** if `git diff --name-only` intersects `freeze`, fail the step
   (the fix tried to weaken the gate).
4. **No-progress check:** hash the `until` command's combined stdout+stderr. If this
   iteration's hash equals the previous iteration's → abort ("stuck; no progress").
5. Re-run `until`. Exit 0 → pass. Else loop, up to `maxIterations`; on exhaustion → fail
   to the human.
6. Write per-iteration artifacts (`FIX_1.md`, `FIX_2.md`, …) so the run dir shows history.

**The four safety invariants, mapped:** deterministic exit = `until` exit code (step 5);
hard cap = `maxIterations` required (step 5); progress-or-abort = step 4; ungameable gate
= `freeze` (step 3). Missing any one is where loop danger comes from.

**Where:**
- `StepType`: add `"loop"`.
- `FlowStep`: add `until?: string`, `maxIterations?: number`, `freeze?: string`.
- `parseFlowYaml`: allowlist the three fields; parse `maxIterations` with
  `Number.parseInt` (mirror the `timeoutSeconds` branch); in `finish()` require, for
  `type: loop`, both `prompt` and `until`, and `maxIterations > 0`.
- `runFlow`: add a `loop` branch implementing the semantics above. Reuse `runShell`
  (for `until` and the git checks) and `runAgent` (for the body).

> Design note for the video: this is the **"make the dangerous thing un-expressible"**
> principle. You don't hand the user `while` and trust them — you give them a primitive
> that's *only* the caged version. Same philosophy as preferring a command's exit code
> over the agent's self-report.

---

## Change 4 — Optional human gate (`type: confirm` or `pause: true`)  ·  *medium*

**What:** a step that pauses the run and waits for the user to approve before continuing
(e.g. after `plan`, before `build`).

**Why:** restores the highest-leverage human gate — *approve the plan before any code* —
for runs you want supervised. Make it opt-in so autonomous flows stay autonomous.

**Where:** needs interaction through `ctx.ui` (the runner is currently fire-and-forward).
More involved than 1–3; ship it after the others. Consider an env flag
(`FLOW_AUTO_APPROVE=1`) so the same workflow runs both supervised and unattended.

---

## Change 5 — Keep state in files; do *not* add implicit output passing  ·  *a deliberate non-change*

`runAgent` already captures the agent's last assistant text, but `runFlow` only
*summarizes* it — it doesn't feed it to the next step. **Leave it that way.** The
file-artifact pattern (`PLAN.md` → `REVIEW.md`) is better: explicit, inspectable,
resumable, and clean-context. Implicit "pass the last message forward" reintroduces
hidden state and context drift. Reinforce the artifact convention in the docs instead.

---

## Suggested rollout order

1. **Change 1 (`when`)** and **Change 2 (`expect`)** — tiny, immediately make existing
   flows more reliable, great for the demo.
2. **Change 3 (`loop`)** — the headline feature; this is what "dynamic" should mean.
3. Update `flows/code-change.yml` and `flows/github-issue-demo.yml` to use them:
   add `expect:` after `plan`/`review`, make `refactor` conditional with `when:`, and
   replace the linear `checks → review → refactor → final_checks` tail with a
   `fix_until_green` loop.
4. **Change 4 (`confirm`)** — last, once the core is solid.

## A `code-change.yml` that uses all of it (target state)

```yaml
steps:
  - { name: plan,    type: agent,   tools: read,write, prompt: prompts/PLAN.md, expect: PLAN.md }
  - { name: build,   type: agent,   prompt: prompts/BUILD.md }
  - name: green
    type: loop
    prompt: prompts/FIX.md
    tools: read,bash,edit
    until: npm test
    maxIterations: 4
    freeze: "test/ spec/"
  - { name: review,  type: agent,   tools: read,bash, prompt: prompts/REVIEW.md, expect: REVIEW.md }
  - name: refine
    type: agent
    when: grep -q "ISSUE" "{{ .RunDir }}/REVIEW.md"
    prompt: prompts/REFINE.md
  - { name: reverify, type: command, run: npm test }
  - { name: summary,  type: agent,   tools: read,write, prompt: prompts/SUMMARY.md }
```

This reads top-to-bottom as the SOP, and every non-deterministic step is fenced by a
deterministic gate. That contrast — *readable checklist on the outside, caged agents on
the inside* — is the whole pitch.
