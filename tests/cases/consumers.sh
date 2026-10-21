#!/usr/bin/env bash
#
# The downstream consumers, fed by the GIT detector.
#
# This is the test that actually earns the word "drop-in". The git-sourced
# detector is only a safe replacement if the code that reads its output cannot
# tell the difference. Four things read the watcher's state; these cover the
# two that are executable without an AI runner or a launchd job.

run_hook() {
  set +e
  # The probe is covered in probe.sh; here it would reach the real GitHub.
  RUN_OUT="$(
    AAE_WATCH_STATE_DIR="$STATE_DIR" \
    AAE_WATCH_ON_SESSION=off \
    "${REPO_ROOT}/plugins/aae/scripts/session-notice.sh" 2>"${SANDBOX}/hook-stderr.log"
  )"
  RUN_RC=$?
  set -e
}

seed_and_change() {
  git_fixture_init
  git_fixture_page "add-features/memory-only" "Memory
======

pip install agentic-platform-memory"
  git_fixture_page "build/install" "Install
======="
  git_fixture_commit "seed"
  run_git_watcher --full

  git_fixture_page "add-features/memory-only" "Memory
======

pip install agent-engine-sdk-memory"
  git_fixture_commit "DOCSP-65094 Correct package name"
  run_git_watcher --full
}

# The hook must emit BOTH channels: the human message and the model context.
# Emitting only one defeats the point — the model is the consumer that matters.
test_hook_reads_a_git_produced_report() {
  seed_and_change
  assert_eq changes "$(report_field status)" "precondition: changes" || return 1

  run_hook
  assert_eq 0 "$RUN_RC" "hook must always exit 0" || return 1

  python3 -c '
import json,sys
d=json.loads(sys.argv[1])
assert d.get("systemMessage"), "no systemMessage"
ctx=d.get("hookSpecificOutput",{}).get("additionalContext")
assert ctx, "no additionalContext"
# systemMessage is a one-line summary for the human; the changed pages are
# named in additionalContext, which is what the model reads.
assert "1 changed" in d["systemMessage"], "systemMessage does not report the count"
assert "memory-only" in ctx, "changed page not named in additionalContext"
' "$RUN_OUT" || { fail "hook output is not the contracted shape: $RUN_OUT"; return 1; }
}

# Second invocation must be silent, or every session repeats the same news.
test_hook_is_silent_on_second_invocation() {
  seed_and_change
  run_hook
  assert_contains "$RUN_OUT" "systemMessage" "first invocation speaks" || return 1

  run_hook
  assert_eq 0 "$RUN_RC" "hook still exits 0" || return 1
  assert_eq "" "$RUN_OUT" "second invocation must be silent"
}

# A watcher problem must never block a session.
test_hook_exits_zero_on_malformed_state() {
  printf 'not json at all' > "${STATE_DIR}/report.json"
  run_hook
  assert_eq 0 "$RUN_RC" "malformed report must not break the session" || return 1

  rm -f "${STATE_DIR}/report.json"
  run_hook
  assert_eq 0 "$RUN_RC" "missing report must not break the session"
}

# install-schedule.sh status parses report.json by hard-indexing ["status"]
# and ["counts"]. If the git detector dropped either, this breaks.
test_install_schedule_status_parses_a_git_produced_report() {
  seed_and_change

  set +e
  local out
  out="$(
    AAE_WATCH_STATE_DIR="$STATE_DIR" \
    "${REPO_ROOT}/plugins/aae/scripts/install-schedule.sh" status 2>&1
  )"
  set -e

  assert_contains "$out" "status: changes" \
    "install-schedule.sh must read the git-produced report" || return 1
  assert_not_contains "$out" "Traceback" "no parse error"
}
