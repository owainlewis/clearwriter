# Dynamic Workflows, the Pi Way

> **Video angle:** Claude Code just shipped dynamic workflows. Pi is a minimalist,
> *extensible* agent — so you can add the same idea yourself. This is the script: what they
> are, the problem they solve, and how to build a declarative version for Pi. Not the same
> tool; the same problem.
>
> Each numbered section is a beat. Pull-quotes (`▶`) are the lines to land on camera.

---

## The hook (cold open)

> Claude Code just shipped **dynamic workflows** — a way to *script* a multi-step agent
> process instead of prompting it one message at a time. It's a genuinely good idea, and
> it points at something important.
>
> Here's the move, though: **you don't have to wait for your agent to ship a feature.** Pi
> is a minimalist, *extensible* coding agent — so when an idea like this lands elsewhere,
> you can just add it yourself, as an extension, on your own terms.

In this video:

1. What dynamic workflows actually are, and the real problem they solve.
2. Why you can't get there by just prompting harder.
3. How to build a declarative version for Pi — and how it compares to Claude's.

It is **not identical** to Claude's dynamic workflows — it makes a different tradeoff
(declarative YAML vs imperative code). But it approaches the **same problem**, and by the
end you'll understand workflows well enough to build or extend your own.

▶ **A good idea shipped in one agent. An extensible agent means you can bring it to yours.**

---

## 1. The problem nobody admits

Every time you work a ticket with an AI agent, you run the **same handful of steps**:

> plan → branch → implement → test → review → fix → verify → open PR

You do it by hand. You type *"now write tests."* Then *"now review it."* Then *"now
fix those."* Then *"did the tests actually pass?"*

This works for one ticket. It does not **scale**, and it is not **consistent**. Some
runs you forget the review. Some runs you trust the agent's "looks good" and ship a bug.
The quality of your output depends on whether *you* remembered to drive every step
correctly, every time.

▶ **A prompt is a one-off instruction. The same work, done a hundred times, deserves a
process — not a hundred prompts typed from memory.**

That process — written down once, runnable again and again — is a **workflow**.

---

## 2. Why workflows matter

Codifying the process buys you four things you can't get from prompting:

- **Consistency** — the same kind of task takes the same path every time.
- **Quality** — the review step *always* runs; the tests *always* run. No skipped checks.
- **Scale** — you stop being the orchestrator. You launch the process and walk away.
- **Shareability** — a team shares a workflow file, not a 600-word prompt nobody trusts.
- **Visibility** — you can *watch* it work: which step is running, what passed, what's
  next. For any step with a gate behind it, you can be sure it actually *happened* — not
  just that the agent claimed so.

▶ **Workflows move you from *prompting agents* to *engineering an agent process*.**

This is the same leap software made from "type the commands by hand each deploy" to
"run the pipeline." The pipeline isn't smarter than you — it's *reliable* in a way a
human typing commands never is.

---

## 3. The key idea: mix deterministic and non-deterministic

Here's the insight the whole thing rests on.

A coding agent is **non-deterministic**. Ask it the same thing twice, get two different
answers. That's a feature for *creative* work (writing code) and a disaster for
*control* work (deciding whether tests passed).

So you split the job:

| Concern | Owner | Why |
|---|---|---|
| The creative work (write code, review, fix) | **Non-deterministic agent** | Judgment, language, synthesis — what LLMs are good at |
| The control (what runs, in what order, did it pass?) | **Deterministic code** | Sequencing, gates, exit codes — what must never "drift" |

▶ **Reliability doesn't come from a smarter agent. It comes from wrapping a
non-deterministic agent in a deterministic skeleton.**

The agent writes the code. A *shell command* — not the agent's opinion — decides whether
the tests passed. The agent reviews the diff. A *file-existence check* — not the agent's
memory — proves the review actually happened.

---

## 4. Attempt #1: "just use subagents." Why it doesn't quite work.

The obvious first try: chain subagents. *Agent, write it. Agent, review it. Agent, fix
it.* Each step a fresh prompt.

This is better than one mega-prompt, but it has three holes — all the same root cause:
**you can't fully trust a prompt.**

1. **Running the check is optional, and the agent owns the definition of "done."** Modern
   agents *do* run tests and read the real output — the problem isn't blindness. It's that
   nothing *forces* the check to run, and nothing stops the agent declaring victory anyway:
   skipping it when it "feels" finished, running only a subset, or waving failures off as
   "unrelated." A prompt can *request* the check; it can't guarantee it ran, or that a
   failure actually stops the line.
