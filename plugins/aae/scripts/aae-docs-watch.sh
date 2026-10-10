#!/usr/bin/env bash
#
# aae-docs-watch.sh — detect changes in MongoDB Atlas Agent Engine documentation.
#
# The AAE docs site publishes a machine-readable page inventory at llms.txt, and
# serves every page as clean markdown via a .md suffix. Those markdown bodies are
# byte-stable across fetches, so a SHA-256 per page is a reliable change signal.
# There is no lastmod and no ETag on the .md responses, so conditional GETs are
# not available and content hashing is the only dependable method.
#
# Modes:
#   --quick   Fetch only llms.txt. Detects pages added, removed, or retitled. ~1s.
#   --full    Crawl every page and hash it. Detects body edits too. ~40s.
#
# Opt-in: --update-kb starts an AI runner (claude or codex) after a run that found
# changes, to apply them to the knowledge base with the aae-kb-update skill in docs
# mode (--auto). A runner failure is recorded in kb-update-error and never changes
# the crawl's own outcome or exit code.
#
# Exit codes: 0 = no changes, 10 = changes found, 1 = error.

set -euo pipefail

readonly DOCS_BASE="https://www.mongodb.com/docs/agentengine"
readonly INVENTORY_URL="${DOCS_BASE}/llms.txt"
readonly CURL_TIMEOUT=30
readonly PARALLEL=8
# A scheduled run can start during a brief maintenance wake, before the network is
# up. Retry the first request instead of losing the day's check.
readonly NET_RETRIES="${AAE_WATCH_NET_RETRIES:-6}"
readonly NET_RETRY_DELAY="${AAE_WATCH_NET_RETRY_DELAY:-30}"

STATE_DIR="${AAE_WATCH_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/aae-docs-watch}"
readonly STATE_DIR
readonly INVENTORY_FILE="${STATE_DIR}/inventory.txt"
readonly URLS_FILE="${STATE_DIR}/urls.txt"
readonly MANIFEST_FILE="${STATE_DIR}/manifest.tsv"
readonly PAGES_DIR="${STATE_DIR}/pages"
readonly DIFF_DIR="${STATE_DIR}/diffs"
readonly REPORT_FILE="${STATE_DIR}/report.json"
readonly ACK_FILE="${STATE_DIR}/acknowledged"
# Local date and time of the last completed full crawl, e.g. "2026-10-09 10:00 IDT".
readonly LAST_FULL_RUN_FILE="${STATE_DIR}/last-full-run"
# Written when a run fails, removed when a full run succeeds. The SessionStart
# hook reads it, so a broken watcher is announced instead of looking like "no changes".
readonly LAST_ERROR_FILE="${STATE_DIR}/last-error"
readonly EXIT_CHANGES=10
readonly EXIT_SKIPPED=20

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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

MODE="full"
SKIP_IF_RAN_TODAY=""
UPDATE_KB=""
KB_UPDATE_ONLY=""

now() { date '+%Y-%m-%d %H:%M:%S %Z'; }
die() {
  printf '%s aae-docs-watch: ERROR: %s\n' "$(now)" "$1" >&2
  if [ -d "$STATE_DIR" ]; then
    printf '%s\t%s\n' "$(now)" "$1" > "$LAST_ERROR_FILE" 2>/dev/null || true
  fi
  exit 1
}
log() { [ -n "${AAE_WATCH_QUIET:-}" ] || printf '%s %s\n' "$(now)" "$1" >&2; }

