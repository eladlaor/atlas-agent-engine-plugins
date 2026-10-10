#!/usr/bin/env bash
#
# session-notice.sh — SessionStart hook for the aae plugin.
#
# Reads the state written by aae-docs-watch.sh and, if AAE documentation has
# changed since you last saw a notice, surfaces it both to the user
# (systemMessage) and to Claude (hookSpecificOutput.additionalContext). When the
# opt-in --update-kb run already applied that change to the knowledge base, the
# notice says so and carries the update's summary (kb-update.md).
#
# This hook does NO network work by default: SessionStart hooks delay Claude's
# first reply, so the crawl belongs in the scheduled job, not here. Set
# AAE_WATCH_ON_SESSION=quick to allow a ~1s inventory-only check when state is
# stale.
#
# It also says when the watcher itself is broken: a failed run (last-error), a
# failed knowledge-base update (kb-update-error), or no successful full crawl for
# longer than AAE_WATCH_BROKEN_HOURS while the daily schedule is installed.
# Otherwise a dead watcher would look exactly like "no changes". That notice is
# shown at most once per day.
#
# Always exits 0. A watcher problem must never block a session.

set -uo pipefail

# The --update-kb runner is itself a Claude Code or Codex session. It sets this so
# the hook inside it does not mark the user's pending notice as shown.
[ -n "${AAE_WATCH_NO_SESSION_NOTICE:-}" ] && exit 0

STATE_DIR="${AAE_WATCH_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/aae-docs-watch}"
readonly STATE_DIR
readonly REPORT_FILE="${STATE_DIR}/report.json"
readonly ACK_FILE="${STATE_DIR}/acknowledged"
readonly STALE_HOURS="${AAE_WATCH_STALE_HOURS:-24}"
readonly MAX_LISTED=12
readonly LAST_ERROR_FILE="${STATE_DIR}/last-error"
readonly LAST_FULL_RUN_FILE="${STATE_DIR}/last-full-run"
readonly HEALTH_ACK_FILE="${STATE_DIR}/health-acknowledged"
readonly KB_SUMMARY_FILE="${STATE_DIR}/kb-update.md"
readonly KB_ERROR_FILE="${STATE_DIR}/kb-update-error"
readonly BROKEN_HOURS="${AAE_WATCH_BROKEN_HOURS:-30}"
readonly SCHEDULE_PLIST="${HOME}/Library/LaunchAgents/com.eladlaor.aae-docs-watch.plist"

emit() {
  # $1 = systemMessage, $2 = additionalContext
  python3 - "$1" "$2" <<'PY'
import json, sys
print(json.dumps({
    "systemMessage": sys.argv[1],
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": sys.argv[2],
    },
}))
PY
}

# Optional cheap refresh when the state is stale.
if [ "${AAE_WATCH_ON_SESSION:-}" = "quick" ]; then
  watcher="$(dirname "$0")/aae-docs-watch.sh"
  if [ -x "$watcher" ]; then
    needs_run=1
    if [ -f "$REPORT_FILE" ]; then
      age=$(( $(date +%s) - $(stat -f %m "$REPORT_FILE" 2>/dev/null || echo 0) ))
      [ "$age" -lt $(( STALE_HOURS * 3600 )) ] && needs_run=0
    fi
    [ "$needs_run" -eq 1 ] && AAE_WATCH_QUIET=1 "$watcher" --quick >/dev/null 2>&1
  fi
fi

# ---------------------------------------------------------------------------
# Part 1: watcher health, at most once a day.
# ---------------------------------------------------------------------------
HEALTH_SYS=""
HEALTH_CTX=""
today="$(date '+%Y-%m-%d')"
if [ "$(cat "$HEALTH_ACK_FILE" 2>/dev/null)" != "$today" ]; then
  problem=""
  if [ -f "$LAST_ERROR_FILE" ]; then
    problem="the last check failed: $(cut -f2- "$LAST_ERROR_FILE" 2>/dev/null) (at $(cut -f1 "$LAST_ERROR_FILE" 2>/dev/null))"
  elif [ -f "$SCHEDULE_PLIST" ]; then
    if [ -f "$LAST_FULL_RUN_FILE" ]; then
      age=$(( $(date +%s) - $(stat -f %m "$LAST_FULL_RUN_FILE" 2>/dev/null || echo 0) ))
      [ "$age" -gt $(( BROKEN_HOURS * 3600 )) ] && problem="no successful check for $(( age / 3600 ))h although the daily schedule is installed"
    else
      problem="the daily schedule is installed but no check has completed yet"
    fi
  fi
  if [ -n "$problem" ]; then
    last_ok="$(cat "$LAST_FULL_RUN_FILE" 2>/dev/null || echo never)"
    HEALTH_SYS="AAE docs watcher: ${problem}. Last good check: ${last_ok}. Run /aae-docs-watch, or see ~/Library/Logs/aae-docs-watch/err.log."
    HEALTH_CTX="The aae-docs-watch change detector is not working: ${problem}. The last successful documentation check was ${last_ok}, so changes since then are unknown. Do not treat the absence of a docs-change notice as evidence that the AAE docs are unchanged; verify AAE API details against the live docs."
  fi
  if [ -f "$KB_ERROR_FILE" ]; then
    kb_problem="$(cut -f2- "$KB_ERROR_FILE" 2>/dev/null) (at $(cut -f1 "$KB_ERROR_FILE" 2>/dev/null))"
    HEALTH_SYS="${HEALTH_SYS:+${HEALTH_SYS} }AAE docs watcher: the automatic knowledge-base update failed: ${kb_problem}. Retry with aae-docs-watch.sh --kb-update-only, or run the aae-kb-update skill in docs mode."
    HEALTH_CTX="${HEALTH_CTX:+${HEALTH_CTX}
}The opt-in automatic knowledge-base update did not complete: ${kb_problem}. The docs changes in the watcher's report have not been applied to the aae-kb-read knowledge base or the personal notes; do not assume they were."
  fi
