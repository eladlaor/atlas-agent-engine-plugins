#!/usr/bin/env bash
#
# install-schedule.sh — manage the launchd job that runs the AAE docs watcher
# between Claude Code sessions.
#
# Claude Code plugins cannot declare cron or scheduled work, so the periodic
# full crawl runs from launchd and writes its result into the shared state
# directory. The SessionStart hook then surfaces it.
#
# launchd runs a copy of the watcher in a fixed location, not the script inside
# the plugin. The plugin lives in a versioned folder that a plugin update can
# delete, which would break the job silently. Re-run `install` after updating
# the plugin to refresh the copy; `status` says when it is out of date.
#
# The job fires at --hour:--minute and again every hour after it until 23:xx. The
# watcher runs with --skip-if-ran-today, so once one attempt succeeds the later ones
# exit at once without touching the network. A run that fails (for example, during a
# brief maintenance wake before the network is up) is retried an hour later instead
# of losing the day.
#
# With --update-kb, the job also passes --update-kb to the watcher: a run that finds
# changes then starts an AI runner (claude or codex) to apply them to the knowledge
# base. AAE_KB_REPO, AAE_KB_RUNNER, AAE_KB_NOTES, AAE_KB_MAX_USD and AAE_KB_MODEL, when set at
# install time, are stored in the job's environment. install also copies the
# aae-kb-update SKILL.md next to the watcher copy, for the same reason as the watcher.
#
# print-plist writes the plist to stdout and changes nothing, for review and tests.
#
# Usage: install-schedule.sh {install|uninstall|status|run|print-plist}
#                            [--hour N] [--minute N] [--update-kb]

set -euo pipefail

readonly LABEL="com.eladlaor.aae-docs-watch"
readonly PLIST="${HOME}/Library/LaunchAgents/${LABEL}.plist"
readonly LOG_DIR="${HOME}/Library/Logs/aae-docs-watch"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WATCHER="${SCRIPT_DIR}/aae-docs-watch.sh"
readonly STATE_DIR="${AAE_WATCH_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/aae-docs-watch}"
readonly BIN_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/aae-docs-watch/bin"
readonly SCHEDULED_WATCHER="${BIN_DIR}/aae-docs-watch.sh"
readonly KB_SKILL="${SCRIPT_DIR}/../skills/aae-kb-update/SKILL.md"
readonly SCHEDULED_KB_SKILL="${BIN_DIR}/aae-kb-update.SKILL.md"
# launchd starts jobs with a minimal PATH. ~/.local/bin is where the claude CLI installs.
readonly JOB_PATH="${HOME}/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin"
# Knowledge-base settings carried into the job's environment when set at install time.
readonly KB_ENV_VARS="AAE_KB_REPO AAE_KB_RUNNER AAE_KB_NOTES AAE_KB_MAX_USD AAE_KB_MODEL"
readonly KB_REFERENCES_SUBPATH="plugins/aae/skills/aae-kb-read/references"

HOUR=10
MINUTE=0
UPDATE_KB=""
ACTION="${1:-}"
[ $# -gt 0 ] && shift

die() { printf 'install-schedule: ERROR: %s\n' "$1" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --hour)   HOUR="${2:?--hour needs a value}"; shift 2 ;;
    --minute) MINUTE="${2:?--minute needs a value}"; shift 2 ;;
    --update-kb) UPDATE_KB="1"; shift ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ "$(uname -s)" = "Darwin" ] || die "launchd scheduling is macOS-only; on Linux use a cron entry calling ${WATCHER} --full"
[ -x "$WATCHER" ] || die "watcher not found or not executable: ${WATCHER}"
case "$HOUR" in ''|*[!0-9]*) die "--hour must be 0-23" ;; esac
case "$MINUTE" in ''|*[!0-9]*) die "--minute must be 0-59" ;; esac
[ "$HOUR" -le 23 ] || die "--hour must be 0-23"
[ "$MINUTE" -le 59 ] || die "--minute must be 0-59"
[ -f "$KB_SKILL" ] || die "aae-kb-update skill not found next to the watcher: ${KB_SKILL}"