usage() {
  cat <<'USAGE'
Usage: aae-docs-watch.sh [--quick|--full] [--skip-if-ran-today] [--update-kb] [-h]
       aae-docs-watch.sh --kb-update-only

  --quick               Inventory-only check (page added/removed/retitled). Fast.
  --full                Full crawl with per-page content hashing. Default.
  --skip-if-ran-today   With --full: if a full crawl already completed today (local
                        date), do nothing and keep that run's report. Used by the
                        daily schedule and by on-demand checks, so a second run on
                        the same day cannot replace the morning's list of changes.
  --update-kb           Opt-in. When the run finds changes, start an AI runner to apply
                        them to the knowledge base (aae-kb-update, docs mode, --auto).
                        A runner failure is written to kb-update-error; the exit code
                        stays that of the crawl.
  --kb-update-only      Do not crawl. Apply the existing changes report to the knowledge
                        base, for example to retry after a runner failure.
                        Exit 0 on success or when already processed, 1 on failure.

Exit: 0 no changes, 10 changes detected, 20 skipped (already ran today), 1 error.
State lives in ${XDG_STATE_HOME:-~/.local/state}/aae-docs-watch (override with AAE_WATCH_STATE_DIR).

Knowledge-base update environment (all optional):
  AAE_KB_RUNNER     claude | codex. Default: claude if on PATH, else codex.
  AAE_KB_REPO       A git clone of the plugin repository. Reference-file and guide-card
                    updates are written there. Unset: they go to the notes as
                    "baseline candidate" entries.
  AAE_KB_NOTES      Personal notes file. Default ~/.claude/agent-memory/aae-guide/MEMORY.md.
  AAE_KB_SKILL      Path to the aae-kb-update SKILL.md. Default: aae-kb-update.SKILL.md
                    next to this script, else ../skills/aae-kb-update/SKILL.md.
  AAE_KB_MAX_USD    Spending cap per claude run. Default 2.
  AAE_KB_MODEL      Model for the claude runner. Default sonnet.
  AAE_KB_TIMEOUT_SECONDS  Time box for the runner. Default 900.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --quick) MODE="quick" ;;
    --full)  MODE="full" ;;
    --skip-if-ran-today) SKIP_IF_RAN_TODAY="1" ;;
    --update-kb) UPDATE_KB="1" ;;
    --kb-update-only) KB_UPDATE_ONLY="1" ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
  shift
done

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

# Print the report's checked_at, or nothing.
report_checked_at() {
  sed -n 's/.*"checked_at":"\([^"]*\)".*/\1/p' "$REPORT_FILE" 2>/dev/null | head -1
}

kb_already_processed() {
  [ -f "$KB_PROCESSED_FILE" ] && grep -qF -- "$1" "$KB_PROCESSED_FILE"
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
    && printf '\n<!-- %s: added by aae-docs-watch --update-kb from the docs report of %s -->\n' \
         "$(date '+%Y-%m-%d')" "$checked_at" >> "$KB_NOTES" \
    && cat "$KB_NOTES_PENDING" >> "$KB_NOTES" \
    || { kb_fail "could not append ${KB_NOTES_PENDING} to the notes (${KB_NOTES}); it is kept for a manual append"; return 1; }
  rm -f "$KB_NOTES_PENDING"
  log "kb-update: appended the staged notes updates to ${KB_NOTES}"
}

run_kb_update() {
  local checked_at skill runner plugin_dir prompt rc repo_line kb_line
  [ -f "$REPORT_FILE" ] || { kb_fail "no report.json in ${STATE_DIR}; run a check first"; return 1; }
  grep -q '"status":"changes"' "$REPORT_FILE" \
    || { kb_fail "report.json does not hold a changes report; nothing to apply"; return 1; }
  checked_at="$(report_checked_at)"
  [ -n "$checked_at" ] || { kb_fail "cannot read checked_at from ${REPORT_FILE}"; return 1; }
  if kb_already_processed "$checked_at"; then
    log "kb-update: report ${checked_at} was already processed; nothing to do"
    rm -f "$KB_ERROR_FILE"
    return 0
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
  prompt="Run the aae-kb-update skill in docs mode with --auto. Nobody is present to answer questions. Today is $(date '+%Y-%m-%d').
Read the skill's instructions at ${KB_SKILL_STAGED} and follow its docs mode, --auto variant, exactly.
Watcher state directory: ${STATE_DIR} (report.json checked_at=${checked_at}).
${notes_line}
Notes updates go to ${KB_NOTES_PENDING}, never to the notes file itself.
${repo_line}
${kb_line}
Do not run git or any shell command. Finish by writing ${KB_SUMMARY_FILE} and appending to ${KB_PROCESSED_FILE}, as the skill describes."

  log "kb-update: starting ${runner} for report ${checked_at} (time box ${KB_TIMEOUT_SECONDS}s)"
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
  kb_already_processed "$checked_at" \
    || { kb_fail "${runner} finished but did not record report ${checked_at} in kb-update-processed; see ${KB_RUNNER_LOG}"; return 1; }
  [ -s "$KB_SUMMARY_FILE" ] && [ "$KB_SUMMARY_FILE" -nt "$REPORT_FILE" ] \
    || { kb_fail "${runner} finished but wrote no fresh kb-update.md; see ${KB_RUNNER_LOG}"; return 1; }
  append_notes_pending "$checked_at" || return 1
  rm -f "$KB_ERROR_FILE"
  if [ "$runner" = "claude" ]; then
    log "kb-update: claude cost USD $(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("total_cost_usd","unknown"))' "$KB_RUNNER_LOG" 2>/dev/null || echo unknown)"
  fi
  log "kb-update: done. $(head -1 "$KB_SUMMARY_FILE")"
  return 0
}

