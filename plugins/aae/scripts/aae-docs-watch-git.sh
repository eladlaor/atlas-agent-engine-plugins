#!/usr/bin/env bash
#
# aae-docs-watch-git.sh — detect changes in MongoDB Atlas Agent Engine
# documentation from the publishing repository's git history.
#
# WHY GIT RATHER THAN HASHING PAGES
#
# The Agent Engine docs publish no change-notification surface: the
# release-notes URL is a redirect loop, both SDK changelogs hold only an
# "[Unreleased]" heading, and none of the ~196 .md pages send Last-Modified.
# The original watcher worked around that by fetching every page daily and
# comparing SHA-256 hashes. That works, but it can only ever know what changed
# since its own first crawl, it cannot say WHEN a change landed or who made it,
# and a page edited and reverted between two runs is invisible.
#
# The pages are published from the PUBLIC repo mongodb/docs, path
# content/agentengine. Reading its history instead gives exact commit
# timestamps, real file-level diffs, author and commit message, and history
# from BEFORE this tool was first run. It needs no credentials: the repository
# is public.
#
# Contract: this script is a drop-in replacement for aae-docs-watch.sh. It
# writes the same report.json, the same state layout and the same exit codes,
# so the SessionStart notice, the aae-kb-update runner, the aae-scout gate and
# the launchd job keep working unchanged. See knowledge/specs/BEHAVIOR_SPEC.md.
#
# Modes:
#   --quick   Fetch and compare HEAD only; report whether commits landed. ~2s.
#   --full    Resolve every changed page, write diffs and page bodies.
#
# Exit codes: 0 = no changes, 10 = changes found, 20 = skipped, 1 = error.

set -euo pipefail

# --------------------------------------------------------------------------
# Constants
# --------------------------------------------------------------------------

# The publishing repository. Public: no token, no permission, no org access.
readonly DOCS_REPO="${AAE_WATCH_DOCS_REPO:-https://github.com/mongodb/docs.git}"
# Everything Agent Engine lives under this one path.
readonly DOCS_PATH="content/agentengine"
readonly SOURCE_PATH="${DOCS_PATH}/source"
readonly INCLUDES_PATH="${SOURCE_PATH}/includes"
# snooty.toml holds the site-wide banner and the substituted constants. A
# one-line edit here changes every published page while touching no source
# page, so it is handled as a special case rather than filtered out.
readonly SNOOTY_CONFIG="${DOCS_PATH}/snooty.toml"
readonly DOCS_BASE="${AAE_WATCH_DOCS_BASE:-https://www.mongodb.com/docs/agentengine}"
readonly DEFAULT_BRANCH="${AAE_WATCH_DOCS_BRANCH:-main}"
readonly CURL_TIMEOUT=30

STATE_DIR="${AAE_WATCH_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/aae-docs-watch}"
readonly STATE_DIR
readonly CLONE_DIR="${STATE_DIR}/docs-repo"
readonly URLS_FILE="${STATE_DIR}/urls.txt"
readonly PAGES_DIR="${STATE_DIR}/pages"
readonly DIFF_DIR="${STATE_DIR}/diffs"
readonly REPORT_FILE="${STATE_DIR}/report.json"
readonly ACK_FILE="${STATE_DIR}/acknowledged"
readonly LAST_FULL_RUN_FILE="${STATE_DIR}/last-full-run"
readonly LAST_ERROR_FILE="${STATE_DIR}/last-error"
# The commit this tool last reported on. The git equivalent of the old
# manifest.tsv: it is the entire baseline.
readonly LAST_COMMIT_FILE="${STATE_DIR}/last-commit"
# Human-readable digest of the run, including the collapsing of a CLI
# regeneration into one line. Kept out of report.json so the machine contract
# stays byte-compatible with the hashing watcher.
readonly SUMMARY_FILE="${STATE_DIR}/changes-summary.md"

readonly EXIT_CHANGES=10
readonly EXIT_SKIPPED=20

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

MODE="full"
SKIP_IF_RAN_TODAY=0
UPDATE_KB=""
KB_UPDATE_ONLY=""

# --------------------------------------------------------------------------
# Logging and failure
# --------------------------------------------------------------------------

now() { date '+%Y-%m-%d %H:%M:%S %Z'; }

log() {
  [ -n "${AAE_WATCH_QUIET:-}" ] && return 0
  printf '%s  %s\n' "$(now)" "$*" >&2
  return 0
}

