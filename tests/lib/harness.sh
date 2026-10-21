#!/usr/bin/env bash
#
# Test harness for the AAE docs watcher.
#
# Dependency-free on purpose: the plugin ships to users who have bash, curl and
# python3 and nothing else, so the suite must not need bats, shellcheck or any
# package manager. The runner in ../run-tests.sh discovers the cases.
#
# Fixture pages are served over real HTTP from a local python3 server rather than
# read through file:// URLs, because the watcher branches on curl's HTTP status
# code. file:// reports 000 and would bypass the exact logic under test.

# This file is SOURCED by the runner, so it must not set -e: a failing
# assertion has to be counted and reported, not abort the whole suite.
set -uo pipefail

# The runner may already have set TESTS_ROOT before sourcing this file.
: "${TESTS_ROOT:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
REPO_ROOT="$(cd "${TESTS_ROOT}/.." && pwd)"
WATCHER="${REPO_ROOT}/plugins/aae/scripts/aae-docs-watch.sh"
HOOK="${REPO_ROOT}/plugins/aae/scripts/session-notice.sh"

# Per-test scratch, set by new_sandbox.
SANDBOX=""
STATE_DIR=""
SERVE_DIR=""
DOCS_BASE=""
SERVER_PID=""

# --------------------------------------------------------------------------
# Assertions. Each prints a diagnostic and returns non-zero; the runner counts.
# --------------------------------------------------------------------------

fail() {
  printf '    FAIL: %s\n' "$*" >&2
  return 1
}

assert_eq() {
  # assert_eq <expected> <actual> <label>
  if [ "$1" != "$2" ]; then
    fail "$3: expected [$1], got [$2]"
    return 1
  fi
}

assert_contains() {
  # assert_contains <haystack> <needle> <label>
  case "$1" in
    *"$2"*) : ;;
    *) fail "$3: expected to contain [$2], got [$1]"; return 1 ;;
  esac
}

assert_not_contains() {
  case "$1" in
    *"$2"*) fail "$3: expected NOT to contain [$2]"; return 1 ;;
    *) : ;;
  esac
}

assert_file() {
  [ -f "$1" ] || { fail "$2: expected file to exist: $1"; return 1; }
}

assert_no_file() {
  [ ! -e "$1" ] || { fail "$2: expected file NOT to exist: $1"; return 1; }
}

# --------------------------------------------------------------------------
# Sandbox and fixture server
# --------------------------------------------------------------------------

new_sandbox() {
  SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/aae-watch-test.XXXXXX")"
  STATE_DIR="${SANDBOX}/state"
  SERVE_DIR="${SANDBOX}/site"
  mkdir -p "$STATE_DIR" "$SERVE_DIR"
}

cleanup_sandbox() {
  stop_server
  stop_gh_server
  [ -n "$SANDBOX" ] && [ -d "$SANDBOX" ] && rm -rf "$SANDBOX"
  SANDBOX=""
}

# Write one fixture page. seed_page <relative-path-without-.md> <body>
seed_page() {
  local rel="$1" body="$2" path
  path="${SERVE_DIR}/${rel}.md"
  mkdir -p "$(dirname "$path")"
  printf '%s\n' "$body" > "$path"
}

# Rewrite llms.txt from whatever pages currently exist under SERVE_DIR.
# The watcher greps for absolute URLs, so these must carry the live port.
regenerate_inventory() {
  local inv="${SERVE_DIR}/llms.txt"
  {
    printf '# Atlas Agent Engine (test fixture)\n\n'
    # Sort for determinism; the watcher sorts too, but a stable fixture makes
    # a failure diff readable.
    while IFS= read -r f; do
      printf -- '- [%s](%s/%s)\n' "$f" "$DOCS_BASE" "$f"
    done < <(cd "$SERVE_DIR" && find . -name '*.md' | sed 's|^\./||' | sort)
  } > "$inv"
}

start_server() {
  local port
  # Let the OS pick a free port, then reuse it: binding twice in quick
  # succession is reliable enough here and avoids a fixed-port collision
  # between parallel test runs.
  port="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"
  DOCS_BASE="http://127.0.0.1:${port}"
  regenerate_inventory
  python3 -m http.server "$port" --bind 127.0.0.1 --directory "$SERVE_DIR" \
    >"${SANDBOX}/server.log" 2>&1 &
  SERVER_PID=$!
  # Wait for readiness rather than sleeping a guessed interval.
  local i=0
  while [ "$i" -lt 100 ]; do
    if curl -sf -o /dev/null "${DOCS_BASE}/llms.txt"; then return 0; fi
    i=$(( i + 1 ))
    sleep 0.05
  done
  echo "fixture server failed to start; log:" >&2
  cat "${SANDBOX}/server.log" >&2
  return 1
}

