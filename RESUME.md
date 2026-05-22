# RESUME.md — what to read first when picking up this repo

> Read this first if you're a fresh Claude session, a new operator, or
> the rotation just brought you in. **Top 5 files, in order.** Stop at
> file 5 unless you've been told to do something specific.

## 1. `outcomes/QUEUE.md`

The orchestrator's source of truth. Lists all 31 outcomes across 6
tracks (A=foundation, B=outcome-gate hardening, C=Cloudflare wiring,
D=eval/rubric tightening, E=multi-agent review surface, F=operator
surfaces). Each row has `id | status | depends_on | title | runroc_path`.

Status values: `pending`, `in_progress`, `done`, `blocked`.

The tail of this file is the **tick log** — one or two lines per
heartbeat firing, oldest at the top, newest at the bottom. The last few
lines tell you the freshest state without needing to re-derive it.

## 2. `.claude/loop-prompt.md`

The heartbeat payload. This is the prompt that fires every 5 minutes
via `/loop 5m`. The procedure is exact: read QUEUE, scan PRs, pick
lowest-id pending whose deps are done, advance one atomic step, append
tick log, PR through, commit + push via PR. Re-read this every tick.

## 3. `~/.claude/projects/-Users-alexzh-subagentmcp-opensubagents/memory/orchestrator.md`

Operator-side memory file. Records the operating model, rules, what's
done, and what's not. Lives outside the repo so it travels with the
operator identity across machines, but it stays in lockstep with QUEUE.md.

## 4. `docs/adrs/0001-rubric-calibration.md`

The first (and currently only) Architecture Decision Record. Documents
the D3 confusion-matrix baseline (TP=20 FN=0 TN=20 FP=0; floor=3.5),
explains why the matrix is "true and uninformative simultaneously",
and names the 3.5–4.4 calibration blind spot as the real test that
D5/D6 are designed to fill. **Read before doing any rubric work or
flipping the floor in B5.**

## 5. `.claude/agents/README.md`

The three review subagents. Each role spec is one file:
- `outcome-reviewer.md` — scores a PR's outcome+report pair and posts
  a structured review comment.
- `ci-firefighter.md` — triages red CI, classifies the failure,
  posts one triage comment, honors dedup.
- `rubric-tightener.md` — given a confusion matrix, proposes one
  ports-stable verifier edit (or returns `no_tightening_needed` when
  the matrix is error-free).

All three have been dispatched via the Agent tool from the heartbeat
in past ticks; see `outcomes/runrocs/E1-outcome-reviewer.json`,
`outcomes/runrocs/E2-ci-firefighter.json`, and
`outcomes/runrocs/E3-rubric-tightener.md` for the runrocs that prove
each one runnable.

---

## State at a glance (verified 2026-05-22T07:50Z)

- **Track A** complete (A1–A5): orchestration foundation in place.
- **Track B** 4 done, 1 in_progress: B1–B4 done; **B5** floor-ratchet
  PR opensubagents/outcomes-mcp#18 is open and **intentionally held
  for human merge** per its row text and ADR 0001's deferral note.
- **Track C** 5 done, 2 blocked: C1/C2/C4/C5/C7 done; C3 blocked
  (apex zone `opensubagents.org` not in Cloudflare account); C6
  blocked (AI Gateway is LLM-provider-only, doesn't fit MCP servers).
- **Track D** complete (D1–D6): rubric + eval surface in place.
- **Track E** complete (E1–E4): three review subagents proven runnable,
  dispatch matrix shipped with 9/9-pass harness.
- **Track F** 3 done + this file finishing F4.

## Live infrastructure

- **Live worker**: `https://outcomes-mcp.alex-e62.workers.dev`
  (Cloudflare Workers, version 89b17bef per C4 deploy; bearer-auth on
  `/mcp`, `/healthz` public).
- **Bearer token**: `/tmp/outcomes-mcp-bearer-token-tick9.txt` (operator
  machine only; matches the `MCP_BEARER_TOKEN` wrangler secret).
- **Heartbeat**: `/loop 5m` cron job `352508ff` (created tick 0).
- **Branch protection**: outcomes-mcp `main` requires `outcome-gate` +
  `typecheck` + linear history + enforce_admins=true.

## What's next (if no operator guidance)

The only pending item with met dependencies is **B5** (the floor ratchet
PR is held for human merge — heartbeat must not auto-merge it).
Everything else is either `done`, `blocked` (waiting for operator
decisions on C3/C6), or `in_progress` (B5 awaiting human review).

The honest answer is: this is a good resting point. The orchestrator
should keep firing every 5 minutes and continue logging the tick state,
but there is no atomic step it can productively take without operator
input on B5, C3, or C6.
