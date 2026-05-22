# Passing evaluation pairs

> D1 fixture set: real outcome+report pairs sourced from actual PRs across
> the enterprise. Each pair scores ≥3.5 against the HeuristicVerifier
> (canonical floor) and represents a merged change. The set drives D3's
> confusion matrix.

## Inventory (20 of 20 — D1 complete)

Sourced from `opensubagents/outcomes-mcp` (this repo, real merged PRs):

1. `bootstrap` — outcomes-mcp Codemode MCP server bootstrap
2. `orchestrator-bootstrap` — heartbeat orchestrator bootstrap
3. `tick-1-A1-protection` — branch protection PUT
4. `tick-2-A4-subagents` — three review subagents codified
5. `tick-3-A5-session-start` — session-start hook + sentinel guard
6. `tick-4-B1-B2-typecheck` — typecheck CI proof
7. `tick-5-B3-record` — submodule cross-repo PR opened
8. `tick-6-B3-done-B4-probe` — submodule merge + probe.sh shipped
9. `tick-7-C1-builds-audit` — Cloudflare Workers Builds MCP audit
10. `tick-8-C2-wrangler-deploy` — `wrangler deploy` + `/healthz` 200
11. `tick-9-C3-blocked-C4-auth` — bearer-token auth on `/mcp`
12. `tick-10-C5-observability` — Workers Observability MCP query
13. `tick-11-C6-blocked-C7-radar` — AI Gateway misfit + Radar baseline
14. `outcomes-mcp-tick-12-d1-seed` — D1 seed fixture (outcomes-mcp#13)
15. `outcomes-mcp-tick-13-d2-seed` — D2 seed fixture (outcomes-mcp#14)

Sourced from `opensubagents/outcomes` (the spec repo, real merged PRs):

16. `spec-bootstrap-v010` — v0.1.0 spec bootstrap (outcomes#1)
17. `spec-drop-research-engineering` — drop bootstrap scaffold (outcomes#2)
18. `spec-revert-session-hook` — revert blocking SessionStart hook (outcomes#5)
19. `spec-outcome-gate` — outcome-gate CI workflow (outcomes#6)
20. `spec-mcp-server-submodule` — submodule pointer + docs (outcomes#10)

## Verification

To re-run all pairs through the gate:

```bash
for o in evals/pairs/passing/*.outcome.json; do
  base=$(basename "$o" .outcome.json)
  python -m open_outcome.cli verify "$o" "evals/pairs/passing/$base.report.json" --floor 3.5
done
```

Last verified: 2026-05-22 — 20/20 pairs pass (overall ≥ 3.5).
