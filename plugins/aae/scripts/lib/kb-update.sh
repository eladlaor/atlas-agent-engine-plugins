#!/usr/bin/env bash
#
# kb-update.sh — the opt-in knowledge-base update (--update-kb), shared by both
# docs detectors.
#
# The runner gets up to two inputs, each applied once: the docs watcher's changes
# report (report.json, keyed by its checked_at) and the release check's drift report
# (release-report.json plus release-notes.md, keyed by release:<drift_key>). Both are
# already in the state directory, so the runner's reach does not grow.
#
# Sourced, never executed (by both docs detectors and by aae-daily-check.sh). It
# expects the sourcing script to have already
# defined STATE_DIR, SCRIPT_DIR, REPORT_FILE and the helpers now(), log() and
# die(), and to declare the UPDATE_KB / KB_UPDATE_ONLY flags itself.
#
# The guarantee this file exists to protect: a failure in here NEVER changes
# the crawl's own exit code. Every failure path goes through kb_fail, which
# records kb-update-error and returns 1 without exiting, so a docs change that
# was detected stays detected even when updating the knowledge base from it
# fails.

# Knowledge-base update (--update-kb). The runner writes kb-update.md (its summary)
# and appends the report's checked_at to kb-update-processed; this script writes
# kb-update-error on failure and the runner's full output to kb-update-runner.log.
readonly KB_SUMMARY_FILE="${STATE_DIR}/kb-update.md"
readonly KB_PROCESSED_FILE="${STATE_DIR}/kb-update-processed"
readonly KB_ERROR_FILE="${STATE_DIR}/kb-update-error"
readonly KB_RUNNER_LOG="${STATE_DIR}/kb-update-runner.log"
readonly KB_LAST_MESSAGE_FILE="${STATE_DIR}/kb-update-last-message.txt"
# Staging. The unattended runner reads external docs text, so it must not get unconfined
# edit rights (prompt injection). Claude Code protects ~/.claude/, where the notes live, so
# a scoped grant can't reach them. Hence the runner reads and writes only the state
# directory and the repo clone: its inputs are copied in here, and its notes updates come
# back out through notes-pending.md, which this script (no AI) appends to the notes.
readonly KB_NOTES_BACKUP="${STATE_DIR}/kb-update-notes-before.md"  # notes snapshot and backup
readonly KB_NOTES_PENDING="${STATE_DIR}/notes-pending.md"
readonly KB_SKILL_STAGED="${STATE_DIR}/kb-update-skill.md"
readonly KB_BASELINE_STAGED="${STATE_DIR}/kb-baseline"   # read-only KB copy, used without a clone
readonly KB_SKILL_COPY_NAME="aae-kb-update.SKILL.md"
readonly KB_TIMEOUT_SECONDS="${AAE_KB_TIMEOUT_SECONDS:-900}"
readonly KB_MAX_USD="${AAE_KB_MAX_USD:-2}"
# Model for the claude runner. Applying a docs diff is a bounded editing task; a
# smaller model keeps a typical run well under the spending cap.
readonly KB_MODEL="${AAE_KB_MODEL:-sonnet}"
readonly KB_NOTES="${AAE_KB_NOTES:-$HOME/.claude/agent-memory/aae-guide/MEMORY.md}"
readonly KB_REFERENCES_SUBPATH="plugins/aae/skills/aae-kb-read/references"
# The claude runner's safety model: only these tools exist in the session (--tools; no
# shell, no web), acceptEdits auto-approves edits only inside its working directories
# (the state directory and the repo clone), and --permission-prompts none denies
# everything else, reads included, since nobody is there to answer a prompt.
readonly CLAUDE_TOOLS="Read,Edit,Write,Glob,Grep"

# ---------------------------------------------------------------------------
# Knowledge-base update (opt-in). Every failure here goes through kb_fail, which
# records kb-update-error and returns 1; it never exits the script, so the crawl's
# outcome stands.
# ---------------------------------------------------------------------------
kb_fail() {
  printf '%s aae-docs-watch: kb-update FAILED: %s\n' "$(now)" "$1" >&2
  printf '%s\t%s\n' "$(now)" "$1" > "$KB_ERROR_FILE" 2>/dev/null || true
  return 1
}