stop_server() {
  if [ -n "$SERVER_PID" ]; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
    SERVER_PID=""
  fi
}

# --------------------------------------------------------------------------
# Running the watcher
# --------------------------------------------------------------------------

# run_watcher <args...> — captures stdout in RUN_OUT, exit code in RUN_RC.
# Never aborts the test on a non-zero code; the code is usually the assertion.
RUN_OUT=""
RUN_RC=0
run_watcher() {
  set +e
  RUN_OUT="$(
    AAE_WATCH_DOCS_BASE="$DOCS_BASE" \
    AAE_WATCH_STATE_DIR="$STATE_DIR" \
    AAE_WATCH_QUIET=1 \
    AAE_WATCH_NET_RETRIES=1 \
    AAE_WATCH_NET_RETRY_DELAY=0 \
    "$WATCHER" "$@" 2>"${SANDBOX}/stderr.log"
  )"
  RUN_RC=$?
  set -e
}

# Read a top-level string/number field out of report.json without a JSON parser,
# mirroring how the shipped consumers read it.
report_field() {
  python3 -c '
import json,sys
d=json.load(open(sys.argv[1]))
v=d
for k in sys.argv[2].split("."):
    v=v[k]
print(json.dumps(v) if isinstance(v,(list,dict)) else v)
' "${STATE_DIR}/report.json" "$1"
}

seed_changed_page() {
  # Make an existing page differ from the recorded baseline.
  seed_page "$1" "$2"
  regenerate_inventory
}

# --------------------------------------------------------------------------
# Shared report.json contract
# --------------------------------------------------------------------------
#
# Asserted against BOTH detectors. The whole point of the git-sourced rewrite
# is that the artifact does not change, so the same checks must hold for each.

assert_report_contract() {
  local label="${1:-report}"

  local keys
  keys="$(python3 -c '
import json,sys
print(" ".join(sorted(json.load(open(sys.argv[1])).keys())))
' "${STATE_DIR}/report.json")"
  assert_eq 'added changed checked_at counts fetch_errors inventory_changed mode pages_total removed status' \
    "$keys" "${label}: top-level keys" || return 1

  local lines; lines="$(wc -l < "${STATE_DIR}/report.json" | tr -d ' ')"
  assert_eq 1 "$lines" "${label}: must be one line" || return 1

  local body; body="$(cat "${STATE_DIR}/report.json")"
  assert_not_contains "$body" '": ' "${label}: no space after colon" || return 1

  grep -q '"status":"' "${STATE_DIR}/report.json" \
    || { fail "${label}: the shipped status grep would not match"; return 1; }
  local checked_at
  checked_at="$(sed -n 's/.*"checked_at":"\([^"]*\)".*/\1/p' "${STATE_DIR}/report.json")"
  printf '%s' "$checked_at" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' \
    || { fail "${label}: checked_at is not UTC ISO-8601: $checked_at"; return 1; }
}

# --------------------------------------------------------------------------
# Git fixture: a miniature mongodb/docs
# --------------------------------------------------------------------------
#
# Mirrors the real layout the detector depends on — content/agentengine with a
# source/ tree, a source/includes/ tree whose files are transcluded rather than
# published, and snooty.toml carrying the site-wide banner.

GIT_FIXTURE=""

git_fixture_init() {
  GIT_FIXTURE="${SANDBOX}/docs-fixture"
  mkdir -p "${GIT_FIXTURE}/content/agentengine/source/includes/limitations"
  git -C "$GIT_FIXTURE" init -q -b main 2>/dev/null || {
    git -C "$GIT_FIXTURE" init -q
    git -C "$GIT_FIXTURE" checkout -q -b main
  }
  git -C "$GIT_FIXTURE" config user.email test@example.com
  git -C "$GIT_FIXTURE" config user.name "Test"
  cat > "${GIT_FIXTURE}/content/agentengine/snooty.toml" <<'TOML'
name = "agentengine"
title = "Atlas Agent Engine"
[constants]
platform-short = "Agent Engine"
TOML
}

# git_fixture_page <path-without-extension> <body>
git_fixture_page() {
  local p="${GIT_FIXTURE}/content/agentengine/source/$1.txt"
  mkdir -p "$(dirname "$p")"
  printf '%s\n' "$2" > "$p"
}

# git_fixture_include <name-under-includes> <body>
git_fixture_include() {
  local p="${GIT_FIXTURE}/content/agentengine/source/includes/$1.rst"
  mkdir -p "$(dirname "$p")"
  printf '%s\n' "$2" > "$p"
}

git_fixture_commit() {
  git -C "$GIT_FIXTURE" add -A
  git -C "$GIT_FIXTURE" commit -q -m "${1:-change}"
}

git_fixture_rm() {
  rm -f "${GIT_FIXTURE}/content/agentengine/source/$1.txt"
}

# Run the git-sourced detector against the fixture repo.
run_git_watcher() {
  set +e
  RUN_OUT="$(
    AAE_WATCH_DOCS_REPO="$GIT_FIXTURE" \
    AAE_WATCH_DOCS_BASE="https://www.mongodb.com/docs/agentengine" \
    AAE_WATCH_STATE_DIR="$STATE_DIR" \
    AAE_WATCH_NO_FETCH_PAGES=1 \
    AAE_WATCH_QUIET=1 \
    "${REPO_ROOT}/plugins/aae/scripts/aae-docs-watch-git.sh" "$@" 2>"${SANDBOX}/stderr.log"
  )"
  RUN_RC=$?
  set -e
}

# --------------------------------------------------------------------------
# GitHub API fixture for the session-start probe
# --------------------------------------------------------------------------
#
# A real HTTP server, for the same reason as the docs fixture: the probe
# branches on the status code. It serves gh/commits.json with an ETag derived
# from the body, answers 304 to a matching If-None-Match, and answers with the
# code in gh/status (and a GitHub-style error body) when that file exists.
# Every request is logged to gh/requests.log as "<path> <If-None-Match>".

GH_API=""
GH_SERVER_PID=""

# gh_commits <sha|date|subject>... — newest first, as GitHub returns them.
gh_commits() {
  mkdir -p "${SANDBOX}/gh"
  python3 - "$@" > "${SANDBOX}/gh/commits.json" <<'PY'
import json, sys
out = []
for spec in sys.argv[1:]:
    sha, date, subject = spec.split("|", 2)
    out.append({
        "sha": sha,
        "html_url": f"https://github.com/mongodb/docs/commit/{sha}",
        "commit": {"message": subject + "\n\nbody", "committer": {"date": date}},
    })
json.dump(out, sys.stdout)
PY
}

start_gh_server() {
  mkdir -p "${SANDBOX}/gh"
  : > "${SANDBOX}/gh/requests.log"
  cat > "${SANDBOX}/gh/server.py" <<'PY'
import hashlib, http.server, os, sys
root = sys.argv[2]
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        inm = self.headers.get("If-None-Match", "-")
        with open(os.path.join(root, "requests.log"), "a") as fh:
            fh.write(f"{self.path} {inm}\n")
        status_file = os.path.join(root, "status")
        if os.path.exists(status_file):
            code = int(open(status_file).read().strip())
            body = b'{"message":"API rate limit exceeded"}'
            self.send_response(code); self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body))); self.end_headers()
            self.wfile.write(body); return
        body = open(os.path.join(root, "commits.json"), "rb").read()
        etag = 'W/"' + hashlib.sha256(body).hexdigest() + '"'
        if inm == etag:
            self.send_response(304); self.send_header("ETag", etag); self.end_headers(); return
        self.send_response(200); self.send_header("ETag", etag)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body))); self.end_headers()
        self.wfile.write(body)
    def log_message(self, *a): pass