if [ -n "$KB_UPDATE_ONLY" ]; then
  [ -z "$UPDATE_KB$SKIP_IF_RAN_TODAY" ] || die "--kb-update-only takes no other options"
  [ -d "$STATE_DIR" ] || die "no state directory: ${STATE_DIR}"
  run_kb_update && exit 0
  exit 1
fi

if [ -n "$SKIP_IF_RAN_TODAY" ]; then
  [ "$MODE" = "full" ] || die "--skip-if-ran-today applies to --full only"
  if [ -f "$LAST_FULL_RUN_FILE" ]; then
    last_run="$(cat "$LAST_FULL_RUN_FILE")"
    if [ "${last_run%% *}" = "$(date '+%Y-%m-%d')" ]; then
      log "already ran today (${last_run}); keeping that report. Run without --skip-if-ran-today to force."
      printf 'status=skipped last_full_run=%s report=%s\n' "$last_run" "$REPORT_FILE"
      exit "$EXIT_SKIPPED"
    fi
  fi
fi

command -v curl   >/dev/null 2>&1 || die "curl not found on PATH"
command -v shasum >/dev/null 2>&1 || die "shasum not found on PATH"

mkdir -p "$STATE_DIR" "$PAGES_DIR" "$DIFF_DIR" || die "cannot create state dir: $STATE_DIR"

WORK_DIR="$(mktemp -d)" || die "cannot create temp dir"
cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

# Escape a string for embedding in a JSON string literal.
json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/\\t/g'
}

# Turn a page URL into a filesystem-safe slug.
slug_for() {
  printf '%s' "$1" | sed -e "s|${DOCS_BASE}/||" -e 's|/|__|g'
}

# ---------------------------------------------------------------------------
# Step 1: fetch the inventory
# ---------------------------------------------------------------------------
NEW_INVENTORY="${WORK_DIR}/inventory.txt"
attempt=1
while :; do
  if http_code="$(curl -sL --max-time "$CURL_TIMEOUT" -o "$NEW_INVENTORY" -w '%{http_code}' "$INVENTORY_URL")"; then
    break
  fi
  [ "$attempt" -lt "$NET_RETRIES" ] \
    || die "network failure fetching inventory after ${NET_RETRIES} attempts: $INVENTORY_URL"
  log "network not reachable (attempt ${attempt}/${NET_RETRIES}); retrying in ${NET_RETRY_DELAY}s"
  sleep "$NET_RETRY_DELAY"
  attempt=$(( attempt + 1 ))
done
[ "$http_code" = "200" ] || die "inventory returned HTTP ${http_code}: $INVENTORY_URL"
[ -s "$NEW_INVENTORY" ] || die "inventory is empty: $INVENTORY_URL"

NEW_URLS="${WORK_DIR}/urls.txt"
# index.md is listed in llms.txt but is not served (confirmed 404); skip it.
grep -o "${DOCS_BASE}/[^)]*\.md" "$NEW_INVENTORY" \
  | grep -v "^${DOCS_BASE}/index\.md$" \
  | sort -u > "$NEW_URLS" || true