die() {
  local msg="$*"
  mkdir -p "$STATE_DIR" 2>/dev/null || true
  printf '%s\t%s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$msg" > "$LAST_ERROR_FILE" 2>/dev/null || true
  printf '%s  ERROR: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$msg" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage: aae-docs-watch-git.sh [--quick|--full] [--skip-if-ran-today] [--update-kb] [-h]
       aae-docs-watch-git.sh --kb-update-only

Detects Agent Engine documentation changes from the git history of the public
mongodb/docs repository.

  --quick               Compare HEAD only; report whether commits landed.
  --full                Resolve changed pages, write diffs and bodies (default).
  --skip-if-ran-today   Exit 20 if a full run already completed today.
  --update-kb           After a run that found changes, start an AI runner to
                        apply them to the knowledge base. Never changes this
                        script's exit code.
  --kb-update-only      Apply the existing report without detecting anything.
  -h, --help            This text.

Exit codes: 0 no changes, 10 changes found, 20 skipped, 1 error.

Environment:
  AAE_WATCH_STATE_DIR   State root (default ${XDG_STATE_HOME:-~/.local/state}/aae-docs-watch)
  AAE_WATCH_DOCS_REPO   Override the source repository (tests)
  AAE_WATCH_DOCS_BASE   Override the published site base (tests)
  AAE_WATCH_DOCS_BRANCH Branch to track (default main)
  AAE_WATCH_QUIET       Suppress progress logging
  AAE_WATCH_NO_FETCH_PAGES  Do not fetch published page bodies
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --quick) MODE="quick" ;;
    --full) MODE="full" ;;
    --skip-if-ran-today) SKIP_IF_RAN_TODAY=1 ;;
    --update-kb) UPDATE_KB=1 ;;
    --kb-update-only) KB_UPDATE_ONLY=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
  shift
done

command -v git >/dev/null 2>&1 || die "git is required but not on PATH"

# The --update-kb machinery, shared with aae-docs-watch.sh.
. "${SCRIPT_DIR}/lib/kb-update.sh"

# Applying an existing report does no detection at all, so it runs before the
# clone is touched.
if [ -n "$KB_UPDATE_ONLY" ]; then
  [ -z "${UPDATE_KB}" ] && [ "$SKIP_IF_RAN_TODAY" -eq 0 ] \
    || die "--kb-update-only takes no other options"
  [ -d "$STATE_DIR" ] || die "no state directory: ${STATE_DIR}"
  run_kb_update && exit 0
  exit 1
fi

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

# The slug rule is inherited verbatim from the hashing watcher, because the
# aae-kb-update skill and the session notice both reconstruct it.
slug_for() {
  printf '%s' "$1" | sed -e "s|${DOCS_BASE}/||" -e 's|/|__|g'
}

json_escape() {
  printf '%s' "$1" | sed -e 's|\\|\\\\|g' -e 's|"|\\"|g' -e 's|	|\\t|g'
}

json_array() {
  # One item per line in, compact JSON array out.
  local items="$1" first=1 line
  printf '['
  if [ -n "$items" ]; then
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      [ $first -eq 1 ] || printf ','
      printf '"%s"' "$(json_escape "$line")"
      first=0
    done <<EOF
$items
EOF
  fi
  printf ']'
}

count_lines() {
  [ -z "$1" ] && { printf '0'; return; }
  printf '%s' "$(printf '%s\n' "$1" | sed '/^$/d' | wc -l | tr -d ' ')"
}

# content/agentengine/source/<path>.txt -> <DOCS_BASE>/<path>.md
#
# Verified exact on 2026-10-13: 200 source files, 196 listed in llms.txt, 196
# matches, 0 published URLs without a source file. The 4 remainder are LICENSE
# pages that llms.txt omits but the site serves, so the source tree — not
# llms.txt — is the authoritative page set.
source_to_url() {
  local path="$1" rel
  case "$path" in
    "${SOURCE_PATH}/"*.txt) : ;;
    *) return 1 ;;
  esac
  # Includes are transcluded, never published on their own.
  case "$path" in
    "${INCLUDES_PATH}/"*) return 1 ;;
  esac
  rel="${path#"${SOURCE_PATH}/"}"
  rel="${rel%.txt}"
  # Published URLs normalise to lowercase.
  rel="$(printf '%s' "$rel" | tr '[:upper:]' '[:lower:]')"
  printf '%s/%s.md' "$DOCS_BASE" "$rel"
}

git_in() { git -C "$CLONE_DIR" "$@"; }

