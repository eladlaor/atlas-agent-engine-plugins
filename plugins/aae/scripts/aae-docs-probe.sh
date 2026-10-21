#!/usr/bin/env bash
#
# aae-docs-probe.sh — one cheap request: did anything land in the Atlas Agent
# Engine documentation source since the last check?
#
# WHY A PROBE
#
# A local coding agent has no public address, so nothing can push a change to
# it; it has to ask. The cheapest question is GitHub's commits API for the
# public publishing repository mongodb/docs, filtered to content/agentengine:
# one request, no clone, no credentials, about a second. The ETag of the last
# answer is sent back as If-None-Match, so an unchanged upstream answers 304
# with no body.
#
# This answers "did anything land?", not "which pages changed?". Resolving
# commits to published pages, include fan-out and diffs is the git detector's
# job (aae-docs-watch-git.sh). The SessionStart hook runs this probe and shows
# what it found once. See knowledge/specs/BEHAVIOR_SPEC.md, FR-37 to FR-41.
#
# Rate limit: without a token GitHub allows 60 requests an hour per IP address,
# and a 304 still counts. Hence the throttle (FR-38).
#
# Exit codes: 0 = nothing new (or baseline recorded), 10 = new commits,
#             20 = throttled, 1 = error.

set -euo pipefail

# --------------------------------------------------------------------------
# Constants
# --------------------------------------------------------------------------

readonly DOCS_REPO_SLUG="mongodb/docs"
readonly DOCS_PATH="content/agentengine"
readonly DOCS_BRANCH="main"
# GitHub returns at most this many commits per page. More new commits than this
# between two probes is reported as "more may exist", not fetched page by page.
readonly PER_PAGE=30
readonly DEFAULT_API="https://api.github.com/repos/${DOCS_REPO_SLUG}/commits?path=${DOCS_PATH}&sha=${DOCS_BRANCH}&per_page=${PER_PAGE}"
readonly API_URL="${AAE_WATCH_PROBE_API:-$DEFAULT_API}"
readonly TIMEOUT_SECONDS="${AAE_WATCH_PROBE_TIMEOUT:-4}"
readonly MIN_MINUTES="${AAE_WATCH_PROBE_MIN_MINUTES:-15}"

STATE_DIR="${AAE_WATCH_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/aae-docs-watch}"
readonly STATE_DIR
readonly SEEN_FILE="${STATE_DIR}/probe-seen"
readonly ETAG_FILE="${STATE_DIR}/probe-etag"
readonly CHECKED_FILE="${STATE_DIR}/probe-checked"
readonly PENDING_FILE="${STATE_DIR}/probe-pending.json"
readonly ERROR_FILE="${STATE_DIR}/probe-error"

readonly EXIT_NEW=10
readonly EXIT_THROTTLED=20

# --------------------------------------------------------------------------
# Logging and failure
# --------------------------------------------------------------------------

log() {
  [ -n "${AAE_WATCH_QUIET:-}" ] && return 0
  printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$*" >&2
}

die() {
  local msg="aae-docs-probe: $*"
  printf '%s\n' "$msg" >&2
  printf '%s\t%s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$*" > "$ERROR_FILE" 2>/dev/null || true
  exit 1
}

usage() {
  cat <<'USAGE'
Usage: aae-docs-probe.sh [-h]

Asks GitHub, in one request, whether commits landed under content/agentengine in
mongodb/docs since the last probe. New commits go to probe-pending.json in the
state directory, for the SessionStart hook to show once.

Environment:
  AAE_WATCH_STATE_DIR          state directory (shared with the watchers)
  AAE_WATCH_PROBE_MIN_MINUTES  minimum minutes between requests (default 15)
  AAE_WATCH_PROBE_TIMEOUT      request timeout in seconds (default 4)
  AAE_WATCH_PROBE_API          override the API URL (tests)

Exit codes: 0 nothing new, 10 new commits, 20 throttled, 1 error.
USAGE
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "") : ;;
  *) usage >&2; exit 1 ;;
esac

command -v curl >/dev/null 2>&1 || die "curl not found on PATH"
command -v python3 >/dev/null 2>&1 || die "python3 not found on PATH"
mkdir -p "$STATE_DIR" || die "cannot create state directory ${STATE_DIR}"

# --------------------------------------------------------------------------
# Throttle (FR-38)
# --------------------------------------------------------------------------