# The release check's output (aae-release-check.sh), the runner's second input.
readonly KB_RELEASE_REPORT="${STATE_DIR}/release-report.json"
readonly KB_RELEASE_NOTES="${STATE_DIR}/release-notes.md"
# A release report is recorded in kb-update-processed under this prefix, so its
# checked_at can never be mistaken for a docs report's.
readonly KB_RELEASE_KEY_PREFIX="release:"
readonly KB_STAMP_SUBPATH="plugins/aae/skills/aae-kb-read/kb-versions.json"

# Print a one-line JSON file's checked_at, or nothing. Defaults to report.json.
report_checked_at() {
  sed -n 's/.*"checked_at":"\([^"]*\)".*/\1/p' "${1:-$REPORT_FILE}" 2>/dev/null | head -1
}

# Exact match on the first field, so a release key never matches a docs key.
# Whitespace-separated rather than tab-only: the runner writes this line with an
# editing tool, and a tab that became spaces must not re-apply a report.
kb_already_processed() {
  [ -f "$KB_PROCESSED_FILE" ] && awk -v k="$1" '$1 == k { found = 1 } END { exit !found }' "$KB_PROCESSED_FILE"
}

# Resolve the aae-kb-update SKILL.md: env, then the scheduled copy next to this
# script, then the plugin's own skill directory.
resolve_kb_skill() {
  local candidate
  if [ -n "${AAE_KB_SKILL:-}" ]; then
    [ -f "$AAE_KB_SKILL" ] || { kb_fail "AAE_KB_SKILL points at a missing file: ${AAE_KB_SKILL}"; return 1; }
    printf '%s' "$AAE_KB_SKILL"; return 0
  fi
  candidate="${SCRIPT_DIR}/${KB_SKILL_COPY_NAME}"
  if [ -f "$candidate" ]; then printf '%s' "$candidate"; return 0; fi
  candidate="${SCRIPT_DIR}/../skills/aae-kb-update/SKILL.md"
  if [ -f "$candidate" ]; then
    printf '%s' "$(cd "$(dirname "$candidate")" && pwd)/SKILL.md"; return 0
  fi
  kb_fail "aae-kb-update SKILL.md not found (set AAE_KB_SKILL, or re-run install-schedule.sh install)"
}

# Pick the runner: AAE_KB_RUNNER, else claude, else codex.
resolve_kb_runner() {
  case "${AAE_KB_RUNNER:-}" in
    claude|codex)
      command -v "$AAE_KB_RUNNER" >/dev/null 2>&1 \
        || { kb_fail "AAE_KB_RUNNER=${AAE_KB_RUNNER} but '${AAE_KB_RUNNER}' is not on PATH (${PATH})"; return 1; }
      printf '%s' "$AAE_KB_RUNNER" ;;
    "")
      if command -v claude >/dev/null 2>&1; then printf 'claude'
      elif command -v codex >/dev/null 2>&1; then printf 'codex'
      else kb_fail "no AI runner found: neither claude nor codex is on PATH (${PATH})"; return 1
      fi ;;
    *) kb_fail "AAE_KB_RUNNER must be claude or codex, got: ${AAE_KB_RUNNER}"; return 1 ;;
  esac
}

# The plugin tree whose aae-kb-read and guide card the runner compares against:
# the repo clone if given, else the plugin this script ships in, else none.
resolve_kb_plugin_dir() {
  if [ -n "${AAE_KB_REPO:-}" ]; then
    printf '%s' "${AAE_KB_REPO}/plugins/aae"
  elif [ -d "${SCRIPT_DIR}/../skills/aae-kb-read/references" ]; then
    printf '%s' "$(cd "${SCRIPT_DIR}/.." && pwd)"
  fi
}

# Run "$@" with a time box. Returns the command's status, or 124 on timeout.
run_with_timeout() {
  local secs="$1"; shift
  local marker="${STATE_DIR}/.kb-timeout"
  rm -f "$marker"
  "$@" &
  local pid=$!
  ( sleep "$secs"; touch "$marker"; kill -TERM "$pid" 2>/dev/null; sleep 10; kill -KILL "$pid" 2>/dev/null ) 2>/dev/null &
  local watchdog=$!
  local rc=0
  wait "$pid" || rc=$?
  pkill -P "$watchdog" 2>/dev/null || true
  kill "$watchdog" 2>/dev/null || true
  wait "$watchdog" 2>/dev/null || true
  if [ -f "$marker" ]; then rm -f "$marker"; return 124; fi
  return "$rc"
}

