#!/usr/bin/env bash
# eval.sh — run the python HeuristicVerifier across all D1/D2 fixture pairs
#           and emit a confusion matrix.
#
# Inputs:
#   evals/pairs/passing/*.outcome.json + *.report.json  (expected ≥ floor)
#   evals/pairs/failing/*.outcome.json + *.report.json  (expected < floor)
#
# Output:
#   evals/results/<UTC-date>.json    (overwritten if same-day re-run)
#
# Usage:
#   scripts/eval.sh                       # uses default floor 3.5
#   scripts/eval.sh --floor 4.0           # try a ratchet
#   scripts/eval.sh --python <path>       # override python binary
#   scripts/eval.sh --out <path>          # override output path

set -euo pipefail

FLOOR="3.5"
PYTHON="/Users/alexzh/subagentmcp/opensubagents/outcomes/sdk-python/.venv/bin/python"
DATE="$(date -u +%Y-%m-%d)"
OUT="evals/results/${DATE}.json"

while [ $# -gt 0 ]; do
  case "$1" in
    --floor)  FLOOR="$2";  shift 2 ;;
    --python) PYTHON="$2"; shift 2 ;;
    --out)    OUT="$2";    shift 2 ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//' | head -20
      exit 0 ;;
    *) echo "eval.sh: unknown arg $1" >&2; exit 2 ;;
  esac
done

mkdir -p "$(dirname "$OUT")"

score_pair() {
  local outcome="$1" report="$2"
  "$PYTHON" -m open_outcome.cli verify "$outcome" "$report" --floor "$FLOOR" 2>/dev/null || true
}

# Header
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "eval.sh: floor=$FLOOR date=$DATE ts=$TS" >&2

# Per-bucket scoring
TP=0; FN=0; TN=0; FP=0; PARSE_ERR=0
PASS_TOTAL=0; FAIL_TOTAL=0
PASS_DETAILS=""
FAIL_DETAILS=""

for o in evals/pairs/passing/*.outcome.json; do
  base="$(basename "$o" .outcome.json)"
  r="evals/pairs/passing/${base}.report.json"
  PASS_TOTAL=$((PASS_TOTAL+1))
  verdict="$(score_pair "$o" "$r")"
  overall="$(echo "$verdict" | python3 -c "import json,sys
try: print(json.load(sys.stdin)['overall'])
except: print('null')
" 2>/dev/null)"
  if [ "$overall" = "null" ] || [ -z "$overall" ]; then
    PARSE_ERR=$((PARSE_ERR+1))
    PASS_DETAILS+="{\"slug\":\"$base\",\"bucket\":\"passing\",\"overall\":null,\"verdict\":\"parse_error\"},"
    continue
  fi
  meets_floor="$(echo "$overall >= $FLOOR" | bc -l)"
  if [ "$meets_floor" = "1" ]; then
    TP=$((TP+1))
    PASS_DETAILS+="{\"slug\":\"$base\",\"bucket\":\"passing\",\"overall\":$overall,\"verdict\":\"true_positive\"},"
  else
    FN=$((FN+1))
    PASS_DETAILS+="{\"slug\":\"$base\",\"bucket\":\"passing\",\"overall\":$overall,\"verdict\":\"false_negative\"},"
  fi
done

for o in evals/pairs/failing/*.outcome.json; do
  base="$(basename "$o" .outcome.json)"
  r="evals/pairs/failing/${base}.report.json"
  FAIL_TOTAL=$((FAIL_TOTAL+1))
  verdict="$(score_pair "$o" "$r")"
  overall="$(echo "$verdict" | python3 -c "import json,sys
try: print(json.load(sys.stdin)['overall'])
except: print('null')
" 2>/dev/null)"
  if [ "$overall" = "null" ] || [ -z "$overall" ]; then
    PARSE_ERR=$((PARSE_ERR+1))
    FAIL_DETAILS+="{\"slug\":\"$base\",\"bucket\":\"failing\",\"overall\":null,\"verdict\":\"parse_error\"},"
    continue
  fi
  meets_floor="$(echo "$overall >= $FLOOR" | bc -l)"
  if [ "$meets_floor" = "1" ]; then
    FP=$((FP+1))
    FAIL_DETAILS+="{\"slug\":\"$base\",\"bucket\":\"failing\",\"overall\":$overall,\"verdict\":\"false_positive\"},"
  else
    TN=$((TN+1))
    FAIL_DETAILS+="{\"slug\":\"$base\",\"bucket\":\"failing\",\"overall\":$overall,\"verdict\":\"true_negative\"},"
  fi
done

TOTAL=$((PASS_TOTAL + FAIL_TOTAL))
CORRECT=$((TP + TN))
ACCURACY="$(echo "scale=3; $CORRECT / $TOTAL" | bc -l)"
PRECISION="$(if [ $((TP + FP)) -gt 0 ]; then echo "scale=3; $TP / ($TP + $FP)" | bc -l; else echo "null"; fi)"
RECALL="$(if [ $((TP + FN)) -gt 0 ]; then echo "scale=3; $TP / ($TP + $FN)" | bc -l; else echo "null"; fi)"

# Strip trailing comma from details
PASS_DETAILS="${PASS_DETAILS%,}"
FAIL_DETAILS="${FAIL_DETAILS%,}"

cat > "$OUT" <<EOF
{
  "as_of": "$TS",
  "date": "$DATE",
  "floor": $FLOOR,
  "verifier_id": "open-outcome.python.heuristic",
  "totals": {
    "pairs": $TOTAL,
    "passing_bucket": $PASS_TOTAL,
    "failing_bucket": $FAIL_TOTAL,
    "parse_errors": $PARSE_ERR
  },
  "confusion_matrix": {
    "true_positive": $TP,
    "false_negative": $FN,
    "true_negative": $TN,
    "false_positive": $FP
  },
  "metrics": {
    "accuracy": $ACCURACY,
    "precision": $PRECISION,
    "recall": $RECALL
  },
  "pairs": [$PASS_DETAILS,$FAIL_DETAILS]
}
EOF

echo "wrote: $OUT" >&2
echo "TP=$TP FN=$FN TN=$TN FP=$FP parse_err=$PARSE_ERR" >&2
echo "accuracy=$ACCURACY precision=$PRECISION recall=$RECALL" >&2

# Exit non-zero if any false positive or false negative — D3 calibration
# treats either failure mode as a regression signal.
if [ $FP -gt 0 ] || [ $FN -gt 0 ]; then
  exit 1
fi