if [ -f "$CHECKED_FILE" ] && [ "$MIN_MINUTES" -gt 0 ]; then
  age_seconds="$(python3 -c 'import os,sys,time;print(int(time.time()-os.path.getmtime(sys.argv[1])))' "$CHECKED_FILE")"
  if [ "$age_seconds" -lt $(( MIN_MINUTES * 60 )) ]; then
    log "last probe ${age_seconds}s ago, under ${MIN_MINUTES} minutes; not asking again"
    exit "$EXIT_THROTTLED"
  fi
fi

# --------------------------------------------------------------------------
# The one request (FR-37)
# --------------------------------------------------------------------------

work="$(mktemp -d "${TMPDIR:-/tmp}/aae-docs-probe.XXXXXX")"
trap 'rm -rf "$work"' EXIT

curl_args=(-sS --max-time "$TIMEOUT_SECONDS"
  -o "${work}/body" -D "${work}/headers" -w '%{http_code}'
  -H 'Accept: application/vnd.github+json'
  -H 'X-GitHub-Api-Version: 2022-11-28')
if [ -f "$ETAG_FILE" ] && [ -f "$SEEN_FILE" ]; then
  curl_args+=(-H "If-None-Match: $(cat "$ETAG_FILE")")
fi

set +e
http_code="$(curl "${curl_args[@]}" "$API_URL" 2>"${work}/curl-err")"
curl_rc=$?
set -e
[ "$curl_rc" -eq 0 ] || die "request to ${API_URL} failed (curl exit ${curl_rc}): $(head -1 "${work}/curl-err")"

case "$http_code" in
  304)
    log "no new commits under ${DOCS_PATH} (304)"
    touch "$CHECKED_FILE"
    rm -f "$ERROR_FILE"
    exit 0
    ;;
  200) : ;;
  *)
    die "GitHub answered HTTP ${http_code} for ${API_URL}: $(head -c 200 "${work}/body" | tr '\n' ' ')"
    ;;
esac

# --------------------------------------------------------------------------
# Record what is new (FR-39)
# --------------------------------------------------------------------------

set +e
new_count="$(python3 - "${work}/body" "$SEEN_FILE" "$PENDING_FILE" <<'PY'
import json, os, sys

body_path, seen_path, pending_path = sys.argv[1:4]
try:
    with open(body_path) as fh:
        commits = json.load(fh)
    if not isinstance(commits, list):
        raise ValueError(f"expected a JSON list, got {type(commits).__name__}")
    rows = [{
        "sha": c["sha"],
        "date": c["commit"]["committer"]["date"],
        "subject": c["commit"]["message"].splitlines()[0] if c["commit"]["message"] else "",
        "url": c.get("html_url", ""),
    } for c in commits]
except (ValueError, KeyError, TypeError) as exc:
    print(f"unparseable commits response: {exc}", file=sys.stderr)
    sys.exit(2)

if not rows:
    print("the commits response is empty; the path may have moved", file=sys.stderr)
    sys.exit(2)

if not os.path.isfile(seen_path):
    # First run: the baseline is the newest commit; nothing is reported.
    with open(seen_path, "w") as fh:
        fh.write(rows[0]["sha"] + "\n")
    print("baseline")
    sys.exit(0)

seen = open(seen_path).read().strip()
shas = [r["sha"] for r in rows]
truncated = seen not in shas
new = rows if truncated else rows[: shas.index(seen)]

if new:
    pending = {"truncated": False, "commits": []}
    if os.path.isfile(pending_path):
        with open(pending_path) as fh:
            pending = json.load(fh)
    known = {c["sha"] for c in pending["commits"]}
    pending["commits"] = [r for r in new if r["sha"] not in known] + pending["commits"]
    pending["truncated"] = pending["truncated"] or truncated
    tmp = pending_path + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(pending, fh)
    os.replace(tmp, pending_path)
    with open(seen_path, "w") as fh:
        fh.write(rows[0]["sha"] + "\n")
print(len(new))
PY
)"
py_rc=$?
set -e
[ "$py_rc" -eq 0 ] || die "could not read the commits response from ${API_URL}"

etag="$(sed -n 's/^[Ee][Tt][Aa][Gg]: *//p' "${work}/headers" | tr -d '\r' | tail -1)"
[ -n "$etag" ] && printf '%s\n' "$etag" > "$ETAG_FILE"
touch "$CHECKED_FILE"
rm -f "$ERROR_FILE"

if [ "$new_count" = baseline ]; then
  log "first probe: recorded the newest commit under ${DOCS_PATH} as the baseline"
  exit 0
fi
if [ "$new_count" -gt 0 ]; then
  log "${new_count} new commit(s) under ${DOCS_PATH}; recorded in ${PENDING_FILE}"
  exit "$EXIT_NEW"
fi
log "no new commits under ${DOCS_PATH}"
exit 0
