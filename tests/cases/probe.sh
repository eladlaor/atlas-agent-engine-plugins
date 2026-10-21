#!/usr/bin/env bash
#
# The session-start probe (FR-37 to FR-41, AC-30 to AC-34).
#
# The probe sends one request to GitHub's commits API, scoped to
# content/agentengine, and records commits newer than its baseline. These tests
# run it against a local fixture server that speaks enough of that API: an ETag,
# a 304 for a matching If-None-Match, and an injectable error status.

pending_shas() {
  python3 -c '
import json,sys
print(" ".join(c["sha"] for c in json.load(open(sys.argv[1]))["commits"]))
' "${STATE_DIR}/probe-pending.json"
}

# HOME points into the sandbox so this machine's own launchd schedule does not
# leak into the health notice.
run_probe_hook() {
  set +e
  RUN_OUT="$(
    AAE_WATCH_PROBE_API="$GH_API" \
    AAE_WATCH_STATE_DIR="$STATE_DIR" \
    AAE_WATCH_PROBE_MIN_MINUTES="${PROBE_MIN_MINUTES:-0}" \
    HOME="$SANDBOX" \
    "${REPO_ROOT}/plugins/aae/scripts/session-notice.sh" 2>"${SANDBOX}/hook-stderr.log"
  )"
  RUN_RC=$?
  set -e
}

# AC-30
test_first_run_records_baseline_and_reports_nothing() {
  gh_commits "aaa111|2026-10-20T10:00:00Z|DOCSP-1 First"
  start_gh_server || return 1

  run_probe
  assert_eq 0 "$RUN_RC" "first run exit code" || return 1
  assert_eq aaa111 "$(cat "${STATE_DIR}/probe-seen")" "baseline is the newest commit" || return 1
  assert_file "${STATE_DIR}/probe-etag" "ETag stored" || return 1
  assert_no_file "${STATE_DIR}/probe-pending.json" "baseline reports nothing"
}

# AC-31
test_new_commits_become_pending_newest_first() {
  gh_commits "aaa111|2026-10-20T10:00:00Z|DOCSP-1 First"
  start_gh_server || return 1
  run_probe

  gh_commits "ccc333|2026-10-21T12:00:00Z|DOCSP-3 Third" \
             "bbb222|2026-10-21T11:00:00Z|DOCSP-2 Second" \
             "aaa111|2026-10-20T10:00:00Z|DOCSP-1 First"
  run_probe
  assert_eq 10 "$RUN_RC" "new commits exit code" || return 1
  assert_eq "ccc333 bbb222" "$(pending_shas)" "exactly the new commits, newest first" || return 1
  assert_eq ccc333 "$(cat "${STATE_DIR}/probe-seen")" "baseline advances"
}

# AC-31: the cheap path. An unchanged upstream is asked conditionally.
test_unchanged_upstream_is_asked_with_etag_and_answers_304() {
  gh_commits "aaa111|2026-10-20T10:00:00Z|DOCSP-1 First"
  start_gh_server || return 1
  run_probe
  local etag; etag="$(cat "${STATE_DIR}/probe-etag")"

  run_probe
  assert_eq 0 "$RUN_RC" "unchanged exit code" || return 1
  assert_contains "$(tail -1 "${SANDBOX}/gh/requests.log")" "$etag" \
    "second request carries If-None-Match" || return 1
  assert_no_file "${STATE_DIR}/probe-pending.json" "nothing pending on 304"
}

# FR-39: commits the hook has not shown yet accumulate, never duplicated.
test_pending_accumulates_without_duplicates() {
  gh_commits "aaa111|2026-10-20T10:00:00Z|DOCSP-1 First"
  start_gh_server || return 1
  run_probe
  gh_commits "bbb222|2026-10-21T11:00:00Z|DOCSP-2 Second" \
             "aaa111|2026-10-20T10:00:00Z|DOCSP-1 First"
  run_probe
  gh_commits "ccc333|2026-10-21T12:00:00Z|DOCSP-3 Third" \
             "bbb222|2026-10-21T11:00:00Z|DOCSP-2 Second" \
             "aaa111|2026-10-20T10:00:00Z|DOCSP-1 First"
  run_probe
  assert_eq 10 "$RUN_RC" "exit code" || return 1
  assert_eq "ccc333 bbb222" "$(pending_shas)" "accumulated, newest first, no duplicates"
}

# FR-39: a baseline that fell out of the returned window must be flagged.
test_baseline_outside_window_marks_truncated() {
  printf 'zzz999\n' > "${STATE_DIR}/probe-seen"
  gh_commits "bbb222|2026-10-21T11:00:00Z|DOCSP-2 Second" \
             "aaa111|2026-10-20T10:00:00Z|DOCSP-1 First"
  start_gh_server || return 1

  run_probe
  assert_eq 10 "$RUN_RC" "exit code" || return 1
  assert_eq "bbb222 aaa111" "$(pending_shas)" "every returned commit is pending" || return 1
  assert_eq True "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["truncated"])' \
    "${STATE_DIR}/probe-pending.json")" "pending says more may exist"
}

