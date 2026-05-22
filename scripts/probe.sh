#!/usr/bin/env bash
# probe.sh — fire-drill the outcome-gate.
#
# Subcommands:
#   below-floor   Opens a draft PR with a deliberately weak outcome+report
#                 pair (overall ~2.2), watches the gate fail, captures the
#                 conclusion, then closes the PR + deletes the branch.
#   orphan        Opens a draft PR with only an outcome.json (no report),
#                 asserts the gate fails at the pairing step.
#   empty         Opens a draft PR with a README touch and no outcomes/* file,
#                 asserts the gate fails with "empty pair set".
#
# Usage:
#   scripts/probe.sh below-floor [--repo opensubagents/outcomes-mcp] [--keep]
#
# Defaults: --repo opensubagents/outcomes-mcp. Without --keep, the probe PR
# is closed and the branch is deleted at the end (the gate's red status is
# what matters; we don't merge probes).

set -euo pipefail

MODE=""
REPO="opensubagents/outcomes-mcp"
KEEP=0
LOG="${LOG:-outcomes/runrocs/B4-probe.log}"

while [ $# -gt 0 ]; do
  case "$1" in
    below-floor|orphan|empty) MODE="$1"; shift ;;
    --repo) REPO="$2"; shift 2 ;;
    --keep) KEEP=1; shift ;;
    --log)  LOG="$2"; shift 2 ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//' | head -25
      exit 0 ;;
    *) echo "probe.sh: unknown arg $1" >&2; exit 2 ;;
  esac
done

if [ -z "$MODE" ]; then
  echo "probe.sh: missing mode (below-floor | orphan | empty)" >&2
  exit 2
fi

mkdir -p "$(dirname "$LOG")"

TS=$(date '+%Y%m%dT%H%M%SZ')
SLUG="probe-${MODE}-${TS}"
BRANCH="claude/probe/${SLUG}"

cleanup() {
  if [ "$KEEP" -eq 0 ] && [ -n "${PR_NUM:-}" ]; then
    gh pr close "$PR_NUM" --repo "$REPO" --delete-branch \
      --comment "probe.sh: drill complete (mode=${MODE})" >/dev/null 2>&1 || true
  fi
  # always return to main
  git checkout main >/dev/null 2>&1 || true
}
trap cleanup EXIT

{
  echo "=== probe.sh ${MODE} — ${TS} ==="
  echo "repo: $REPO"
  echo "slug: $SLUG"
} | tee -a "$LOG"

git fetch origin main >/dev/null
git checkout -b "$BRANCH" origin/main >/dev/null

case "$MODE" in
  below-floor)
    mkdir -p outcomes
    cat > "outcomes/${SLUG}.outcome.json" <<EOF
{
  "title": "Probe — below-floor scoring fire drill",
  "as_of": "$(date '+%Y-%m-%d')",
  "question": "Will outcome-gate correctly reject a pair whose verdict overall is below 3.5?",
  "success_criteria": ["submarine periscope deployment unequivocally"]
}
EOF
    cat > "outcomes/${SLUG}.report.json" <<EOF
{
  "summary": "Stuff happened.",
  "claims": [{
    "statement": "Mumble mumble.",
    "confidence": "low",
    "citations": [{
      "url": "https://example.com/forum/post/42",
      "title": "random forum post",
      "accessed": "$(date '+%Y-%m-%d')",
      "kind": "community"
    }]
  }]
}
EOF
    git add "outcomes/${SLUG}.outcome.json" "outcomes/${SLUG}.report.json"
    ;;
  orphan)
    mkdir -p outcomes
    cat > "outcomes/${SLUG}.outcome.json" <<EOF
{
  "title": "Probe — orphan outcome (no report)",
  "as_of": "$(date '+%Y-%m-%d')",
  "question": "Will outcome-gate reject an outcome with no matching report?",
  "success_criteria": ["the gate must reject orphan pairs"]
}
EOF
    git add "outcomes/${SLUG}.outcome.json"
    ;;
  empty)
    echo "" >> README.md
    git add README.md
    ;;
esac

git -c user.email="alex@jadecli.com" -c user.name="alex-jadecli" \
  commit -s -m "probe (drill): ${MODE} — expects gate red" >/dev/null

git push -u origin "$BRANCH" >/dev/null 2>&1

PR_NUM=$(gh pr create --repo "$REPO" --draft \
  --title "probe (drill): ${MODE}" \
  --body "Fire drill from scripts/probe.sh ${MODE}. Expects outcome-gate to fail." \
  | grep -oE '[0-9]+$')
echo "PR #$PR_NUM opened (draft)" | tee -a "$LOG"

# Wait for the gate to conclude (max ~90s).
DEADLINE=$(( $(date +%s) + 90 ))
GATE_CONCLUSION=""
while [ "$(date +%s)" -lt "$DEADLINE" ]; do
  GATE_CONCLUSION=$(gh pr checks "$PR_NUM" --repo "$REPO" --json name,conclusion,status 2>/dev/null | \
    python3 -c "
import json, sys
d = json.load(sys.stdin)
for c in d:
    if c['name'] == 'outcome-gate':
        print(c.get('conclusion') or '')
        break
" 2>/dev/null) || GATE_CONCLUSION=""
  if [ -n "$GATE_CONCLUSION" ] && [ "$GATE_CONCLUSION" != "null" ]; then
    break
  fi
  sleep 5
done

echo "outcome-gate conclusion: ${GATE_CONCLUSION}" | tee -a "$LOG"

if [ "$GATE_CONCLUSION" = "FAILURE" ]; then
  echo "PASS: gate correctly blocked the probe (mode=${MODE})" | tee -a "$LOG"
  EXIT=0
elif [ "$GATE_CONCLUSION" = "SUCCESS" ]; then
  echo "FAIL: gate let the probe through — this is a regression (mode=${MODE})" | tee -a "$LOG"
  EXIT=1
else
  echo "UNDETERMINED: gate did not conclude within 90s (mode=${MODE}, last=${GATE_CONCLUSION})" | tee -a "$LOG"
  EXIT=2
fi

echo "" | tee -a "$LOG"
exit "$EXIT"
