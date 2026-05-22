# Orchestrator subagents

Three review subagents the `/loop 5m` heartbeat dispatches in parallel. Defined here per queue item **A4**.

| Subagent | Trigger | What it does | Time budget |
|---|---|---|---|
| [`outcome-reviewer`](outcome-reviewer.md) | PR opens touching `outcomes/*.json` | Scores the pair against HeuristicVerifier, posts one structured comment | seconds |
| [`ci-firefighter`](ci-firefighter.md) | Any open PR shows a red check | Triages (flake / outcome-gate / typecheck / unknown); fixes mechanical breakage in-place; escalates otherwise | 60 sec hard limit |
| [`rubric-tightener`](rubric-tightener.md) | New `evals/results/*.json` lands | Picks the worst-performing dimension; proposes one small port-stable verifier edit; opens a PR on `opensubagents/outcomes` | minutes |

## Dispatch matrix (preview)

Queue item **E4** ships `dispatch.json` mapping events → subagents. Today (A4 only), the orchestrator manually invokes via `Agent({subagent_type: "<name>", ...})`. Once E4 lands, the orchestrator reads dispatch.json instead.

```jsonc
// dispatch.json (E4 — not yet written)
{
  "pull_request.opened":           ["outcome-reviewer"],
  "pull_request.check_failed":     ["ci-firefighter"],
  "eval_results.published":        ["rubric-tightener"]
}
```

## Invariants the orchestrator relies on

- Each subagent has **one job** and a hard scope.
- None of them can disable the outcome-gate or branch protection.
- All of them write to PRs/comments, never to `main` directly.
- They run in parallel; the heartbeat does not wait on them.