http.server.HTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
PY
  local port
  port="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"
  GH_API="http://127.0.0.1:${port}/repos/mongodb/docs/commits?path=content/agentengine"
  python3 "${SANDBOX}/gh/server.py" "$port" "${SANDBOX}/gh" >"${SANDBOX}/gh/server.log" 2>&1 &
  GH_SERVER_PID=$!
  local i=0
  while [ "$i" -lt 100 ]; do
    if curl -s -o /dev/null "http://127.0.0.1:${port}/ready"; then
      : > "${SANDBOX}/gh/requests.log"
      return 0
    fi
    i=$(( i + 1 ))
    sleep 0.05
  done
  echo "GitHub fixture server failed to start; log:" >&2
  cat "${SANDBOX}/gh/server.log" >&2
  return 1
}

stop_gh_server() {
  if [ -n "$GH_SERVER_PID" ]; then
    kill "$GH_SERVER_PID" 2>/dev/null || true
    wait "$GH_SERVER_PID" 2>/dev/null || true
    GH_SERVER_PID=""
  fi
}

gh_request_count() { wc -l < "${SANDBOX}/gh/requests.log" | tr -d ' '; }

# run_probe <args...> — throttle off unless the test sets PROBE_MIN_MINUTES.
run_probe() {
  set +e
  RUN_OUT="$(
    AAE_WATCH_PROBE_API="$GH_API" \
    AAE_WATCH_STATE_DIR="$STATE_DIR" \
    AAE_WATCH_PROBE_MIN_MINUTES="${PROBE_MIN_MINUTES:-0}" \
    AAE_WATCH_QUIET=1 \
    "${REPO_ROOT}/plugins/aae/scripts/aae-docs-probe.sh" "$@" 2>"${SANDBOX}/stderr.log"
  )"
  RUN_RC=$?
  set -e
}