# AC-32
test_throttle_skips_the_request() {
  gh_commits "aaa111|2026-10-20T10:00:00Z|DOCSP-1 First"
  start_gh_server || return 1
  run_probe
  local before; before="$(gh_request_count)"

  PROBE_MIN_MINUTES=15 run_probe
  assert_eq 20 "$RUN_RC" "throttled exit code" || return 1
  assert_eq "$before" "$(gh_request_count)" "no request sent while throttled"
}

# AC-33
test_rate_limit_fails_loudly_and_keeps_baseline() {
  gh_commits "aaa111|2026-10-20T10:00:00Z|DOCSP-1 First"
  start_gh_server || return 1
  run_probe
  printf '403\n' > "${SANDBOX}/gh/status"

  run_probe
  assert_eq 1 "$RUN_RC" "rate-limited exit code" || return 1
  assert_file "${STATE_DIR}/probe-error" "probe-error written" || return 1
  assert_contains "$(cat "${STATE_DIR}/probe-error")" "403" "error names the status" || return 1
  assert_eq aaa111 "$(cat "${STATE_DIR}/probe-seen")" "baseline untouched" || return 1

  rm -f "${SANDBOX}/gh/status"
  run_probe
  assert_eq 0 "$RUN_RC" "recovers" || return 1
  assert_no_file "${STATE_DIR}/probe-error" "success clears probe-error"
}

# AC-33
test_unreachable_api_fails_loudly() {
  local port
  port="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"
  GH_API="http://127.0.0.1:${port}/repos/mongodb/docs/commits"
  run_probe
  assert_eq 1 "$RUN_RC" "unreachable exit code" || return 1
  assert_file "${STATE_DIR}/probe-error" "probe-error written"
}

# AC-33: a non-JSON body is an error, not "nothing new".
test_unparseable_body_fails_loudly() {
  mkdir -p "${SANDBOX}/gh"
  printf '<html>maintenance</html>' > "${SANDBOX}/gh/commits.json"
  start_gh_server || return 1
  run_probe
  assert_eq 1 "$RUN_RC" "unparseable exit code" || return 1
  assert_file "${STATE_DIR}/probe-error" "probe-error written" || return 1
  assert_no_file "${STATE_DIR}/probe-seen" "no baseline from garbage"
}

# AC-34: the hook runs the probe by default and speaks once, in both channels.
test_hook_shows_new_commits_once() {
  gh_commits "aaa111|2026-10-20T10:00:00Z|DOCSP-1 First"
  start_gh_server || return 1
  run_probe_hook
  assert_eq "" "$RUN_OUT" "baseline session is silent" || return 1

  gh_commits "bbb222|2026-10-21T11:00:00Z|DOCSP-2 Renamed the memory package" \
             "aaa111|2026-10-20T10:00:00Z|DOCSP-1 First"
  run_probe_hook
  assert_eq 0 "$RUN_RC" "hook exit code" || return 1
  python3 -c '
import json,sys
d=json.loads(sys.argv[1])
assert "1 new" in d["systemMessage"], d["systemMessage"]
ctx=d["hookSpecificOutput"]["additionalContext"]
assert "DOCSP-2 Renamed the memory package" in ctx, ctx
assert "bbb222" in ctx, ctx
' "$RUN_OUT" || { fail "hook output is not the contracted shape: $RUN_OUT"; return 1; }
  assert_no_file "${STATE_DIR}/probe-pending.json" "pending cleared after showing" || return 1

  run_probe_hook
  assert_eq "" "$RUN_OUT" "next session is silent"
}

# AC-34
test_hook_off_sends_no_request() {
  gh_commits "aaa111|2026-10-20T10:00:00Z|DOCSP-1 First"
  start_gh_server || return 1
  AAE_WATCH_ON_SESSION=off run_probe_hook
  assert_eq 0 "$RUN_RC" "hook exit code" || return 1
  assert_eq 0 "$(gh_request_count)" "no request with the probe off"
}

# AC-33: a failing probe never blocks the session, and is not silent.
test_hook_names_probe_error_and_exits_zero() {
  gh_commits "aaa111|2026-10-20T10:00:00Z|DOCSP-1 First"
  start_gh_server || return 1
  printf '403\n' > "${SANDBOX}/gh/status"
  run_probe_hook
  assert_eq 0 "$RUN_RC" "hook must exit 0" || return 1
  assert_contains "$RUN_OUT" "probe" "health notice names the probe" || return 1
  assert_contains "$RUN_OUT" "403" "health notice carries the error"
}