# --------------------------------------------------------------------------
# The clone
# --------------------------------------------------------------------------
#
# Blobless and sparse: file contents are fetched on demand and only the one
# content path is materialised. mongodb/docs is a large monorepo; this keeps
# the working tree to the Agent Engine pages while still giving full history
# for that path.
ensure_clone() {
  if [ -d "${CLONE_DIR}/.git" ]; then
    log "updating the docs clone…"
    git_in fetch --quiet origin "$DEFAULT_BRANCH" \
      || die "git fetch failed — is the network reachable? repo: $DOCS_REPO"
    return 0
  fi
  log "creating the docs clone (one time, a minute or so)…"
  mkdir -p "$(dirname "$CLONE_DIR")"
  git clone --filter=blob:none --sparse --no-checkout --quiet \
    "$DOCS_REPO" "$CLONE_DIR" \
    || die "git clone failed for $DOCS_REPO"
  git_in sparse-checkout set "$DOCS_PATH" \
    || die "sparse-checkout failed for $DOCS_PATH"
  git_in fetch --quiet origin "$DEFAULT_BRANCH" \
    || die "git fetch failed after clone"
}

# --------------------------------------------------------------------------
# Change classification
# --------------------------------------------------------------------------

# Pages that transclude a given include file, resolved AT THE COMMIT being
# reported rather than at HEAD. Resolving at HEAD mis-attributes whenever an
# include is added or removed in the same range.
pages_including() {
  local include_path="$1" at_commit="$2" include_rel hits f url
  include_rel="${include_path#"${SOURCE_PATH}"}"   # e.g. /includes/limitations/x.rst
  hits="$(git_in grep -l -F -e "include:: ${include_rel}" "$at_commit" -- "${SOURCE_PATH}" 2>/dev/null || true)"
  [ -z "$hits" ] && return 0
  # git grep prefixes "<rev>:" on each path.
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    f="${f#"${at_commit}":}"
    if url="$(source_to_url "$f" 2>/dev/null)"; then
      printf '%s\n' "$url"
    fi
  done <<EOF
$hits
EOF
}

# Every published page at a commit — used for pages_total, and as the blast
# radius of a snooty.toml change.
all_pages_at() {
  local at_commit="$1" f url
  git_in ls-tree -r --name-only "$at_commit" -- "$SOURCE_PATH" 2>/dev/null | {
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      if url="$(source_to_url "$f" 2>/dev/null)"; then
        printf '%s\n' "$url"
      fi
    done
  } | sort -u
}

# --------------------------------------------------------------------------
# Run
# --------------------------------------------------------------------------

mkdir -p "$STATE_DIR" "$PAGES_DIR" "$DIFF_DIR"

if [ "$SKIP_IF_RAN_TODAY" -eq 1 ]; then
  [ "$MODE" = "full" ] || die "--skip-if-ran-today applies to --full only"
  if [ -f "$LAST_FULL_RUN_FILE" ]; then
    last_day="$(cut -d' ' -f1 < "$LAST_FULL_RUN_FILE" 2>/dev/null || true)"
    if [ "$last_day" = "$(date '+%Y-%m-%d')" ]; then
      log "a full run already completed today; skipping"
      printf 'status=skipped last_full_run=%s report=%s\n' \
        "$(cat "$LAST_FULL_RUN_FILE")" "$REPORT_FILE"
      exit "$EXIT_SKIPPED"
    fi
  fi
fi

ensure_clone

HEAD_SHA="$(git_in rev-parse "origin/${DEFAULT_BRANCH}" 2>/dev/null)" \
  || die "cannot resolve origin/${DEFAULT_BRANCH} in the clone"

# A path that resolves to no commits at all means the content moved. Reporting
# "clean" then would be a silent, permanent blind spot, so it is an error.
total_commits="$(git_in rev-list --count "$HEAD_SHA" -- "$DOCS_PATH" 2>/dev/null || printf '0')"
[ "$total_commits" -gt 0 ] \
  || die "no commits touch ${DOCS_PATH} — the docs may have moved in the repository"

PAGES_TOTAL="$(all_pages_at "$HEAD_SHA" | wc -l | tr -d ' ')"
[ "$PAGES_TOTAL" -gt 0 ] || die "resolved 0 published pages at ${HEAD_SHA} — the layout may have changed"
all_pages_at "$HEAD_SHA" > "$URLS_FILE"

ADDED=""; REMOVED=""; CHANGED=""; SUMMARY=""
INVENTORY_CHANGED="false"
STATUS="clean"

if [ ! -f "$LAST_COMMIT_FILE" ]; then
  # First run ever: record where we are. It must never say "no changes",
  # because it compared nothing.
  STATUS="baseline"
  INVENTORY_CHANGED="first-run"
  log "baseline recorded at ${HEAD_SHA} (${PAGES_TOTAL} pages)"