# Append the runner's staged notes updates to the notes file, under a dated separator.
# On failure notes-pending.md is kept, so nothing is lost.
append_notes_pending() {
  local checked_at="$1"
  [ -s "$KB_NOTES_PENDING" ] || { rm -f "$KB_NOTES_PENDING"; return 0; }
  mkdir -p "$(dirname "$KB_NOTES")" \
    && printf '\n<!-- %s: added by aae-docs-watch --update-kb from report %s -->\n' \
         "$(date '+%Y-%m-%d')" "$checked_at" >> "$KB_NOTES" \
    && cat "$KB_NOTES_PENDING" >> "$KB_NOTES" \
    || { kb_fail "could not append ${KB_NOTES_PENDING} to the notes (${KB_NOTES}); it is kept for a manual append"; return 1; }
  rm -f "$KB_NOTES_PENDING"
  log "kb-update: appended the staged notes updates to ${KB_NOTES}"
}

run_kb_update() {
  local checked_at="" release_checked_at="" release_key="" skill runner plugin_dir prompt rc repo_line kb_line
  local docs_line release_line stamp_line newest_input="" already="" release_drift_key=""

  # Two inputs, each applied once: the docs watcher's changes report, and the
  # release check's drift report. Either alone is enough to start the runner.
  if [ -f "$REPORT_FILE" ] && grep -q '"status":"changes"' "$REPORT_FILE"; then
    checked_at="$(report_checked_at "$REPORT_FILE")"
    [ -n "$checked_at" ] || { kb_fail "cannot read checked_at from ${REPORT_FILE}"; return 1; }
    if kb_already_processed "$checked_at"; then
      already="docs report ${checked_at}"
      checked_at=""
    else
      newest_input="$REPORT_FILE"
    fi
  fi
  if [ -f "$KB_RELEASE_REPORT" ] && grep -q '"status":"drift"' "$KB_RELEASE_REPORT"; then
    release_checked_at="$(report_checked_at "$KB_RELEASE_REPORT")"
    [ -n "$release_checked_at" ] || { kb_fail "cannot read checked_at from ${KB_RELEASE_REPORT}"; return 1; }
    # Keyed by WHAT drifted (the released versions), not by when it was checked: the
    # check runs daily and the drift persists until the stamp is bumped, and a drift
    # already applied must not start a paid runner again every day.
    release_drift_key="$(sed -n 's/.*"drift_key":"\([^"]*\)".*/\1/p' "$KB_RELEASE_REPORT" | head -1)"
    [ -n "$release_drift_key" ] || { kb_fail "cannot read drift_key from ${KB_RELEASE_REPORT}"; return 1; }
    release_key="${KB_RELEASE_KEY_PREFIX}${release_drift_key}"
    if kb_already_processed "$release_key"; then
      already="${already:+${already} and }release drift ${release_drift_key}"
      release_key=""
    elif [ -z "$newest_input" ] || [ "$KB_RELEASE_REPORT" -nt "$newest_input" ]; then
      newest_input="$KB_RELEASE_REPORT"
    fi
  fi
  if [ -z "$checked_at" ] && [ -z "$release_key" ]; then
    if [ -n "$already" ]; then
      log "kb-update: ${already} already processed; nothing to do"
      rm -f "$KB_ERROR_FILE"
      return 0
    fi
    kb_fail "neither report.json holds a changes report nor release-report.json a drift report in ${STATE_DIR}; nothing to apply"
    return 1
  fi

  skill="$(resolve_kb_skill)" || return 1
  runner="$(resolve_kb_runner)" || return 1
  if [ -n "${AAE_KB_REPO:-}" ]; then
    [ -d "${AAE_KB_REPO}/${KB_REFERENCES_SUBPATH}" ] && [ -e "${AAE_KB_REPO}/.git" ] \
      || { kb_fail "AAE_KB_REPO is not a git clone of the plugin repository (needs .git and ${KB_REFERENCES_SUBPATH}): ${AAE_KB_REPO}"; return 1; }
  fi
  plugin_dir="$(resolve_kb_plugin_dir)"

  # Stage the runner's inputs inside the state directory.
  cp "$skill" "$KB_SKILL_STAGED" || { kb_fail "cannot stage the skill to ${KB_SKILL_STAGED}"; return 1; }
  rm -f "$KB_NOTES_BACKUP" "$KB_NOTES_PENDING"
  if [ -f "$KB_NOTES" ]; then
    cp "$KB_NOTES" "$KB_NOTES_BACKUP" || { kb_fail "cannot snapshot the notes to ${KB_NOTES_BACKUP}"; return 1; }
  fi
  rm -rf "$KB_BASELINE_STAGED"
  if [ -z "${AAE_KB_REPO:-}" ] && [ -n "$plugin_dir" ]; then
    mkdir -p "${KB_BASELINE_STAGED}/agents" \
      && cp -R "${plugin_dir}/skills/aae-kb-read" "${KB_BASELINE_STAGED}/" \
      && cp "${plugin_dir}/agents/aae-guide.md" "${KB_BASELINE_STAGED}/agents/" \
      || { kb_fail "cannot stage the shipped knowledge base to ${KB_BASELINE_STAGED}"; return 1; }
  fi

  local notes_line
  if [ -f "$KB_NOTES_BACKUP" ]; then
    notes_line="Personal notes, read-only snapshot: ${KB_NOTES_BACKUP}"
  else
    notes_line="Personal notes: none exist yet."
  fi
  if [ -n "${AAE_KB_REPO:-}" ]; then
    repo_line="Plugin repository clone (write reference-file and guide-card updates here): ${AAE_KB_REPO}"
    kb_line="Shipped knowledge base to compare against: the clone's plugins/aae/skills/aae-kb-read/ and plugins/aae/agents/aae-guide.md"
  else
    repo_line="Plugin repository clone: none (AAE_KB_REPO is unset). Reference-file updates become 'baseline candidate' entries in the notes-pending file; say so in the summary."
    if [ -n "$plugin_dir" ]; then
      kb_line="Shipped knowledge base to compare against (read-only copy): ${KB_BASELINE_STAGED}/aae-kb-read/ and ${KB_BASELINE_STAGED}/agents/aae-guide.md"
    else
      kb_line="Shipped knowledge base to compare against: not available to this run. Compare against the notes only, and say in the summary that the shipped knowledge base was not checked."
    fi
  fi
  if [ -n "$checked_at" ]; then
    docs_line="Docs changes report: ${REPORT_FILE} (checked_at=${checked_at}). Apply it as docs mode describes, and record it in ${KB_PROCESSED_FILE} under its checked_at."
  else
    docs_line="Docs changes report: not part of this run (none unprocessed). Skip the docs-page steps."
  fi
  if [ -n "$release_key" ]; then
    release_line="Release drift report: ${KB_RELEASE_REPORT} (checked_at=${release_checked_at}): the CLI and SDK versions released since the knowledge base's version stamp."
    if [ -f "$KB_RELEASE_NOTES" ]; then
      release_line="${release_line} CLI release notes newer than the stamp, newest first: ${KB_RELEASE_NOTES}."
    fi
    release_line="${release_line} Apply it as docs mode's release-input section describes, and record it in ${KB_PROCESSED_FILE} under the key \`${release_key}\`."
    if [ -n "${AAE_KB_REPO:-}" ]; then
      stamp_line="Version stamp: ${AAE_KB_REPO}/${KB_STAMP_SUBPATH}. Bump a field (cli, sdk_python, sdk_npm) only to a version whose release notes or package changes you actually read and applied; leave every other field as it is, and set verified_at to today only if you bumped something. Never bump a version you did not apply."
    else
      stamp_line="Version stamp: no clone, so the shipped kb-versions.json stays as it is. Record each version you applied as a baseline candidate in the notes-pending file instead."
    fi
  else
    release_line="Release drift report: not part of this run (none unprocessed). Skip the release steps and leave kb-versions.json as it is."
    stamp_line=""
  fi
  prompt="Run the aae-kb-update skill in docs mode with --auto. Nobody is present to answer questions. Today is $(date '+%Y-%m-%d').
Read the skill's instructions at ${KB_SKILL_STAGED} and follow its docs mode, --auto variant, exactly.
Watcher state directory: ${STATE_DIR}.
${docs_line}
${release_line}${stamp_line:+
${stamp_line}}
${notes_line}
Notes updates go to ${KB_NOTES_PENDING}, never to the notes file itself.
${repo_line}
${kb_line}
Do not run git or any shell command. Finish by writing ${KB_SUMMARY_FILE} and appending one line per applied report to ${KB_PROCESSED_FILE}, as the skill describes."

  log "kb-update: starting ${runner} for ${checked_at:+docs report ${checked_at} }${release_key:+release report ${release_checked_at} }(time box ${KB_TIMEOUT_SECONDS}s)"
  # The runner is itself a Claude Code or Codex session, so this plugin's SessionStart
  # hook would fire inside it and mark the user's pending notice as shown. Keep it quiet.
  export AAE_WATCH_NO_SESSION_NOTICE=1
  rc=0
  if [ "$runner" = "claude" ]; then
    local -a cmd=(claude -p "$prompt"
      --tools "$CLAUDE_TOOLS" --permission-mode acceptEdits --permission-prompts none
      --model "$KB_MODEL" --strict-mcp-config --max-budget-usd "$KB_MAX_USD"
      --no-session-persistence --output-format json --add-dir "$STATE_DIR")
    [ -n "${AAE_KB_REPO:-}" ] && cmd+=(--add-dir "$AAE_KB_REPO")
    ( cd "$STATE_DIR" && run_with_timeout "$KB_TIMEOUT_SECONDS" "${cmd[@]}" ) \
      > "$KB_RUNNER_LOG" 2>&1 < /dev/null || rc=$?
  else
    # Codex: untested here (no signed-in Codex available when this was written). The
    # workspace-write sandbox limits writes to -C and --add-dir: the state dir and clone.
    local -a cmd=(codex exec -s workspace-write -C "$STATE_DIR" --skip-git-repo-check --ephemeral
      -o "$KB_LAST_MESSAGE_FILE")
    [ -n "${AAE_KB_REPO:-}" ] && cmd+=(--add-dir "$AAE_KB_REPO")
    cmd+=("$prompt")
    run_with_timeout "$KB_TIMEOUT_SECONDS" "${cmd[@]}" > "$KB_RUNNER_LOG" 2>&1 < /dev/null || rc=$?
  fi

  if [ "$rc" -eq 124 ]; then
    kb_fail "${runner} timed out after ${KB_TIMEOUT_SECONDS}s; see ${KB_RUNNER_LOG}"; return 1
  fi
  if [ "$rc" -ne 0 ]; then
    local reason=""
    [ "$runner" = "claude" ] && reason="$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));print(" ("+d.get("subtype","")+", cost USD "+str(d.get("total_cost_usd"))+")")' "$KB_RUNNER_LOG" 2>/dev/null || true)"
    kb_fail "${runner} exited ${rc}${reason}; see ${KB_RUNNER_LOG}"; return 1
  fi
  local key
  for key in $checked_at $release_key; do
    kb_already_processed "$key" \
      || { kb_fail "${runner} finished but did not record report ${key} in kb-update-processed; see ${KB_RUNNER_LOG}"; return 1; }
  done
  [ -s "$KB_SUMMARY_FILE" ] && [ "$KB_SUMMARY_FILE" -nt "$newest_input" ] \
    || { kb_fail "${runner} finished but wrote no fresh kb-update.md; see ${KB_RUNNER_LOG}"; return 1; }
  append_notes_pending "${checked_at:-$release_key}" || return 1
  rm -f "$KB_ERROR_FILE"
  if [ "$runner" = "claude" ]; then
    log "kb-update: claude cost USD $(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("total_cost_usd","unknown"))' "$KB_RUNNER_LOG" 2>/dev/null || echo unknown)"
  fi
  log "kb-update: done. $(head -1 "$KB_SUMMARY_FILE")"
  return 0
}
