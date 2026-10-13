#!/usr/bin/env bash
#
# The --update-kb contract, asserted against BOTH detectors.
#
# These run without an AI runner on PATH, which is the point: the guarantee
# worth pinning is that the knowledge-base update can never change the crawl's
# own outcome. A runner failure must be recorded and announced, not swallowed,
# and not promoted into a crawl failure.
#
# Written before --update-kb was ported to the git detector, so they first
# pinned the hashing watcher's behaviour and then defined "ported correctly".

# Run a watcher with no AI runner reachable.
run_without_runner() {
  local impl="$1"; shift
  set +e
  if [ "$impl" = git ]; then
    RUN_OUT="$(
      PATH=/usr/bin:/bin \
      AAE_WATCH_DOCS_REPO="$GIT_FIXTURE" \
      AAE_WATCH_DOCS_BASE="https://www.mongodb.com/docs/agentengine" \
      AAE_WATCH_STATE_DIR="$STATE_DIR" \
      AAE_WATCH_NO_FETCH_PAGES=1 AAE_WATCH_QUIET=1 \
      "${REPO_ROOT}/plugins/aae/scripts/aae-docs-watch-git.sh" "$@" 2>"${SANDBOX}/stderr.log"
    )"
  else
    RUN_OUT="$(
      PATH=/usr/bin:/bin \
      AAE_WATCH_DOCS_BASE="$DOCS_BASE" \
      AAE_WATCH_STATE_DIR="$STATE_DIR" \
      AAE_WATCH_QUIET=1 AAE_WATCH_NET_RETRIES=1 AAE_WATCH_NET_RETRY_DELAY=0 \
      "${REPO_ROOT}/plugins/aae/scripts/aae-docs-watch.sh" "$@" 2>"${SANDBOX}/stderr.log"
    )"
  fi
  RUN_RC=$?
  set -e
}

hash_fixture_with_change() {
  seed_page "build/install" "# Install"
  seed_page "deploy/invoke-agent" "# Invoke"
  start_server
  run_watcher --full
  seed_changed_page "build/install" "# Install

Changed."
}

git_fixture_with_change() {
  git_fixture_init
  git_fixture_page "build/install" "Install
======="
  git_fixture_page "deploy/invoke-agent" "Invoke
======"
  git_fixture_commit "seed"
  run_git_watcher --full
  git_fixture_page "build/install" "Install
=======

Changed."
  git_fixture_commit "an edit"
}

# AC-19: without the flag, a changed page writes no kb-update* file at all.
test_AC19_hash_without_flag_writes_no_kb_files() {
  hash_fixture_with_change
  run_watcher --full
  assert_eq 10 "$RUN_RC" "exit 10" || return 1
  assert_no_file "${STATE_DIR}/kb-update.md" "no summary" || return 1
  assert_no_file "${STATE_DIR}/kb-update-error" "no error file" || return 1
  assert_no_file "${STATE_DIR}/kb-update-processed" "no processed record"
}

test_AC19_git_without_flag_writes_no_kb_files() {
  git_fixture_with_change
  run_git_watcher --full
  assert_eq 10 "$RUN_RC" "exit 10" || return 1
  assert_no_file "${STATE_DIR}/kb-update.md" "no summary" || return 1
  assert_no_file "${STATE_DIR}/kb-update-error" "no error file" || return 1
  assert_no_file "${STATE_DIR}/kb-update-processed" "no processed record"
}

# AC-20: with the flag and no runner, the crawl still exits 10 and the failure
# is recorded. The crawl's exit code must not become 1.
test_AC20_hash_no_runner_records_error_and_keeps_exit_code() {
  hash_fixture_with_change
  run_without_runner hash --full --update-kb
  assert_eq 10 "$RUN_RC" "a runner failure must not change the crawl's exit code" || return 1
  assert_file "${STATE_DIR}/kb-update-error" "records kb-update-error" || return 1
  assert_no_file "${STATE_DIR}/kb-update.md" "writes no summary on failure" || return 1
  assert_eq changes "$(report_field status)" "report still says changes"
}

test_AC20_git_no_runner_records_error_and_keeps_exit_code() {
  git_fixture_with_change
  run_without_runner git --full --update-kb
  assert_eq 10 "$RUN_RC" "a runner failure must not change the crawl's exit code" || return 1
  assert_file "${STATE_DIR}/kb-update-error" "records kb-update-error" || return 1
  assert_no_file "${STATE_DIR}/kb-update.md" "writes no summary on failure" || return 1
  assert_eq changes "$(report_field status)" "report still says changes"
}

# A clean run must not start the runner at all: no changes, nothing to apply.
test_clean_run_does_not_start_the_runner() {
  git_fixture_with_change
  run_git_watcher --full          # consumes the change
  run_without_runner git --full --update-kb
  assert_eq 0 "$RUN_RC" "clean run exits 0" || return 1
  assert_no_file "${STATE_DIR}/kb-update-error" "no runner attempt on a clean run"
}

# --kb-update-only refuses when there is no changes report to apply.
test_kb_update_only_refuses_without_a_changes_report() {
  git_fixture_init
  git_fixture_page "build/install" "Install
======="
  git_fixture_commit "seed"
  run_git_watcher --full
  assert_eq baseline "$(report_field status)" "precondition: baseline" || return 1

  run_without_runner git --kb-update-only
  assert_eq 1 "$RUN_RC" "--kb-update-only without changes exits 1"
}

# Both watchers source lib/kb-update.sh relative to their own directory, so the
# scheduled copy needs the library beside it. If a future install forgets to
# copy it, the script must fail loudly rather than quietly losing --update-kb.
test_a_watcher_without_its_library_fails_loudly() {
  local lone="${SANDBOX}/lone"
  mkdir -p "$lone"
  cp "${REPO_ROOT}/plugins/aae/scripts/aae-docs-watch-git.sh" "$lone/"
  set +e
  # --help deliberately answers before the library is sourced, so probe a real
  # run, which reaches the source line before it touches the network.
  local out; out="$( AAE_WATCH_STATE_DIR="$STATE_DIR" "$lone/aae-docs-watch-git.sh" --full 2>&1 )"
  local rc=$?
  set -e
  [ "$rc" -ne 0 ] || { fail "a watcher with no lib/ beside it must not run: $out"; return 1; }
  assert_contains "$out" "kb-update.sh" "the error names the missing library"
}

# The flag combination the hashing watcher rejects must be rejected identically.
test_kb_update_only_is_exclusive() {
  git_fixture_init
  git_fixture_page "build/install" "Install
======="
  git_fixture_commit "seed"
  run_without_runner git --kb-update-only --update-kb
  assert_eq 1 "$RUN_RC" "--kb-update-only with --update-kb exits 1"
}
