# ADR 0001 — Rubric calibration baseline

**Status:** Accepted
**Date:** 2026-05-22
**Authors:** Orchestrator heartbeat (tick 16)

## Context

D3 shipped `scripts/eval.sh` and produced the first confusion matrix for the
HeuristicVerifier against the 40-pair seed set (20 passing fixtures from real
merged PRs + 20 hand-crafted failing fixtures targeting each rubric dimension).
This ADR records the calibration baseline so future rubric edits can be
diffed against it, and decides what to do with the result.

## The baseline (floor = 3.5)

Source: `evals/results/2026-05-22.json` (verified `verifier_id =
open-outcome.python.heuristic`).

| Metric            | Value |
|-------------------|-------|
| Pairs scored      | 40    |
| True positives    | 20    |
| False negatives   | 0     |
| True negatives    | 20    |
| False positives   | 0     |
| Parse errors      | 0     |
| Accuracy          | 1.000 |
| Precision         | 1.000 |
| Recall            | 1.000 |

Per-bucket score distribution:

| Bucket    | Min  | Median | Max  |
|-----------|------|--------|------|
| Passing   | 4.4  | 5.0    | 5.0  |
| Failing   | 1.4  | 2.8    | 3.4  |

A 0.1-wide buffer (3.4 → 3.5) separates the worst passing fixture (4.4) from
the best failing fixture (3.4). **No fixture falls in the 3.5 – 4.4 band.**
That band is the calibration blind spot of the current seed set.

## Per-dimension firing (failing bucket)

The 20 failing fixtures were authored to push exactly one rubric dimension to
the floor at a time, with a `combined/` bucket that pushes several. The
following table records which dimension actually dragged the overall score
below 3.5 for each fixture (verified against
`evals/pairs/failing/MANIFEST.md`):

| Dimension targeted          | Pairs | All fired? |
|-----------------------------|-------|------------|
| clarity                     | 3 (a*) | yes |
| citation_quality            | 4 (b*) | yes |
| confidence_calibration      | 4 (c*) | yes |
| coverage                    | 2 (d*) | yes |
| decision_usefulness         | 2 (e*) | yes |
| combined / pathological     | 5 (f*) | yes |

Every dimension fires in isolation; no dimension is silently dead.

## Decision

1. **Adopt 3.5 as the canonical floor for v0.1.0.** It cleanly separates the
   seed set with a 0.1-wide margin and no false positives or false negatives.
2. **Treat the current matrix as a regression baseline, not as a quality
   oracle.** Perfect classification on a hand-curated seed set is necessary
   but not sufficient evidence of rubric quality. The matrix protects against
   future verifier edits that silently break a dimension.
3. **Wire `scripts/eval.sh` into CI as a soft gate (warning, not blocker)
   for now.** Hard-gating a perfect matrix would freeze the rubric. Wait
   until D5 (citation staleness) and D6 (URL liveness) add asymmetric checks
   that can flip a known-passing fixture below 3.5 — those are the real tests.
4. **Defer the floor ratchet to 4.0 (B5).** The seed set has no pairs in the
   3.5 – 4.4 band, so a ratchet to 4.0 would pass without exercising the
   transition. Before ratcheting:
   - D1 should grow with naturalistic pairs likely to land in the 3.5 – 4.0
     band (operator-authored PRs where summary is terse, or where coverage is
     intentionally narrow). 5 such pairs would create the calibration shoulder
     the ratchet needs.
   - The bootstrap pair (`outcomes/orchestrator-bootstrap.{outcome,report}.json`)
     and `outcomes-mcp/outcomes/bootstrap.{outcome,report}.json` must continue
     to clear the new floor; their current scores are at the ceiling so this
     is unlikely to bind.

## Consequences

- **Bias toward false confidence.** Anyone reading this matrix in isolation
  will conclude the rubric is "perfect". It is perfect *on a curated set
  designed to be perfectly classified*. The metrics in §"The baseline" are
  true and uninformative simultaneously; future PRs that grow D1 with
  naturalistic pairs are the real signal.
- **Calibration blind spot.** The 3.5 – 4.4 band is untested. D5/D6 will fill
  it asymmetrically (staleness/liveness can downgrade an otherwise-passing
  pair). If the matrix ever shows a pair scoring 3.4 – 3.5 or 4.4 – 4.5, that
  is the first interesting datapoint — investigate, do not blindly add to
  fixtures.
- **B5 + E3 unlocked.** With D3 done, both can proceed:
  - B5 (floor ratchet) should land *after* the calibration shoulder is in
    place.
  - E3 (rubric-tightener subagent) should consume the matrix JSON directly.

## How to re-run the calibration

```bash
scripts/eval.sh                           # canonical floor 3.5
scripts/eval.sh --floor 4.0               # what would a ratchet do?
scripts/eval.sh --out evals/results/sanity.json
```

The script exits non-zero when any FP or FN appears. Wire it into CI per §3.

## References

- `evals/results/2026-05-22.json` — the verdict this ADR records
- `evals/pairs/passing/MANIFEST.md` — D1 fixture inventory (20/20)
- `evals/pairs/failing/MANIFEST.md` — D2 fixture inventory (20/20) and
  per-pair dimension attribution
- `scripts/eval.sh` — the matrix emitter
- `sdk-python/open_outcome/verifier.py` (in opensubagents/outcomes) — the
  reference HeuristicVerifier whose contract this ADR pins to v0.1.0
- ADR follow-ups: B5 (floor ratchet), D5 (staleness), D6 (URL liveness),
  E3 (rubric-tightener subagent)
