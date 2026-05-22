# Orchestrator queue

> Source of truth for the `/loop 5m` heartbeat. Each tick reads this file, picks
> the **lowest-id pending** outcome whose `depends_on` are all `done`, advances
> it one atomic step, updates the row, and reports.
>
> **Status values**: `pending` · `in_progress` · `done` · `blocked`
>
> **Runroc** = run-of-record artifact. Every `done` outcome must point at one
> (PR URL, screenshot path, runtime output saved to `runrocs/`).

## Operating rules (read every tick)

1. **Never invent new outcomes.** Only execute what's listed below.
2. **Always PR** — no direct push to main. Auto-merge once gate green.
3. **CI red anywhere** → spawn `ci-firefighter` subagent in parallel; continue with next pending outcome.
4. **Dogfood**: each PR MUST add `outcomes/<slug>.outcome.json` + `outcomes/<slug>.report.json` scoring ≥3.5 against HeuristicVerifier. The outcome-gate enforces this.
5. **Slugs are append-only.** Pick a fresh kebab-case slug per PR.
6. **One atomic step per tick.** If a step takes >1 tick (e.g. waiting for CI), leave the outcome `in_progress` and pick the next pending one.

## Queue

### Track A — Orchestration foundation (sequential, unblocks all)

| id | status | depends_on | title | runroc_path |
|---|---|---|---|---|
| A1 | pending | — | Branch protection on `opensubagents/outcomes-mcp` main (require `outcome-gate`, enforce_admins, linear history) | `outcomes/runrocs/A1-protection.json` |
| A2 | done | — | QUEUE.md committed at `outcomes/QUEUE.md` with all 31 outcomes | `outcomes/QUEUE.md` |
| A3 | done | — | Heartbeat prompt committed at `.claude/loop-prompt.md` | `.claude/loop-prompt.md` |
| A4 | pending | A3 | Three review subagents codified in `.claude/agents/`: outcome-reviewer, ci-firefighter, rubric-tightener | `.claude/agents/README.md` |
| A5 | pending | — | Session-start hook (background dispatch + sentinel guard, <100ms blocking) at `.claude/settings.json` + `scripts/session-start.sh` | `runrocs/A5-latency.txt` |

### Track B — Outcome-gate hardening

| id | status | depends_on | title | runroc_path |
|---|---|---|---|---|
| B1 | pending | A1 | Prove `typecheck` workflow runs green on a probe commit | PR URL |
| B2 | pending | A1 | (Subsumed into A1 — drop if A1 covers it) Branch protection mirror | PR URL |
| B3 | pending | A1 | Submodule outcomes-mcp into `opensubagents/outcomes/mcp-server/` via PR on outcomes repo | PR URL on outcomes |
| B4 | pending | A1 | `scripts/probe.sh below-floor` opens a draft PR with known-failing pair; asserts gate red | `runrocs/B4-probe.log` |
| B5 | pending | D3 | Ratchet floor 3.5→4.0 in a feature branch; bootstrap pair must still pass; hold for human merge | PR URL |

### Track C — Cloudflare wiring

| id | status | depends_on | title | runroc_path |
|---|---|---|---|---|
| C1 | pending | — | Query Cloudflare Workers Builds MCP for outcomes-mcp build history | `runrocs/C1-builds.json` |
| C2 | pending | A1 | `wrangler deploy` outcomes-mcp to Workers; verify `/healthz` returns 200 from live URL | `runrocs/C2-deploy.txt` |
| C3 | pending | C2 | Custom domain `outcomes.mcp.opensubagents.org` via Cloudflare DNS MCP | `runrocs/C3-dns.txt` |
| C4 | pending | C2 | Bearer-token auth on Workers (`wrangler secret put`) + curl probe with/without | `runrocs/C4-auth.txt` |
| C5 | pending | C2 | Cloudflare Observability MCP query confirms live worker received traffic | `runrocs/C5-obs.json` |
| C6 | pending | C2 | AI Gateway in front of the MCP; verify gateway log entries | `runrocs/C6-gateway.json` |
| C7 | pending | — | Radar MCP baseline traffic for opensubagents.org saved for diff | `runrocs/C7-radar.json` |

### Track D — Eval / rubric tightening

| id | status | depends_on | title | runroc_path |
|---|---|---|---|---|
| D1 | pending | — | 20 high-quality outcome+report pairs at `evals/pairs/passing/*.json` (sourced from real PRs across enterprise) | `evals/pairs/passing/` |
| D2 | pending | — | 20 deliberately-bad pairs at `evals/pairs/failing/*.json` covering each failure mode | `evals/pairs/failing/` |
| D3 | pending | D1,D2 | `scripts/eval.sh` runs verifier across all 40 pairs; emits confusion matrix | `evals/results/{date}.json` |
| D4 | pending | D3 | First ADR: `docs/adrs/0001-rubric-calibration.md` records FP/FN rates from D3 | `docs/adrs/0001-rubric-calibration.md` |
| D5 | pending | D4 | Citation-staleness check: downgrade citation_quality if `accessed` >180 days. Ports across spec, sdk-python, sdk-typescript, CLI test | PR URL on outcomes |
| D6 | pending | D4 | Optional `--check-urls` flag: HEAD-request each citation, downgrade on 4xx/5xx | PR URL on outcomes |

### Track E — Multi-agent review surface

| id | status | depends_on | title | runroc_path |
|---|---|---|---|---|
| E1 | pending | A4 | outcome-reviewer subagent runnable: reads open PR, scores pair, posts review comment | Example PR URL |
| E2 | pending | A4 | ci-firefighter subagent runnable: reads failed CI, opens fix PR | Example fix PR URL |
| E3 | pending | A4,D3 | rubric-tightener subagent runnable: given matrix from D3, proposes rubric edit | Example proposal PR URL |
| E4 | pending | E1,E2,E3 | `.claude/dispatch.json` event→subagent matrix; test simulates each event | `runrocs/E4-dispatch-test.log` |

### Track F — Operator surfaces

| id | status | depends_on | title | runroc_path |
|---|---|---|---|---|
| F1 | done | — | Orchestrator memory at `~/.claude/projects/.../memory/orchestrator.md` | (operator-side file) |
| F2 | pending | C2 | VS Code MCP probe — confirm outcomes-mcp reachable; screenshot saved | `runrocs/F2-vscode.png` |
| F3 | pending | C2 | Claude Desktop config check — Desktop calls verify_outcome_pair; transcript saved | `runrocs/F3-desktop.md` |
| F4 | pending | A2,A3,F1 | `RESUME.md` in repo root: top-5 files to read on session resume | `RESUME.md` |

## Tick log

The heartbeat appends one line per tick:

```
2026-05-22T05:30Z A1 in_progress → done (PR #N merged) | next: A4
```