url_count="$(wc -l < "$NEW_URLS" | tr -d ' ')"
[ "$url_count" -gt 0 ] || die "parsed 0 page URLs from inventory — the format may have changed"
log "inventory: ${url_count} pages"

INVENTORY_CHANGED="false"
if [ -f "$INVENTORY_FILE" ]; then
  cmp -s "$INVENTORY_FILE" "$NEW_INVENTORY" || INVENTORY_CHANGED="true"
else
  INVENTORY_CHANGED="first-run"
fi

# ---------------------------------------------------------------------------
# Step 2: determine added / removed pages
# ---------------------------------------------------------------------------
# The URL baseline is tracked separately from the content manifest so that a
# --quick run (which never crawls pages) still advances the added/removed
# baseline instead of re-reporting the whole site on every invocation.
OLD_URLS="${WORK_DIR}/old-urls.txt"
if [ -f "$URLS_FILE" ]; then
  sort -u "$URLS_FILE" > "$OLD_URLS"
elif [ -f "$MANIFEST_FILE" ]; then
  cut -f1 "$MANIFEST_FILE" | sort -u > "$OLD_URLS"
else
  : > "$OLD_URLS"
fi

ADDED="$(comm -13 "$OLD_URLS" "$NEW_URLS" || true)"
REMOVED="$(comm -23 "$OLD_URLS" "$NEW_URLS" || true)"

# ---------------------------------------------------------------------------
# Step 3 (full mode only): crawl and hash every page
# ---------------------------------------------------------------------------
CHANGED=""
FETCH_ERRORS=""
if [ "$MODE" = "full" ]; then
  log "crawling ${url_count} pages (${PARALLEL} parallel)…"
  FETCHER="${WORK_DIR}/fetch.sh"
  cat > "$FETCHER" <<'FETCH'
#!/bin/sh
url="$1"
slug=$(printf '%s' "$url" | sed -e "s|$DOCS_BASE/||" -e 's|/|__|g')
out="$OUT_DIR/$slug"
code=$(curl -sL --retry 2 --retry-delay 2 --max-time "$CURL_TIMEOUT" -o "$out" -w '%{http_code}' "$url" 2>/dev/null) || code="000"
if [ "$code" = "200" ] && [ -s "$out" ]; then
  printf '%s\t%s\t%s\n' "$url" "$(shasum -a 256 "$out" | cut -d' ' -f1)" "ok"
else
  printf '%s\t%s\t%s\n' "$url" "-" "http_$code"
fi
FETCH
  chmod +x "$FETCHER"

  OUT_DIR="${WORK_DIR}/pages"; mkdir -p "$OUT_DIR"
  export OUT_DIR DOCS_BASE CURL_TIMEOUT
  RAW="${WORK_DIR}/raw.tsv"
  xargs -P "$PARALLEL" -n 1 "$FETCHER" < "$NEW_URLS" > "$RAW" \
    || die "crawl failed"

  FETCH_ERRORS="$(awk -F'\t' '$3!="ok" {print $1" ("$3")"}' "$RAW" || true)"
  NEW_MANIFEST="${WORK_DIR}/manifest.tsv"
  awk -F'\t' '$3=="ok" {print $1"\t"$2}' "$RAW" | sort > "$NEW_MANIFEST"

  ok_count="$(wc -l < "$NEW_MANIFEST" | tr -d ' ')"
  [ "$ok_count" -gt 0 ] || die "every page fetch failed — aborting rather than recording an empty baseline"
  log "fetched ok: ${ok_count}/${url_count}"

  # Guard against recording a degraded crawl as the new truth.
  if [ -f "$MANIFEST_FILE" ]; then
    prev_count="$(wc -l < "$MANIFEST_FILE" | tr -d ' ')"
    if [ "$ok_count" -lt $(( prev_count / 2 )) ]; then
      die "only ${ok_count} pages fetched vs ${prev_count} previously — refusing to overwrite baseline"
    fi
  fi

  # Compare hashes for URLs present in both manifests.
  if [ -s "$MANIFEST_FILE" ]; then
    while IFS=$'\t' read -r url newhash; do
      oldhash="$(awk -F'\t' -v u="$url" '$1==u {print $2; exit}' "$MANIFEST_FILE" || true)"
      [ -n "$oldhash" ] || continue              # new page, already in ADDED
      [ "$oldhash" = "$newhash" ] && continue
      CHANGED="${CHANGED}${url}"$'\n'
      slug="$(slug_for "$url")"
      if [ -f "${PAGES_DIR}/${slug}" ]; then
        diff -u "${PAGES_DIR}/${slug}" "${OUT_DIR}/${slug}" \
          > "${DIFF_DIR}/${slug}.diff" 2>/dev/null || true
      fi
    done < "$NEW_MANIFEST"
  fi
  CHANGED="$(printf '%s' "$CHANGED" | sed '/^$/d' || true)"

  # Promote the crawl to the new baseline.
  cp "$NEW_MANIFEST" "$MANIFEST_FILE"
  rm -rf "$PAGES_DIR"; mv "$OUT_DIR" "$PAGES_DIR"
