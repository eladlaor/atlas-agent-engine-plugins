#!/usr/bin/env bash
#
# The report.json contract.
#
# Why these tests exist: report.json is read TEXTUALLY in two places — the
# watcher's own --kb-update-only path greps for '"status":"changes"', and it
# recovers checked_at with a sed over the raw line. install-schedule.sh then
# hard-indexes ["status"] and ["counts"]. So the file's shape is not a
# formatting preference, it is an interface. Pretty-printing it, reordering it
# into something a parser would still accept, or renaming a key breaks shipped
# code silently. These tests fail if that happens.

EXPECTED_KEYS='added changed checked_at counts fetch_errors inventory_changed mode pages_total removed status'

seed_two_pages() {
  seed_page "build/install" "# Install"
  seed_page "deploy/invoke-agent" "# Invoke"
  start_server
}

test_report_has_exactly_the_contracted_keys() {
  seed_two_pages
  run_watcher --full

  local keys
  keys="$(python3 -c '
import json,sys
print(" ".join(sorted(json.load(open(sys.argv[1])).keys())))
' "${STATE_DIR}/report.json")"
  assert_eq "$EXPECTED_KEYS" "$keys" "report.json top-level keys" || return 1

  local count_keys
  count_keys="$(python3 -c '
import json,sys
print(" ".join(sorted(json.load(open(sys.argv[1]))["counts"].keys())))
' "${STATE_DIR}/report.json")"
  assert_eq "added changed removed" "$count_keys" "report.json counts keys"
}

# The two textual readers depend on the file being one compact line with no
# space after a colon. Assert that directly.
test_report_is_compact_and_single_line() {
  seed_two_pages
  run_watcher --full

  local lines; lines="$(wc -l < "${STATE_DIR}/report.json" | tr -d ' ')"
  assert_eq 1 "$lines" "report.json must be exactly one line" || return 1

  local body; body="$(cat "${STATE_DIR}/report.json")"
  assert_not_contains "$body" '": ' "report.json must have no space after a colon" || return 1
  assert_not_contains "$body" '", "' "report.json must have no space after a comma" || return 1

  # The exact greps the shipped code performs must match.
  grep -q '"status":"' "${STATE_DIR}/report.json" \
    || { fail "the --kb-update-only status grep would not match"; return 1; }
  local checked_at
  checked_at="$(sed -n 's/.*"checked_at":"\([^"]*\)".*/\1/p' "${STATE_DIR}/report.json")"
  [ -n "$checked_at" ] || { fail "the checked_at sed recovered nothing"; return 1; }
  # checked_at is the identity of a report; it must be UTC ISO-8601 to the second.
  printf '%s' "$checked_at" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' \
    || { fail "checked_at is not UTC ISO-8601: $checked_at"; return 1; }
}

test_report_value_domains() {
  seed_two_pages
  run_watcher --full

  # inventory_changed is a STRING, not a bool. Consumers compare it as text.
  local inv_type
  inv_type="$(python3 -c '
import json,sys
print(type(json.load(open(sys.argv[1]))["inventory_changed"]).__name__)
' "${STATE_DIR}/report.json")"
  assert_eq str "$inv_type" "inventory_changed must stay a string" || return 1

  local pt_type
  pt_type="$(python3 -c '
import json,sys
print(type(json.load(open(sys.argv[1]))["pages_total"]).__name__)
' "${STATE_DIR}/report.json")"
  assert_eq int "$pt_type" "pages_total must stay a number" || return 1

  # added/removed/changed carry absolute page URLs, not slugs. The hook splits
  # on "/docs/agentengine/" for display, so a bare slug would break it.
  seed_page "deploy/brand-new" "# New"
  regenerate_inventory
  run_watcher --full
  local added; added="$(report_field added)"
  assert_contains "$added" "${DOCS_BASE}/deploy/brand-new.md" \
    "added[] must hold absolute URLs"
}

# The exit-code table is an interface: the launchd job and the hook branch on it.
test_exit_code_table() {
  seed_two_pages

  run_watcher --full
  assert_eq 0 "$RUN_RC" "baseline run exits 0" || return 1

  run_watcher --full
  assert_eq 0 "$RUN_RC" "clean run exits 0" || return 1

  seed_changed_page "build/install" "# Install

Changed."
  run_watcher --full
  assert_eq 10 "$RUN_RC" "changes run exits 10" || return 1

  run_watcher --nonsense-flag
  assert_eq 1 "$RUN_RC" "unknown argument exits 1"
}

# Failure behaviour: an unreachable inventory must exit 1 and name the URL,
# never record an empty baseline.
test_unreachable_inventory_fails_loudly() {
  seed_two_pages
  run_watcher --full
  stop_server

  run_watcher --full
  assert_eq 1 "$RUN_RC" "unreachable inventory exits 1" || return 1
  assert_file "${STATE_DIR}/last-error" "unreachable inventory records last-error" || return 1
  local err; err="$(cat "${STATE_DIR}/last-error")"
  assert_contains "$err" "llms.txt" "last-error names the inventory URL"
}

# A changes report must clear the acknowledged marker, or the hook would stay
# silent about a brand-new change.
test_new_changes_report_clears_acknowledged() {
  seed_two_pages
  run_watcher --full
  touch "${STATE_DIR}/acknowledged"

  seed_changed_page "build/install" "# Install

Changed."
  run_watcher --full

  assert_eq 10 "$RUN_RC" "precondition: changes detected" || return 1
  assert_no_file "${STATE_DIR}/acknowledged" "a fresh changes report clears acknowledged"
}