2. **The agent reviews its own work with bias.** If the same context that wrote the code
   also reviews it, it defends its choices — *"I just wrote this, it's fine."* The review
   is theater.
3. **The agent drifts.** As the conversation grows, it forgets steps, reorders them, or
   quietly skips the one you cared about most.

▶ **A prompt is a *request*, not a *guarantee*. "Please run the tests" is not the same as
the tests running.**

Chaining prompts gets you ~80%. The last 20% — the part that makes it trustworthy enough
to leave alone — needs something a prompt can't provide: **a check the agent cannot
fake.**

---

## 5. The fix: deterministic gates between non-deterministic steps

Put a **command** between the agent steps. Not "ask the agent to verify" — an actual
shell command whose **exit code** is the source of truth.

```
agent: write code
command: run tests        ← exit 0 or the workflow STOPS. The agent can't lie about this.
agent: review (fresh context, read-only — it physically cannot edit while reviewing)
command: test -s REVIEW.md ← prove the review actually ran and wrote its verdict
agent: fix the findings
```

Two things make this trustworthy:

- **The gate is deterministic.** `exit code 0` is a fact, not an opinion.
- **The reviewer has a clean context.** Run it as a *separate* agent that never saw the
  code being written — it reads the diff fresh, with no "I wrote this" bias. (In a
  sub-process model, this is true *by construction*: the review agent literally doesn't
  have the author's memory.)

▶ **Don't ask the agent if it's done. Ask a command.**

---

## 6. Visibility: the glass box

A raw agent is opaque. You fire a prompt and watch a wall of text scroll by, with no idea
where it is, what it's done, or whether it's on track. A workflow makes the **process
observable**:

```
✓ Creating branch   (1/5)
✓ Writing code      (2/5)
▶ Running review    (3/5)
```

This isn't decoration — it's four concrete benefits:

- **You can be sure a step accomplished its purpose — not just that it "ran."** This isn't
  a knock on job orchestrators like Temporal or Airflow — they have *excellent* step-level
  visibility, and they're built for a different job (durable production execution, not your
  local dev loop). The point is narrower: their notion of success is *"the worker returned
  without throwing"* — exactly right for a *deterministic* worker, and nearly meaningless
  for a *non-deterministic* one, which can return cleanly having done the wrong thing, or
  nothing at all. A gated workflow shows `review ✓` *because a command confirmed it*, so the
  green check means the step did its job, not merely that a process exited. Ran ≠ did the
  thing.
- **Failure is localized.** When a run breaks you see it failed *at review*, not at build —
  and the run directory holds the artifact to prove it. You debug a step, not a transcript.
- **You can intervene early.** See it stuck on step 2 and abort now, instead of finding the
  mess at the end. You can't course-correct what you can't see.
- **You can *talk to it* about what went wrong.** This is the quiet superpower of running
  the flow *inside* the coding agent. When `review` fails, the agent that just ran it still
  has the context — you ask *"why did the review fail?"* and it answers from what it just
  saw. Debugging is a conversation, not a forensic reconstruction. A fire-and-forget script
  gives you a stack trace and a cold start; an in-agent workflow gives you a colleague who
  was there.

There's a tell hidden in here: **you can only show a tracker because the work has named,
ordered steps.** A monolithic prompt has nothing to display — it has no parts. So a visible
progress tracker is also a *diagnostic*: if your "workflow" can't render one, it's still a
blob.

One caveat, to keep it honest: **a visible status is only as trustworthy as the gate behind
it.** `tests ✓` means something only if a command checked the exit code. A
non-deterministic-only system can cheerfully display "passed" when it didn't — the
checkmark inherits the agent's unreliability. Visibility and determinism are a pair.

▶ **A raw agent is a black box. A workflow is a glass box — and you only walk away from work
you can watch.**

---

## 7. The hard part: loops (and why they're dangerous)

Some steps need to *repeat*. "Fix the failing test" might take one try or four. You can't
know the count in advance. That smells like a loop — and loops with agents are where
people get burned:

- **Non-termination** — it "fixes" forever, burning money.
- **Oscillation** — fix A breaks B, fix B breaks A, ping-pong.
- **Reward hacking** — told to "make tests pass," it *deletes the failing test.* Green
  board, broken code. This is the scary one.

But here's the reframe that defuses it:

▶ **Loops aren't dangerous. Letting the *agent* decide when to stop is dangerous.**