else
  BASE_SHA="$(cat "$LAST_COMMIT_FILE")"
  if ! git_in cat-file -e "${BASE_SHA}^{commit}" 2>/dev/null; then
    die "recorded baseline commit ${BASE_SHA} is not in the clone — delete ${LAST_COMMIT_FILE} to re-baseline"
  fi

  if [ "$BASE_SHA" = "$HEAD_SHA" ]; then
    log "no new commits since ${BASE_SHA}"
  else
    range_commits="$(git_in rev-list --count "${BASE_SHA}..${HEAD_SHA}" -- "$DOCS_PATH")"
    log "${range_commits} new commit(s) touching ${DOCS_PATH}"

    if [ "$MODE" = "full" ] && [ "$range_commits" -gt 0 ]; then
      # --diff-filter is deliberately not used: we want A, M, D and R all
      # classified, and renames resolved to their published effect.
      changes="$(git_in diff --name-status -M "${BASE_SHA}" "${HEAD_SHA}" -- "$DOCS_PATH" || true)"

      snooty_touched=0
      while IFS=$'\t' read -r st f rest; do
        [ -z "${st:-}" ] && continue
        case "$st" in
          R*) # rename: treat the old path as removed, the new as added
            if url="$(source_to_url "$f" 2>/dev/null)"; then REMOVED="${REMOVED}${url}"$'\n'; fi
            if url="$(source_to_url "${rest:-}" 2>/dev/null)"; then ADDED="${ADDED}${url}"$'\n'; fi
            continue ;;
        esac

        if [ "$f" = "$SNOOTY_CONFIG" ]; then
          snooty_touched=1
          continue
        fi

        case "$f" in
          "${INCLUDES_PATH}/"*)
            # An include is not a page. Its change lands on every page that
            # transcludes it.
            fan="$(pages_including "$f" "$HEAD_SHA")"
            [ -n "$fan" ] && CHANGED="${CHANGED}${fan}"$'\n'
            SUMMARY="${SUMMARY}- shared include \`${f#"${INCLUDES_PATH}/"}\` changed, affecting $(count_lines "$fan") page(s)"$'\n'
            continue ;;
        esac

        url="$(source_to_url "$f" 2>/dev/null)" || continue
        case "$st" in
          A) ADDED="${ADDED}${url}"$'\n' ;;
          D) REMOVED="${REMOVED}${url}"$'\n' ;;
          *) CHANGED="${CHANGED}${url}"$'\n' ;;
        esac
      done <<EOF
$changes
EOF

      if [ "$snooty_touched" -eq 1 ]; then
        # The banner renders on every page and the constants substitute into
        # dozens. Treating this as "no page changed" is the single largest
        # miss a source-path filter can make.
        INVENTORY_CHANGED="true"
        CHANGED="${CHANGED}$(all_pages_at "$HEAD_SHA")"$'\n'
        SUMMARY="${SUMMARY}- \`snooty.toml\` changed: site-wide banner or substituted constants, affecting up to ${PAGES_TOTAL} page(s)"$'\n'
      fi

      ADDED="$(printf '%s' "$ADDED" | sed '/^$/d' | sort -u || true)"
      REMOVED="$(printf '%s' "$REMOVED" | sed '/^$/d' | sort -u || true)"
      CHANGED="$(printf '%s' "$CHANGED" | sed '/^$/d' | sort -u || true)"
      # A page cannot be both added and changed.
      if [ -n "$ADDED" ] && [ -n "$CHANGED" ]; then
        CHANGED="$(comm -23 <(printf '%s\n' "$CHANGED") <(printf '%s\n' "$ADDED") || true)"
      fi

      [ -n "$ADDED$REMOVED" ] && INVENTORY_CHANGED="true"

      # One CLI release regenerates every cli/ page at once. That is signal,
      # but 37 separate alerts is noise, so the human summary collapses it.
      cli_changed="$(printf '%s\n' "$CHANGED" | grep -c "${DOCS_BASE}/cli/" || true)"
      if [ "${cli_changed:-0}" -ge 5 ]; then
        SUMMARY="${SUMMARY}- CLI reference regenerated: ${cli_changed} \`cli/\` pages changed together (one release, not ${cli_changed} separate edits)"$'\n'
      fi

      # Diffs, and the published body for context.
      while IFS= read -r url; do
        [ -z "$url" ] && continue
        slug="$(slug_for "$url")"
        rel="${url#"${DOCS_BASE}/"}"; rel="${rel%.md}"
        src="${SOURCE_PATH}/${rel}.txt"
        git_in diff "${BASE_SHA}" "${HEAD_SHA}" -- "$src" > "${DIFF_DIR}/${slug}.diff" 2>/dev/null || true
        [ -s "${DIFF_DIR}/${slug}.diff" ] || rm -f "${DIFF_DIR}/${slug}.diff"
        if [ -z "${AAE_WATCH_NO_FETCH_PAGES:-}" ]; then
          curl -sL --max-time "$CURL_TIMEOUT" -o "${PAGES_DIR}/${slug}" "$url" 2>/dev/null || true
        fi
      done <<EOF
