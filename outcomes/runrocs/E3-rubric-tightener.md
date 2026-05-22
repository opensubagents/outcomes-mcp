# E3 — Rubric Tightener runroc

**As of:** 2026-05-22
**Source matrix:** `evals/results/2026-05-22.json` (verifier_id `open-outcome.python.heuristic`, floor 3.5)

## Verdict

`no_tightening_needed`

## Matrix summary

| Cell | Count |
|------|-------|
| TP   | 20    |
| FN   | 0     |
| TN   | 20    |
| FP   | 0     |

Accuracy = precision = recall = 1.000. Total FP+FN = 0; no dimension has any error to attribute. Passing-bucket min = 4.4 (`spec-bootstrap-v010`); failing-bucket max = 3.4 (`a1-clarity-one-sentence`, `e1-decision-no-signals`, `f3-combined-mixed-bad`). The 3.5–4.4 band is empty.

## Rationale

ADR 0001 explicitly anticipates this state and instructs against tightening on it: "Anyone reading this matrix in isolation will conclude the rubric is 'perfect'. It is perfect *on a curated set designed to be perfectly classified*. The metrics ... are true and uninformative simultaneously." The role spec biases me toward threshold tightening, a new signal, or a corner-case fix — but every one of those needs error evidence the matrix does not supply, and the ADR pins the real test to D5 (citation staleness) and D6 (URL liveness) which will asymmetrically flip a known-passing fixture into the 3.5–4.4 calibration blind spot. Tightening now would freeze the rubric before that shoulder exists and would be the "false confidence" failure mode the ADR names by name.

## What I would do next if invoked again with a non-perfect matrix

Pick the single dimension with the largest combined FP+FN, read its scoring function in `outcomes/sdk-python/open_outcome/verifier.py` (canonical) and the two ports, and propose one ports-stable change — threshold tightening, one new deterministic signal, or a corner-case fix — with the FP/FN counts that motivated it cited in the PR body. If the first non-zero entry instead lands a fixture in the 3.5–4.4 blind spot, investigate that pair before touching the rubric, per ADR 0001's "investigate, do not blindly add to fixtures" instruction.
