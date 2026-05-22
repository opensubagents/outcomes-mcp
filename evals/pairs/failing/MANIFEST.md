# Failing evaluation pairs

> D2 fixture set: 20 deliberately-bad outcome+report pairs, each scoring
> **below 3.5** against the HeuristicVerifier and each targeting a
> specific failure mode the rubric is meant to catch. These are the
> negative class for D3's confusion matrix.

## Layout

The slug prefix encodes which dimension the pair primarily targets:

| Prefix | Dimension exercised | Pairs |
|---|---|---|
| `a*` | clarity (summary length) | a1, a2, a3 |
| `b*` | citation_quality | b1, b2, b3, b4 |
| `c*` | confidence_calibration | c1, c2, c3, c4 |
| `d*` | coverage (success_criteria miss) | d1, d2 |
| `e*` | decision_usefulness (no signals) | e1, e2 |
| `f*` | combined / pathological | f1, f2, f3, f4, f5 |

## Scores (verified 2026-05-22 against the python HeuristicVerifier)

| Slug | Overall | Note |
|---|---|---|
| `a1-clarity-one-sentence`              | 3.4 | summary is 1 sentence → clarity=3 |
| `a2-clarity-six-sentences`             | 2.8 | 6-sentence summary → clarity=2 |
| `a3-clarity-ten-sentences`             | 2.8 | 10-sentence summary → clarity=2 |
| `b1-citations-none`                    | 2.8 | report has no citations → citation_quality=1 |
| `b2-citations-community-only`          | 2.8 | community-only → citation_quality=1 |
| `b3-citations-secondary-only`          | 3.0 | secondary-only → citation_quality=2 |
| `b4-citations-mostly-community`        | 2.2 | mostly community → citation_quality=1 |
| `c1-calibration-high-one-primary`      | 2.8 | high-conf with 1 primary → calibration violation |
| `c2-calibration-high-zero-primary`     | 2.2 | high-conf with 0 primary → calibration violation |
| `c3-calibration-low-well-sourced`      | 2.8 | low-conf with ≥2 primary → under-calibrated |
| `c4-calibration-medium-weak`           | 2.2 | medium-conf with weak sourcing → violation |
| `d1-coverage-zero-hits`                | 1.4 | success_criteria zero overlap with claims |
| `d2-coverage-one-of-five`              | 1.6 | 1/5 axes hit |
| `e1-decision-no-signals`               | 3.4 | no recommend/tradeoff/caveats/methodology |
| `e2-decision-one-signal`               | 3.2 | only methodology_notes signal |
| `f1-combined-minimal`                  | 1.6 | every dimension at the floor |
| `f2-combined-hyperconfident`           | 1.4 | high-conf single community citation |
| `f3-combined-mixed-bad`                | 3.4 | three claims spanning bad modes |
| `f4-combined-worst`                    | 1.4 | shortest summary + community-only |
| `f5-coverage-trap`                     | 1.4 | passes other dims, coverage zeroes it |

## How to re-verify

```bash
for o in evals/pairs/failing/*.outcome.json; do
  base=$(basename "$o" .outcome.json)
  python -m open_outcome.cli verify "$o" "evals/pairs/failing/$base.report.json" --floor 3.5
done
```

The CLI exits 1 when overall < 3.5, which is the intended outcome for
every pair here. D3's `scripts/eval.sh` will turn each pair's expected
verdict into a row of the confusion matrix:

- pair from `passing/` + verdict ≥ 3.5 → true positive
- pair from `passing/` + verdict < 3.5 → false negative
- pair from `failing/` + verdict < 3.5 → true negative
- pair from `failing/` + verdict ≥ 3.5 → false positive

Last verified: 2026-05-22 — 20/20 pairs score < 3.5.