$CHANGED
EOF

      # Commit-level provenance: the thing hashing could never report.
      SUMMARY="${SUMMARY}"$'\n'"Commits in range:"$'\n'
      SUMMARY="${SUMMARY}$(git_in log --no-merges --date=short \
        --format='- %ad `%h` %s' "${BASE_SHA}..${HEAD_SHA}" -- "$DOCS_PATH")"$'\n'
    fi
  fi
fi

n_added="$(count_lines "$ADDED")"
n_removed="$(count_lines "$REMOVED")"
n_changed="$(count_lines "$CHANGED")"

if [ "$STATUS" != "baseline" ]; then
  if [ "$(( n_added + n_removed + n_changed ))" -gt 0 ]; then
    STATUS="changes"
  else
    STATUS="clean"
  fi
else
  # Baseline compares nothing, so it reports nothing.
  ADDED=""; REMOVED=""; CHANGED=""
  n_added=0; n_removed=0; n_changed=0
fi

# --------------------------------------------------------------------------
# report.json — compact and single-line ON PURPOSE.
#
# Two shipped readers parse it textually (a grep for '"status":"changes"' and a
# sed for checked_at), and install-schedule.sh hard-indexes ["status"] and
# ["counts"]. Pretty-printing this file breaks them silently.
# --------------------------------------------------------------------------
{
  printf '{'
  printf '"checked_at":"%s",' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf '"mode":"%s",' "$MODE"
  printf '"status":"%s",' "$STATUS"
  printf '"pages_total":%s,' "$PAGES_TOTAL"
  printf '"inventory_changed":"%s",' "$INVENTORY_CHANGED"
  printf '"counts":{"added":%s,"removed":%s,"changed":%s},' "$n_added" "$n_removed" "$n_changed"
  printf '"added":%s,' "$(json_array "$ADDED")"
  printf '"removed":%s,' "$(json_array "$REMOVED")"
  printf '"changed":%s,' "$(json_array "$CHANGED")"
  # Kept for contract compatibility. A git range either resolves or the run
  # fails, so there is no per-page fetch error to report.
  printf '"fetch_errors":[]'
  printf '}\n'
} > "$REPORT_FILE"

{
  printf '# Agent Engine docs changes\n\n'
  printf 'Checked %s, source: git history of `%s`\n\n' "$(date '+%Y-%m-%d %H:%M %Z')" "$DOCS_PATH"
  if [ "$STATUS" = "changes" ]; then
    printf '%d changed, %d added, %d removed.\n\n' "$n_changed" "$n_added" "$n_removed"
    [ -n "$SUMMARY" ] && printf '%s\n' "$SUMMARY"
  elif [ "$STATUS" = "baseline" ]; then
    printf 'Baseline recorded: %s pages at `%s`. Nothing compared.\n' "$PAGES_TOTAL" "$HEAD_SHA"
  else
    printf 'Checked %s pages, 0 changes.\n' "$PAGES_TOTAL"
  fi
} > "$SUMMARY_FILE"

# A fresh report has not been shown yet.
[ "$STATUS" = "changes" ] && rm -f "$ACK_FILE"

# Advance the baseline only at the very end, so a failure never swallows a
# change by moving the pointer past it.
printf '%s\n' "$HEAD_SHA" > "$LAST_COMMIT_FILE"
if [ "$MODE" = "full" ]; then
  date '+%Y-%m-%d %H:%M %Z' > "$LAST_FULL_RUN_FILE"
  rm -f "$LAST_ERROR_FILE"
fi

printf 'status=%s added=%s removed=%s changed=%s report=%s\n' \
  "$STATUS" "$n_added" "$n_removed" "$n_changed" "$REPORT_FILE"

# Opt-in, and deliberately incapable of changing the outcome above: `|| true`
# means a failed knowledge-base update is recorded and announced, never
# promoted into a failed crawl.
if [ -n "$UPDATE_KB" ] && [ "$STATUS" = "changes" ]; then
  run_kb_update || true
fi

[ "$STATUS" = "changes" ] && exit "$EXIT_CHANGES"
exit 0
