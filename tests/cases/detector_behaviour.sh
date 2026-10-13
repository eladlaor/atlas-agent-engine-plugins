#!/usr/bin/env bash
#
# Ports the detector half of BEHAVIOR_SPEC.md's acceptance criteria into
# executable tests: AC-1, AC-2, AC-3, AC-12 and AC-16.
#
# These run against the SHIPPED hashing watcher, unmodified apart from the
# AAE_WATCH_DOCS_BASE test seam. That is deliberate: a suite written against a
# replacement detector proves only that the replacement does what it does.
# Passing here first is what makes this a regression suite for the git-sourced
# detector to satisfy.

seed_three_pages() {
  seed_page "build/install" "# Install

Run the installer."
  seed_page "deploy/invoke-agent" "# Invoke

POST to the invoke endpoint."
  seed_page "add-features/memory-only" "# Memory

pip install agentic-platform-memory"
  start_server
}

# AC-2: first run on empty state yields status=baseline, added=[], rc=0.
test_AC2_first_run_records_baseline_only() {
  seed_three_pages
  run_watcher --full

  assert_eq 0 "$RUN_RC" "AC-2 exit code" || return 1
  assert_eq baseline "$(report_field status)" "AC-2 status" || return 1
  assert_eq '[]' "$(report_field added)" "AC-2 added must be empty" || return 1
  assert_eq 0 "$(report_field counts.added)" "AC-2 counts.added" || return 1
  assert_eq first-run "$(report_field inventory_changed)" "AC-2 inventory_changed" || return 1
  assert_eq 3 "$(report_field pages_total)" "AC-2 pages_total" || return 1
  # The point of AC-2: a baseline must never be described as "no changes".
  assert_contains "$RUN_OUT" "status=baseline" "AC-2 stdout summary"
}

# AC-3: a second run with no upstream change yields status=clean, rc=0.
test_AC3_unchanged_second_run_is_clean() {
  seed_three_pages
  run_watcher --full
  run_watcher --full

  assert_eq 0 "$RUN_RC" "AC-3 exit code" || return 1
  assert_eq clean "$(report_field status)" "AC-3 status" || return 1
  assert_eq 0 "$(report_field counts.changed)" "AC-3 counts.changed" || return 1
  assert_eq false "$(report_field inventory_changed)" "AC-3 inventory_changed"
}

# AC-1: a changed page yields status=changes, rc=10, the URL in changed[], and
# a .diff file. The spec phrases this as tampering with a manifest hash; editing
# the upstream fixture exercises the same comparison from the real direction.
test_AC1_changed_page_is_reported_with_diff() {
  seed_three_pages
  run_watcher --full

  seed_changed_page "add-features/memory-only" "# Memory

pip install agent-engine-sdk-memory"
  run_watcher --full

  assert_eq 10 "$RUN_RC" "AC-1 exit code" || return 1
  assert_eq changes "$(report_field status)" "AC-1 status" || return 1
  assert_eq 1 "$(report_field counts.changed)" "AC-1 counts.changed" || return 1
  assert_contains "$(report_field changed)" "add-features/memory-only.md" \
    "AC-1 changed[] holds the page URL" || return 1

  local slug="add-features__memory-only.md"
  assert_file "${STATE_DIR}/diffs/${slug}.diff" "AC-1 diff written" || return 1
  local diff_body; diff_body="$(cat "${STATE_DIR}/diffs/${slug}.diff")"
  assert_contains "$diff_body" "agent-engine-sdk-memory" "AC-1 diff holds the new text" || return 1
  assert_contains "$diff_body" "agentic-platform-memory" "AC-1 diff holds the old text"
}

# AC-12: a degraded crawl (<50% of known pages) exits 1 and leaves the
# baseline untouched. This is the guard that stops a partial outage being
# recorded as mass deletion.
test_AC12_degraded_crawl_refuses_to_overwrite_baseline() {
  # Ten pages so that removing most of them crosses the 50% threshold.
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    seed_page "page-${i}" "# Page ${i}"
  done
  start_server
  run_watcher --full
  assert_eq baseline "$(report_field status)" "AC-12 precondition: baseline recorded" || return 1

  local manifest_before; manifest_before="$(cat "${STATE_DIR}/manifest.tsv")"

  # Serve 404 for most pages while keeping them listed in the inventory, which
  # is what a partial outage looks like from the crawler's side.
  for i in 3 4 5 6 7 8 9 10; do
    rm -f "${SERVE_DIR}/page-${i}.md"
  done
  run_watcher --full

  assert_eq 1 "$RUN_RC" "AC-12 must exit 1" || return 1
  local manifest_after; manifest_after="$(cat "${STATE_DIR}/manifest.tsv")"
  assert_eq "$manifest_before" "$manifest_after" "AC-12 manifest must be unchanged" || return 1
  assert_file "${STATE_DIR}/last-error" "AC-12 records last-error"
}

# AC-16: --skip-if-ran-today crawls with no marker, exits 20 on a same-day
# repeat without touching report.json, crawls again with yesterday's marker,
# and refuses --quick.
test_AC16_skip_if_ran_today() {
  seed_three_pages

  run_watcher --full --skip-if-ran-today
  assert_eq 0 "$RUN_RC" "AC-16 first run crawls" || return 1
  assert_file "${STATE_DIR}/last-full-run" "AC-16 writes last-full-run" || return 1

  local report_before; report_before="$(cat "${STATE_DIR}/report.json")"
  run_watcher --full --skip-if-ran-today
  assert_eq 20 "$RUN_RC" "AC-16 same-day repeat exits 20" || return 1
  assert_eq "$report_before" "$(cat "${STATE_DIR}/report.json")" \
    "AC-16 report.json unchanged on skip" || return 1
  assert_contains "$RUN_OUT" "status=skipped" "AC-16 skip summary" || return 1

  # Yesterday's marker must not skip.
  printf '2000-01-01 10:00 UTC\n' > "${STATE_DIR}/last-full-run"
  run_watcher --full --skip-if-ran-today
  assert_eq 0 "$RUN_RC" "AC-16 stale marker crawls again" || return 1

  # --quick with the flag is an error.
  run_watcher --quick --skip-if-ran-today
  assert_eq 1 "$RUN_RC" "AC-16 --quick --skip-if-ran-today exits 1"
}

# --quick advances the URL baseline without re-reporting the whole site, and
# never writes last-full-run. (BEHAVIOR_SPEC "State layout", AC-4's cheap half.)
test_quick_mode_advances_urls_without_full_marker() {
  seed_three_pages
  run_watcher --full

  seed_page "deploy/new-page" "# New"
  regenerate_inventory
  rm -f "${STATE_DIR}/last-full-run"

  run_watcher --quick
  assert_eq quick "$(report_field mode)" "quick mode recorded" || return 1
  assert_eq true "$(report_field inventory_changed)" "quick detects inventory change" || return 1
  assert_contains "$(report_field added)" "deploy/new-page.md" "quick reports the added page" || return 1
  assert_no_file "${STATE_DIR}/last-full-run" "quick must not write last-full-run" || return 1
  assert_eq '[]' "$(report_field fetch_errors)" "quick records no fetch errors"
}