fi

# ---------------------------------------------------------------------------
# Part 2: the pending changes report, once per report.
# ---------------------------------------------------------------------------
CHANGES_SYS=""
CHANGES_CTX=""
if [ -f "$REPORT_FILE" ] && [ ! -f "$ACK_FILE" ]; then
  notice="$(python3 - "$REPORT_FILE" "$MAX_LISTED" "$STALE_HOURS" "$KB_SUMMARY_FILE" <<'PY' 2>/dev/null
import json, os, sys, time

report_path, max_listed, stale_hours, kb_path = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
with open(report_path) as fh:
    rep = json.load(fh)

if rep.get("status") != "changes":
    sys.exit(1)

added, removed, changed = (rep.get(k, []) for k in ("added", "removed", "changed"))

def short(url):
    return url.split("/docs/agentengine/", 1)[-1]

parts = []
for label, items in (("changed", changed), ("new", added), ("removed", removed)):
    if items:
        parts.append(f"{len(items)} {label}")
summary = ", ".join(parts) or "no changes"

age_h = (time.time() - os.path.getmtime(report_path)) / 3600
stale = f" (checked {age_h:.0f}h ago)" if age_h > stale_hours else ""

# The opt-in --update-kb run writes kb-update.md after report.json; only a summary
# newer than the current report belongs to it.
kb_text = ""
if os.path.isfile(kb_path) and os.path.getmtime(kb_path) > os.path.getmtime(report_path):
    with open(kb_path) as fh:
        kb_text = fh.read().strip()
kb_first = kb_text.splitlines()[0].strip() if kb_text else ""

if kb_first:
    system_message = f"AAE docs: {summary}{stale}. Knowledge base updated: {kb_first}"
else:
    system_message = f"AAE docs: {summary}{stale}. Ask aae-guide, or run /aae-docs-watch for the diff."

lines = [
    "MongoDB Atlas Agent Engine documentation changed since the last check "
    f"(checked at {rep.get('checked_at', 'unknown')}, mode={rep.get('mode')}).",
    f"Summary: {summary} out of {rep.get('pages_total')} tracked pages.",
    "",
]
for label, items in (("Changed", changed), ("New", added), ("Removed", removed)):
    if not items:
        continue
    lines.append(f"{label}:")
    for url in items[:max_listed]:
        lines.append(f"  - {short(url)}")
    if len(items) > max_listed:
        lines.append(f"  - …and {len(items) - max_listed} more")
    lines.append("")
lines.append(
    "These pages are the authoritative source for this preview product. "
    "Before asserting AAE API details, re-read any changed page "
    "(append .md to the docs URL for clean markdown). "
    "Unified diffs for changed pages are in the watcher's diffs/ directory."
)
if kb_text:
    lines += [
        "",
        f"The knowledge base was already updated from this report ({kb_path}). Its summary:",
        "",
        kb_text[:6000],
    ]

json.dump({"system": system_message, "context": "\n".join(lines)}, sys.stdout)
PY
)"
  if [ -n "$notice" ]; then
    CHANGES_SYS="$(printf '%s' "$notice" | python3 -c 'import json,sys;print(json.load(sys.stdin)["system"])' 2>/dev/null)"
    CHANGES_CTX="$(printf '%s' "$notice" | python3 -c 'import json,sys;print(json.load(sys.stdin)["context"])' 2>/dev/null)"
  fi
fi

[ -n "${HEALTH_SYS}${CHANGES_SYS}" ] || exit 0

SYS="${HEALTH_SYS}"
[ -n "$CHANGES_SYS" ] && SYS="${SYS:+${SYS} }${CHANGES_SYS}"
CTX="${HEALTH_CTX}"
[ -n "$CHANGES_CTX" ] && CTX="${CTX:+${CTX}

}${CHANGES_CTX}"

emit "$SYS" "$CTX" || exit 0

# Mark shown so the same notice does not nag on every future session.
[ -n "$HEALTH_SYS" ] && printf '%s\n' "$today" > "$HEALTH_ACK_FILE"
[ -n "$CHANGES_SYS" ] && touch "$ACK_FILE"
exit 0
