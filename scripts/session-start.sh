#!/usr/bin/env bash
# SessionStart hook for outcomes-mcp.
#
# Contract:
#   - Returns in <100ms (background-dispatch + sentinel guard).
#   - matcher: "startup" only — resume is free.
#   - Never blocks the prompt. All real work goes to a forked child.
#   - The child writes a one-screen orientation to /tmp/outcomes-mcp-session.txt
#     that the operator (or Claude) can `cat` if useful.
#
# DO NOT add apt-get installs, dockerd starts, postgres waits, or plugin
# installs here. Those belong in `wrangler` workflows / CI, not in
# session start. See git history for why (reverted SessionStart hook).

set -u

SENTINEL="/tmp/outcomes-mcp-session-init-$$.done"
LOG="/tmp/outcomes-mcp-session.txt"

# Sentinel guard: if we already ran this session, skip. Per-PID so resume
# in the same shell skips, but a brand-new session re-runs.
if [ -f "$SENTINEL" ]; then
  exit 0
fi

# Background dispatch: fork, detach, return immediately.
(
  touch "$SENTINEL"
  {
    printf '# outcomes-mcp orientation — %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    if [ -d "${CLAUDE_PROJECT_DIR:-.}/.git" ]; then
      cd "${CLAUDE_PROJECT_DIR:-.}"
      printf 'branch: %s\n' "$(git branch --show-current)"
      printf 'last commit: %s\n\n' "$(git log -1 --oneline)"
      printf '## queue summary\n'
      grep -E '^\| [A-F][0-9]+' outcomes/QUEUE.md 2>/dev/null | awk -F'|' '{print $2, $3}' | sed 's/^ *//' | sort -u | uniq -c | awk '{print "  " $2 ": " $1 " row(s) " $3}'
    fi
    printf '\n(written by .claude/session-start.sh; safe to ignore)\n'
  } > "$LOG" 2>&1
) >/dev/null 2>&1 &
disown 2>/dev/null || true

exit 0
