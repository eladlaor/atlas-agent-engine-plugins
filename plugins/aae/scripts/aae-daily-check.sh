#!/usr/bin/env bash
#
# aae-daily-check.sh — the scheduled job's entry point: the docs watcher, then the
# release check, then (opt-in) one knowledge-base update fed by both.
#
# WHY A SEPARATE ENTRY POINT
#
# The docs watcher only diffs the documentation repository. CLI and SDK releases
# are a second source with their own failure modes, so they live in their own
# script (aae-release-check.sh) rather than inside the watcher. This file runs the
# two in order and keeps them independent:
#
#   - each step carries its own --skip-if-ran-today marker, so an hourly retry
#     re-runs only the step that has not succeeded yet today;
#   - a failed release check never stops the docs watcher (it runs second) and
#     never changes the watcher's report; it writes release-check-error, which the
#     session notice names, exactly as a failed probe does;
#   - with --update-kb, ONE runner receives both inputs, so a day with docs
#     changes and a CLI release costs one AI run, not two. A runner failure is
#     recorded in kb-update-error and never changes this script's exit code.
#
# Exit codes: 0 = nothing new, 10 = docs changes or release drift found,
#             20 = both steps already ran today, 1 = a step failed.

set -euo pipefail

STATE_DIR="${AAE_WATCH_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/aae-docs-watch}"
readonly STATE_DIR
readonly REPORT_FILE="${STATE_DIR}/report.json"
readonly EXIT_FOUND=10
readonly EXIT_SKIPPED=20

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly RELEASE_CHECK="${AAE_DAILY_RELEASE_CHECK:-${SCRIPT_DIR}/aae-release-check.sh}"

WATCHER=""
UPDATE_KB=""
SKIP_FLAG="--skip-if-ran-today"

now() { date '+%Y-%m-%d %H:%M:%S %Z'; }

log() {
  [ -n "${AAE_WATCH_QUIET:-}" ] && return 0
  printf '%s  aae-daily-check: %s\n' "$(now)" "$*" >&2
  return 0
}

# Only argument and setup errors reach die(): a step's own failure is recorded by
# that step, in its own error file.
die() {
  printf '%s  aae-daily-check: ERROR: %s\n' "$(now)" "$*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage: aae-daily-check.sh --watcher PATH [--update-kb] [--force] [-h]

Runs the docs watcher (PATH --full --skip-if-ran-today), then
aae-release-check.sh --skip-if-ran-today, then, with --update-kb, one
knowledge-base update that receives both the docs changes and the release drift.

  --watcher PATH   The docs watcher to run (aae-docs-watch-git.sh, or the
                   scheduled copy install-schedule.sh made of it).
  --update-kb      After a step that found something, start the AI runner.
  --force          Run both steps even if they already ran today.
  -h, --help       This text.

Exit codes: 0 nothing new, 10 docs changes or release drift, 20 both skipped,
1 a step failed (its error is in last-error or release-check-error).
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --watcher)
      [ $# -ge 2 ] && [ -n "$2" ] || die "--watcher needs a path"
      WATCHER="$2"; shift ;;
    --update-kb) UPDATE_KB=1 ;;
    --force) SKIP_FLAG="" ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
  shift
done

[ -n "$WATCHER" ] || die "--watcher is required (try --help)"
[ -x "$WATCHER" ] || die "docs watcher not found or not executable: ${WATCHER}"
[ -x "$RELEASE_CHECK" ] || die "release check not found or not executable: ${RELEASE_CHECK}"
mkdir -p "$STATE_DIR" || die "cannot create state directory ${STATE_DIR}"
export AAE_WATCH_STATE_DIR="$STATE_DIR"

# Step 1: the docs. Never with --update-kb here: the update runs once, below.
docs_rc=0
"$WATCHER" --full ${SKIP_FLAG:+"$SKIP_FLAG"} || docs_rc=$?
log "docs watcher exited ${docs_rc}"

# Step 2: the releases. Runs whatever the docs step did.
release_rc=0
"$RELEASE_CHECK" ${SKIP_FLAG:+"$SKIP_FLAG"} || release_rc=$?
log "release check exited ${release_rc}"

# Step 3: one knowledge-base update for whatever either step found.
if [ -n "$UPDATE_KB" ] && { [ "$docs_rc" -eq "$EXIT_FOUND" ] || [ "$release_rc" -eq "$EXIT_FOUND" ]; }; then
  # The shared library expects the watcher's names and helpers.
  # shellcheck source=lib/kb-update.sh
  . "${SCRIPT_DIR}/lib/kb-update.sh"
  run_kb_update || true
fi

if [ "$docs_rc" -ne 0 ] && [ "$docs_rc" -ne "$EXIT_FOUND" ] && [ "$docs_rc" -ne "$EXIT_SKIPPED" ]; then
  exit 1
fi
if [ "$release_rc" -ne 0 ] && [ "$release_rc" -ne "$EXIT_FOUND" ] && [ "$release_rc" -ne "$EXIT_SKIPPED" ]; then
  exit 1
fi
if [ "$docs_rc" -eq "$EXIT_FOUND" ] || [ "$release_rc" -eq "$EXIT_FOUND" ]; then
  exit "$EXIT_FOUND"
fi
if [ "$docs_rc" -eq "$EXIT_SKIPPED" ] && [ "$release_rc" -eq "$EXIT_SKIPPED" ]; then
  exit "$EXIT_SKIPPED"
fi
exit 0