Move the stop decision to deterministic code and the scary part disappears: like `for i in
range(4)`, the loop *can't run forever*. Bounded termination is just the first of **four**
guards a safe agent loop needs — and the danger is always a missing one:

1. **Deterministic exit** — a command's exit code, never "the agent thinks it's done."
2. **Hard cap** — max N iterations, then fail to a human.
3. **Progress-or-abort** — same failure twice in a row → stop; you're stuck.
4. **Hard-to-game gate** — freeze the test files so "fix the code" can't become "weaken the
   test." (That closes the obvious vector, not every one — see §10.)

There's a subtlety worth saying out loud, because it tells you *when* you even need a loop:

- **Quality repetition** (review → refine): converges in 1–2 passes, count known up front.
  → **Don't loop. Just lay out the steps** (unroll it). Pass findings through a file.
- **Correctness repetition** (test → fix → green): count is data-dependent.
  → **This is the one place a guarded loop earns its keep.**

▶ **You need exactly one real loop, in one place — reaching green — and it must be caged.
Everything else is better as explicit, readable steps.**

---

## 8. Two ways to build this: Pi Flow vs Claude dynamic workflows

Both solve the same problem — codify a repeatable agent process, mixing deterministic
control with non-deterministic work. They differ on **one axis: declarative vs
imperative.**

### Pi Flow (this extension) — *declarative*

A workflow is a **YAML checklist**. Steps are either `command` (deterministic shell) or
`agent` (a focused sub-process with a limited tool list). State passes between steps as
**files** (`PLAN.md` → `REVIEW.md`).

```yaml
steps:
  - { name: plan,   type: agent,   prompt: prompts/PLAN.md, tools: read,write }
  - { name: gate,   type: command, run: 'test -s "{{ .RunDir }}/PLAN.md"' }
  - { name: build,  type: agent,   prompt: prompts/BUILD.md }
  - { name: tests,  type: command, run: npm test }
  - { name: review, type: agent,   prompt: prompts/REVIEW.md, tools: read,bash }
```

- **Strengths:** you can *read the file and know exactly what will happen.* Trivially
  shareable and versionable. The structure itself prevents skipped steps. Low floor —
  anyone can author one.
- **Limits (today):** linear only. No loops, no conditionals. (That's exactly what we add
  in the change list.)
- **Philosophy:** *a workflow is configuration.* The process is data.

### Claude dynamic workflows — *imperative*

A workflow is a **JavaScript program** that orchestrates agents. It has real control
flow: `parallel()` for fan-out, `pipeline()` for staged work, loops, conditionals,
token-budget-aware iteration, and agents that return **schema-validated structured
output** instead of free text.

```js
const findings = await agent("review this diff", { schema: FINDINGS })
const verified = await parallel(findings.map(f =>
  () => agent(`refute: ${f.claim}`, { schema: VERDICT })))   // fan-out, in parallel
```

- **Strengths:** maximum expressiveness. Parallel fan-out, loops, conditionals, and
  structured results are built in, not bolted on. High ceiling.
- **Limits:** it's *code you write per workflow.* Less auditable at a glance, higher
  floor, and tied to the Claude runtime.
- **Philosophy:** *a workflow is a program.* The process is logic.

### How to choose

| | **Pi Flow (declarative)** | **Claude dynamic workflows (imperative)** |
|---|---|---|
| Author by | Editing YAML | Writing JavaScript |
| Read-and-understand | Instant | Requires reading code |
| Control flow | Linear (+ what we add) | Loops, conditionals, parallel — native |
| Parallel fan-out | No | Yes |
| Structured agent output | Files | Schema-validated objects |
| Best for | Stable, shareable SOPs a team reuses | Complex, branching, parallel orchestration |
| Floor / ceiling | Low floor, modest ceiling | Higher floor, high ceiling |

▶ **Same idea, two surfaces. Declarative when the process is stable and you want anyone
to read it; imperative when the process needs real branching and parallelism. Most
people should start declarative — and reach for code only when the YAML can't say what
they mean.**

---

## 9. Anticipating the pushback: "can't I already do this with X?"

You will get this — so name the X's yourself before someone else does. The honest answer
has two halves.

**The concept is not new.** Orchestrating multi-step processes with deterministic gates is
a deeply populated space. Say so plainly:

- **CI/CD (GitHub Actions, GitLab CI, Jenkins…)** — pipelines orchestrate *deterministic*
  steps. The twist here is putting *non-deterministic agent* steps inside, gated, and
  running it in your dev loop instead of post-push.