fi

cp "$NEW_INVENTORY" "$INVENTORY_FILE"
cp "$NEW_URLS" "$URLS_FILE"

# ---------------------------------------------------------------------------
# Step 4: write the report
# ---------------------------------------------------------------------------
count_lines() { [ -z "$1" ] && printf '0' || printf '%s' "$(printf '%s\n' "$1" | sed '/^$/d' | wc -l | tr -d ' ')"; }

json_array() {
  local items="$1" first=1 line
  printf '['
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    [ $first -eq 1 ] || printf ','
    printf '"%s"' "$(json_escape "$line")"
    first=0
  done <<< "$items"
  printf ']'
}

n_added="$(count_lines "$ADDED")"
n_removed="$(count_lines "$REMOVED")"
n_changed="$(count_lines "$CHANGED")"
total_changes=$(( n_added + n_removed + n_changed ))

if [ "$INVENTORY_CHANGED" = "first-run" ]; then
  # Nothing to compare against yet: record the baseline, report no changes, and
  # do not list all ~195 pages as "added".
  STATUS="baseline"
  ADDED=""
  n_added=0
  total_changes=0
elif [ "$total_changes" -gt 0 ]; then
  STATUS="changes"
else
  STATUS="clean"
fi

{
  printf '{'
  printf '"checked_at":"%s",' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf '"mode":"%s",' "$MODE"
  printf '"status":"%s",' "$STATUS"
  printf '"pages_total":%s,' "$url_count"
  printf '"inventory_changed":"%s",' "$INVENTORY_CHANGED"
  printf '"counts":{"added":%s,"removed":%s,"changed":%s},' "$n_added" "$n_removed" "$n_changed"
  printf '"added":%s,' "$(json_array "$ADDED")"
  printf '"removed":%s,' "$(json_array "$REMOVED")"
  printf '"changed":%s,' "$(json_array "$CHANGED")"
  printf '"fetch_errors":%s' "$(json_array "$FETCH_ERRORS")"
  printf '}\n'
} > "$REPORT_FILE"

if [ "$MODE" = "full" ]; then
  date '+%Y-%m-%d %H:%M %Z' > "$LAST_FULL_RUN_FILE"
  rm -f "$LAST_ERROR_FILE"
fi

# A fresh report has not been shown to the user yet.
[ "$STATUS" = "changes" ] && rm -f "$ACK_FILE"

log "status=${STATUS} added=${n_added} removed=${n_removed} changed=${n_changed}"

# The full report can be hundreds of lines; print it only on request so that
# cron/launchd logs and hook callers stay readable.
if [ -n "${AAE_WATCH_PRINT_JSON:-}" ]; then
  cat "$REPORT_FILE"
else
  printf 'status=%s added=%s removed=%s changed=%s report=%s\n' \
    "$STATUS" "$n_added" "$n_removed" "$n_changed" "$REPORT_FILE"
fi

# Opt-in knowledge-base update. Its failure is recorded in kb-update-error and
# deliberately does not change this run's exit code.
if [ "$STATUS" = "changes" ] && [ -n "$UPDATE_KB" ]; then
  run_kb_update || true
fi

[ "$STATUS" = "changes" ] && exit "$EXIT_CHANGES"
exit 0