# Escape a value for an XML text node.
xml_escape() {
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

# With --update-kb, fail now rather than at the first change: check the repo clone
# and that a runner is reachable on the job's PATH.
check_kb_settings() {
  [ -n "$UPDATE_KB" ] || return 0
  if [ -n "${AAE_KB_REPO:-}" ]; then
    case "$AAE_KB_REPO" in /*) ;; *) die "AAE_KB_REPO must be an absolute path: ${AAE_KB_REPO}" ;; esac
    [ -d "${AAE_KB_REPO}/${KB_REFERENCES_SUBPATH}" ] && [ -e "${AAE_KB_REPO}/.git" ] \
      || die "AAE_KB_REPO is not a git clone of the plugin repository (needs .git and ${KB_REFERENCES_SUBPATH}): ${AAE_KB_REPO}"
  fi
  case "${AAE_KB_RUNNER:-}" in
    claude|codex)
      PATH="$JOB_PATH" command -v "$AAE_KB_RUNNER" >/dev/null 2>&1 \
        || die "AAE_KB_RUNNER=${AAE_KB_RUNNER} is not on the job's PATH (${JOB_PATH})" ;;
    "")
      PATH="$JOB_PATH" command -v claude >/dev/null 2>&1 || PATH="$JOB_PATH" command -v codex >/dev/null 2>&1 \
        || die "--update-kb needs claude or codex on the job's PATH (${JOB_PATH})" ;;
    *) die "AAE_KB_RUNNER must be claude or codex, got: ${AAE_KB_RUNNER}" ;;
  esac
}

# One <dict> per attempt: the main time, then hourly catch-ups until the end of the day.
calendar_entries() {
  local h
  for (( h = HOUR; h <= 23; h++ )); do
    printf '        <dict>\n            <key>Hour</key>\n            <integer>%d</integer>\n            <key>Minute</key>\n            <integer>%d</integer>\n        </dict>\n' "$h" "$MINUTE"
  done
}

# The job's plist, on stdout. Owned solely by this plugin; install writes it fresh.
render_plist() {
  local var
  cat <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>$(xml_escape "$SCHEDULED_WATCHER")</string>
        <string>--full</string>
        <string>--skip-if-ran-today</string>
PLISTEOF
  [ -n "$UPDATE_KB" ] && printf '        <string>--update-kb</string>\n'
  cat <<PLISTEOF
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>AAE_WATCH_STATE_DIR</key>
        <string>$(xml_escape "$STATE_DIR")</string>
        <key>PATH</key>
        <string>$(xml_escape "$JOB_PATH")</string>
PLISTEOF
  if [ -n "$UPDATE_KB" ]; then
    for var in $KB_ENV_VARS; do
      [ -n "${!var:-}" ] || continue
      printf '        <key>%s</key>\n        <string>%s</string>\n' "$var" "$(xml_escape "${!var}")"
    done
  fi
  cat <<PLISTEOF
    </dict>
    <key>StartCalendarInterval</key>
    <array>
$(calendar_entries)
    </array>
    <key>RunAtLoad</key>
    <false/>
    <key>StandardOutPath</key>
    <string>$(xml_escape "${LOG_DIR}/out.log")</string>
    <key>StandardErrorPath</key>
    <string>$(xml_escape "${LOG_DIR}/err.log")</string>
</dict>
</plist>
PLISTEOF
}

do_install() {
  check_kb_settings
  mkdir -p "$(dirname "$PLIST")" "$LOG_DIR" "$STATE_DIR" "$BIN_DIR"
  install -m 0755 "$WATCHER" "$SCHEDULED_WATCHER" \
    || die "cannot copy the watcher to ${SCHEDULED_WATCHER}"
  install -m 0644 "$KB_SKILL" "$SCHEDULED_KB_SKILL" \
    || die "cannot copy the aae-kb-update skill to ${SCHEDULED_KB_SKILL}"

  render_plist > "$PLIST" || die "cannot write ${PLIST}"

  launchctl bootout "gui/$(id -u)/${LABEL}" >/dev/null 2>&1 || true
  launchctl bootstrap "gui/$(id -u)" "$PLIST" \
    || die "launchctl bootstrap failed; check ${PLIST}"
  printf 'Installed %s — runs daily at %02d:%02d, retrying hourly until it succeeds that day\n' "$LABEL" "$HOUR" "$MINUTE"
  printf 'Watcher copy: %s\nSkill copy:   %s\nState: %s\nLogs:  %s\n' "$SCHEDULED_WATCHER" "$SCHEDULED_KB_SKILL" "$STATE_DIR" "$LOG_DIR"
  if [ -n "$UPDATE_KB" ]; then
    printf 'Knowledge-base update: ON (runner: %s; repo clone: %s)\n' \
      "${AAE_KB_RUNNER:-claude if on PATH, else codex}" "${AAE_KB_REPO:-none, updates go to your notes}"
  else
    printf 'Knowledge-base update: off (notify only). Re-run with --update-kb to turn it on.\n'
  fi
}

do_uninstall() {
  launchctl bootout "gui/$(id -u)/${LABEL}" >/dev/null 2>&1 || true
  if [ -f "$PLIST" ]; then
    rm -f "$PLIST"
    printf 'Removed %s\n' "$PLIST"
  else
    printf 'Not installed (no %s)\n' "$PLIST"
  fi
  local copy
  for copy in "$SCHEDULED_WATCHER" "$SCHEDULED_KB_SKILL"; do
    if [ -f "$copy" ]; then
      rm -f "$copy"
      printf 'Removed %s\n' "$copy"
    fi
  done
  printf 'State left in place: %s\n' "$STATE_DIR"
}

do_status() {
  if [ -f "$PLIST" ]; then
    printf 'plist:  %s\n' "$PLIST"
  else
    printf 'plist:  not installed\n'
  fi
  if launchctl print "gui/$(id -u)/${LABEL}" >/dev/null 2>&1; then
    printf 'loaded: yes\n'
  else
    printf 'loaded: no\n'
  fi
  if [ -f "$SCHEDULED_WATCHER" ]; then
    if cmp -s "$WATCHER" "$SCHEDULED_WATCHER"; then
      printf 'watcher copy: current (%s)\n' "$SCHEDULED_WATCHER"
    else
      printf 'watcher copy: OUT OF DATE, differs from this plugin version; re-run install\n'
    fi
  elif [ -f "$PLIST" ]; then
    printf 'watcher copy: MISSING (%s); re-run install\n' "$SCHEDULED_WATCHER"
  fi
  if [ -f "$SCHEDULED_KB_SKILL" ]; then
    if cmp -s "$KB_SKILL" "$SCHEDULED_KB_SKILL"; then
      printf 'kb-update skill copy: current (%s)\n' "$SCHEDULED_KB_SKILL"
    else
      printf 'kb-update skill copy: OUT OF DATE, differs from this plugin version; re-run install\n'
    fi
  elif [ -f "$PLIST" ]; then
    printf 'kb-update skill copy: MISSING (%s); re-run install\n' "$SCHEDULED_KB_SKILL"
  fi
  if [ -f "$PLIST" ]; then
    if grep -q -- '<string>--update-kb</string>' "$PLIST"; then
      printf 'knowledge-base update: ON\n'
    else
      printf 'knowledge-base update: off (notify only)\n'
    fi
  fi
  if [ -f "${STATE_DIR}/last-full-run" ]; then
    printf 'last full run: %s\n' "$(cat "${STATE_DIR}/last-full-run")"
  fi
  if [ -f "${STATE_DIR}/last-error" ]; then
    printf 'LAST ERROR: %s\n' "$(tr '\t' ' ' < "${STATE_DIR}/last-error")"
  fi
  if [ -f "${STATE_DIR}/kb-update-error" ]; then
    printf 'KB UPDATE ERROR: %s\n' "$(tr '\t' ' ' < "${STATE_DIR}/kb-update-error")"
  fi
  if [ -f "${STATE_DIR}/kb-update.md" ]; then
    printf 'last kb update: %s — %s\n' "$(stat -f '%Sm' "${STATE_DIR}/kb-update.md")" "$(head -1 "${STATE_DIR}/kb-update.md")"
  fi
  if [ -f "${STATE_DIR}/report.json" ]; then
    printf 'last report: %s\n' "$(stat -f '%Sm' "${STATE_DIR}/report.json")"
    python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print("status:",d["status"],d["counts"])' \
      "${STATE_DIR}/report.json" 2>/dev/null || true
  else
    printf 'last report: none (watcher has not run yet)\n'
  fi
}

case "$ACTION" in
  install)   do_install ;;
  uninstall) do_uninstall ;;
  status)    do_status ;;
  run)       AAE_WATCH_STATE_DIR="$STATE_DIR" "$WATCHER" --full ${UPDATE_KB:+--update-kb} ;;
  print-plist) check_kb_settings; render_plist ;;
  *) die "usage: install-schedule.sh {install|uninstall|status|run|print-plist} [--hour N] [--minute N] [--update-kb]" ;;
esac
