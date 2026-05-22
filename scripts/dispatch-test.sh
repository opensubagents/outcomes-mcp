#!/usr/bin/env bash
# dispatch-test.sh — simulate each event in .claude/dispatch.json and assert
# the matrix selects the expected subagent. Pure local test; no network, no PR.
#
# Output: writes a log to outcomes/runrocs/E4-dispatch-test.log and exits
# non-zero on any mismatch.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DISPATCH="${ROOT}/.claude/dispatch.json"
LOG="${LOG:-${ROOT}/outcomes/runrocs/E4-dispatch-test.log}"

mkdir -p "$(dirname "$LOG")"

# Helper: pick the subagent for a synthetic event using jq. The matching rule
# is deliberately simple: walk events in declared order, return the first
# subagent whose matcher fields are all consistent with the event's fields.
# In production the heartbeat would consult a richer matcher; this is the
# minimal logic the test harness needs to exercise.
select_subagent() {
  local event_type="$1"
  local extra_json="$2"  # JSON object with the event-specific fields
  jq -r --arg et "$event_type" --argjson ev "$extra_json" '
    .events[]
    | select(.event == $et)
    | select(
        (.matcher.conclusion == null or .matcher.conclusion == $ev.conclusion) and
        (.matcher.draft == null or .matcher.draft == ($ev.draft // false)) and
        (.matcher.state == null or .matcher.state == ($ev.state // "open")) and
        (
          .matcher.workflow_name == null or
          .matcher.workflow_name == $ev.workflow_name
        ) and
        (
          .matcher.check_name_includes == null or
          (
            $ev.check_name != null and
            ([ .matcher.check_name_includes[] | select(. as $needle | $ev.check_name | contains($needle)) ] | length > 0)
          )
        ) and
        (
          .matcher.files_touched == null or
          (
            $ev.files != null and
            ([
              .matcher.files_touched[] as $pat
              | $ev.files[]
              | select(
                  ($pat | startswith("outcomes/") and endswith(".outcome.json") and (. | endswith(".outcome.json") and startswith("outcomes/")))
                  or ($pat | endswith(".report.json") and (. | endswith(".report.json") and startswith("outcomes/")))
                )
            ] | length > 0)
          )
        )
      )
    | .subagent
  ' "$DISPATCH" | head -1
}

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "PASS: $label → $actual" | tee -a "$LOG"
    return 0
  else
    echo "FAIL: $label expected=$expected actual=$actual" | tee -a "$LOG"
    return 1
  fi
}

{
  echo "=== dispatch-test.sh — $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
  echo "dispatch.json: $DISPATCH"
  echo ""
} > "$LOG"

PASS=0
FAIL=0

# Event 1: PR opened with an outcome+report pair → outcome-reviewer
EV1='{"state":"open","draft":false,"files":["outcomes/foo.outcome.json","outcomes/foo.report.json"]}'
ACTUAL=$(select_subagent "pull_request.opened" "$EV1")
if assert_eq "PR opened with pair" "outcome-reviewer" "$ACTUAL"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# Event 2: PR opened as draft → matcher requires draft=false → no match (empty)
EV2='{"state":"open","draft":true,"files":["outcomes/foo.outcome.json","outcomes/foo.report.json"]}'
ACTUAL=$(select_subagent "pull_request.opened" "$EV2")
if assert_eq "PR opened as draft" "" "$ACTUAL"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# Event 3: check_suite outcome-gate failed → ci-firefighter
EV3='{"conclusion":"failure","check_name":"outcome-gate"}'
ACTUAL=$(select_subagent "check_suite.completed" "$EV3")
if assert_eq "outcome-gate failure" "ci-firefighter" "$ACTUAL"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# Event 4: check_suite typecheck failed → ci-firefighter
EV4='{"conclusion":"failure","check_name":"typecheck"}'
ACTUAL=$(select_subagent "check_suite.completed" "$EV4")
if assert_eq "typecheck failure" "ci-firefighter" "$ACTUAL"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# Event 5: check_suite unrelated check failed → no match
EV5='{"conclusion":"failure","check_name":"some-other-check"}'
ACTUAL=$(select_subagent "check_suite.completed" "$EV5")
if assert_eq "unrelated check failure" "" "$ACTUAL"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# Event 6: check_suite success → no match (matcher requires failure)
EV6='{"conclusion":"success","check_name":"outcome-gate"}'
ACTUAL=$(select_subagent "check_suite.completed" "$EV6")
if assert_eq "outcome-gate success" "" "$ACTUAL"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# Event 7: eval-matrix workflow success → rubric-tightener
EV7='{"conclusion":"success","workflow_name":"eval-matrix"}'
ACTUAL=$(select_subagent "workflow_run.completed" "$EV7")
if assert_eq "eval-matrix success" "rubric-tightener" "$ACTUAL"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# Event 8: unrelated workflow success → no match
EV8='{"conclusion":"success","workflow_name":"some-other-workflow"}'
ACTUAL=$(select_subagent "workflow_run.completed" "$EV8")
if assert_eq "unrelated workflow success" "" "$ACTUAL"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# Event 9: unknown event type → no match
EV9='{}'
ACTUAL=$(select_subagent "pull_request.labeled" "$EV9")
if assert_eq "unknown event type" "" "$ACTUAL"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

echo "" | tee -a "$LOG"
echo "=== summary: $((PASS+FAIL)) tests, $PASS pass, $FAIL fail ===" | tee -a "$LOG"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