- **Workflow / agent frameworks (LangGraph, CrewAI, AutoGen, Temporal, Prefect, n8n…)** —
  these do graph/DAG agent orchestration. But they're *frameworks you build an app in.*
  Flow is a thin, declarative layer that lives *inside the coding agent* and operates on
  your actual repo, in your terminal.
- **A bare shell script** — `pi -p plan && npm test && pi -p review` genuinely is a minimal
  version of this. This is the most honest "X." What you'd rewrite by hand every time is the
  80% of plumbing Flow gives you for free: per-step tool scoping, clean-context
  sub-processes, the progress UI, run artifacts/summaries, and guarded loops.
- **Claude Code (hooks + subagents + dynamic workflows)** — within the Claude ecosystem this
  capability *largely already exists* — and if you're on Claude Code, use it. That's the
  whole point, not a problem: **the interesting thing is the pattern, not the
  implementation.** If you're *not* on Claude Code, you apply the same ideas to whatever
  agent you do use. Flow is just the Pi-native, declarative take.

**So what's defensible is positioning, not invention:** a *lightweight, declarative,
repo-native* workflow layer *inside the coding agent you already use*, with the
agent-specific ergonomics baked in. You're not claiming a new concept — you're claiming a
better *ergonomic point* for one specific job: running your repeatable dev SOP, in your
agent, on your repo, where the whole process is a YAML file anyone can read.

▶ **Don't sell it as new. Sell it as clear. Name every "isn't this just X," then explain why
a declarative, in-agent checklist beats each one for *this* job. Owning the comparison is
far stronger than getting caught by it.**

The one rebuttal to rehearse is the shell-script objection, because it's the truest.
Concede it instantly — *"yes, you can"* — then show the plumbing you'd reimplement, and the
fact that nobody actually maintains that script across twenty tickets. **Convenience that
gets used beats capability that doesn't.**

And there's a difference a script can't close: **a shell script is fire-and-forget.** When
it dies you get a stack trace and a cold start — to debug it you spin up a *fresh* agent
that has to reconstruct what happened from scratch. The Pi workflow runs *inside the agent*,
so when a step fails you just turn to the agent that ran it and ask why — it already has the
context. The script hands you a corpse; the in-agent flow hands you a witness.

▶ **The script runs your steps. The agent runs your steps *and is still there to talk to
when one breaks.* That's not plumbing you can bolt onto a bash file.**

---

## 10. What gates can't do — the honest ceiling

Be straight about the limit, or a sharp viewer will be straight about it for you:
**deterministic gates verify mechanics, not correctness.**

- `test -s PLAN.md` proves a plan *exists* — not that it's any good.
- Tests passing proves you didn't regress the tests you *already had* — not that the new
  code is right, nor that the agent's new tests exercise anything real.
- Freezing test files (§7) stops the obvious reward-hack — not special-casing code to the
  test, or adding a trivial always-green test.

Gates **raise the floor**; they don't certify the ceiling. What manages the residue is the
*clean-context review* (still a probabilistic agent — just an unbiased one) and, above all,
a **good ticket**: clear acceptance criteria the work is actually checked against. Garbage
ticket in, garbage-but-green out.

▶ **A green workflow means "nothing I knew to check is broken." That's a high floor — not a
proof of correctness. Don't sell it as one.**

---

## 11. The takeaway

The shift isn't "use a fancier tool." It's a change in how you think:

▶ **Stop prompting your agent. Start engineering the process your agent runs inside.**

- Let the agent do the *non-deterministic* creative work.
- Let *deterministic* code own the control and the gates.
- Never let the agent decide whether it's done — ask a command.
- Cage the one loop you need; unroll the rest.

That's what turns a clever-but-flaky assistant into a process you can trust to run a
ticket largely unattended — provided you still read the diff before you merge (§10).

---

## 12. The real lesson: you can just build this

The headline isn't "Claude shipped a feature." It's that a capability landing in one agent
doesn't have to be something you *wait* for. Pi is minimalist and **extensible** — the
whole workflow runner is a single extension. Deterministic gates and clean-context
sub-agents are already in it; the parts that take it the rest of the way (guarded loops,
conditionals) are a handful of additions on top. You read the news, you liked the idea, you
brought it home the same week.

▶ **When a good idea ships somewhere else, an extensible agent lets you bring it home — on
your terms, with your tradeoffs.**

Claude's dynamic workflows are imperative and powerful. The Pi version is declarative and
legible, and it lives inside the agent you're already talking to. Different tradeoff, same
problem — and you built it yourself. The exact changes are in `flow-changes.md`.
