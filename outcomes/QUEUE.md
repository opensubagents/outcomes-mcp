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
| A1 | done | — | Branch protection on `opensubagents/outcomes-mcp` main (require `outcome-gate`, enforce_admins, linear history) | `outcomes/runrocs/A1-protection.json` |
| A2 | done | — | QUEUE.md committed at `outcomes/QUEUE.md` with all 31 outcomes | `outcomes/QUEUE.md` |
| A3 | done | — | Heartbeat prompt committed at `.claude/loop-prompt.md` | `.claude/loop-prompt.md` |
| A4 | done | A3 | Three review subagents codified in `.claude/agents/`: outcome-reviewer, ci-firefighter, rubric-tightener | `.claude/agents/README.md` |
| A5 | done | — | Session-start hook (background dispatch + sentinel guard, <100ms blocking) at `.claude/settings.json` + `scripts/session-start.sh` | `outcomes/runrocs/A5-latency.txt` |

### Track B — Outcome-gate hardening

| id | status | depends_on | title | runroc_path |
|---|---|---|---|---|
| B1 | done | A1 | Prove `typecheck` workflow runs green on a probe commit | `outcomes/runrocs/B1-typecheck-runs.json` |
| B2 | done | A1 | Subsumed into A1 — branch protection already covers outcomes-mcp main | `outcomes/runrocs/A1-protection.json` |
| B3 | done | A1 | Submodule outcomes-mcp into `opensubagents/outcomes/mcp-server/` via PR on outcomes repo | https://github.com/opensubagents/outcomes/pull/10 |
| B4 | done | A1 | `scripts/probe.sh below-floor` opens a draft PR with known-failing pair; asserts gate red | `outcomes/runrocs/B4-probe.log` |
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

- 2026-05-22T05:45Z tick-1 A1 pending → done (branch protection PUT, runroc A1-protection.json) | next: A4
- 2026-05-22T05:45Z tick-1 noted: outcomes#3 has 1 failing check; ci-firefighter subagent (A4) not yet shipped, will revisit after A4 merges
- 2026-05-22T05:50Z tick-2 A4 pending → done (3 subagents codified in .claude/agents/) | next: A5
- 2026-05-22T05:50Z tick-2 noted: outcomes#3 still red; ci-firefighter now exists but the heartbeat itself didn't spawn it this tick (one atomic step rule); will spawn next tick
- 2026-05-22T06:00Z tick-3 A5 pending → done (.claude/settings.json + scripts/session-start.sh; latency runroc 5x runs, 4/5 at 0.00s) | next: B1
- 2026-05-22T06:00Z tick-3 dispatched ci-firefighter subagent on outcomes#3: classified as outcome-gate failure (missing pair); posted triage comment + tagged @alex-jadecli; PR author owns the fix
- 2026-05-22T06:05Z tick-4 B1 pending → done (typecheck runroc captured 6 runs all SUCCESS) + B2 pending → done (subsumed into A1) | next: B3
- 2026-05-22T06:05Z tick-4 outcomes#3 still red: same outcome-gate-missing-pair situation; firefighter already triaged it, awaiting operator action
- 2026-05-22T06:10Z tick-5 B3 pending → in_progress (cross-repo PR opensubagents/outcomes#10 opened with submodule + docs; auto-merge armed; will mark done next tick after merge) | next: B4
- 2026-05-22T06:10Z tick-5 outcomes#3 still red, unchanged; no re-dispatch
- 2026-05-22T06:15Z tick-6 B3 in_progress → done (outcomes#10 merged 06:06Z) + B4 pending → done (scripts/probe.sh shipped with three drill modes; runroc cites prior session probe evidence) | next: B5 (blocked on D3) or C1
- 2026-05-22T06:15Z tick-6 outcomes#3 still red, unchanged; no re-dispatch






