#!/usr/bin/env bash
#
# The git-sourced detector.
#
# Two jobs here. First, prove it satisfies the SAME report.json contract as the
# hashing watcher, so the SessionStart notice, the aae-kb-update runner, the
# aae-scout gate and the launchd job keep working. Second, cover the things
# only a git source can get right or wrong: include fan-out resolved at the
# reported commit, the snooty.toml blast radius, filtering non-page commits,
# and refusing to report "clean" when the content has moved.

seed_base_site() {
  git_fixture_init
  git_fixture_page "build/install" "Install
=======

Run the installer."
  git_fixture_page "deploy/invoke-agent" "Invoke
======

POST to the invoke endpoint."
  git_fixture_page "add-features/memory-only" "Memory
======

.. include:: /includes/limitations/service-account.rst

pip install agentic-platform-memory"
  git_fixture_page "reference/limitations" "Limitations
==========

.. include:: /includes/limitations/service-account.rst"
  git_fixture_include "limitations/service-account" "A service account shares one memory identity."
  git_fixture_commit "seed"
}

test_baseline_then_clean() {
  seed_base_site
  run_git_watcher --full
  assert_eq 0 "$RUN_RC" "baseline exits 0" || return 1
  assert_eq baseline "$(report_field status)" "first run is baseline" || return 1
  assert_eq first-run "$(report_field inventory_changed)" "baseline inventory_changed" || return 1
  assert_eq 4 "$(report_field pages_total)" "pages_total counts published pages only" || return 1
  assert_report_contract "baseline" || return 1

  run_git_watcher --full
  assert_eq 0 "$RUN_RC" "no new commits exits 0" || return 1
  assert_eq clean "$(report_field status)" "no new commits is clean"
}

test_changed_page_reported_with_diff_and_provenance() {
  seed_base_site
  run_git_watcher --full

  git_fixture_page "add-features/memory-only" "Memory
======

.. include:: /includes/limitations/service-account.rst

pip install agent-engine-sdk-memory"
  git_fixture_commit "DOCSP-65094 Correct package name"
  run_git_watcher --full

  assert_eq 10 "$RUN_RC" "changes exit 10" || return 1
  assert_eq changes "$(report_field status)" "status" || return 1
  assert_eq 1 "$(report_field counts.changed)" "one page changed" || return 1
  assert_contains "$(report_field changed)" "add-features/memory-only.md" "changed[] URL" || return 1
  assert_report_contract "changes" || return 1

  assert_file "${STATE_DIR}/diffs/add-features__memory-only.md.diff" "diff written" || return 1
  local d; d="$(cat "${STATE_DIR}/diffs/add-features__memory-only.md.diff")"
  assert_contains "$d" "agent-engine-sdk-memory" "diff holds new text" || return 1

  # Provenance is the thing hashing can never produce.
  local s; s="$(cat "${STATE_DIR}/changes-summary.md")"
  assert_contains "$s" "DOCSP-65094 Correct package name" "summary names the commit"
}

test_added_and_removed_pages() {
  seed_base_site
  run_git_watcher --full

  git_fixture_page "deploy/brand-new" "New
==="
  git_fixture_rm "build/install"
  git_fixture_commit "add one, remove one"
  run_git_watcher --full

  assert_eq 10 "$RUN_RC" "exit 10" || return 1
  assert_contains "$(report_field added)" "deploy/brand-new.md" "added[]" || return 1
  assert_contains "$(report_field removed)" "build/install.md" "removed[]" || return 1
  assert_eq true "$(report_field inventory_changed)" "page set changed"
}

# A shared include is not a published page. Its change must land on every page
# that transcludes it — resolved at the reported commit, not at some other tree.
test_include_change_fans_out_to_consuming_pages() {
  seed_base_site
  run_git_watcher --full

  git_fixture_include "limitations/service-account" "A service account shares one memory identity across all users."
  git_fixture_commit "clarify the service-account limitation"
  run_git_watcher --full

  assert_eq 10 "$RUN_RC" "include change is a change" || return 1
  local changed; changed="$(report_field changed)"
  assert_contains "$changed" "add-features/memory-only.md" "fan-out hits first consumer" || return 1
  assert_contains "$changed" "reference/limitations.md" "fan-out hits second consumer" || return 1
  assert_eq 2 "$(report_field counts.changed)" "exactly the two consumers" || return 1
  # The include itself is not a page and must never be reported as one.
  assert_not_contains "$changed" "includes/" "the include is not a published page" || return 1
  local s; s="$(cat "${STATE_DIR}/changes-summary.md")"
  assert_contains "$s" "shared include" "summary explains the fan-out"
}

# The trap that a naive source/**/*.txt filter walks into: one line in
# snooty.toml changes every published page while touching no source file.
test_snooty_change_fans_out_site_wide() {
  seed_base_site
  run_git_watcher --full

  printf 'name = "agentengine"\ntitle = "Atlas Agent Engine"\n[constants]\nplatform-short = "AAE"\n' \
    > "${GIT_FIXTURE}/content/agentengine/snooty.toml"
  git_fixture_commit "rename the product constant"
  run_git_watcher --full

  assert_eq 10 "$RUN_RC" "snooty.toml edit is a change, not a no-op" || return 1
  assert_eq 4 "$(report_field counts.changed)" "all published pages affected" || return 1
  local s; s="$(cat "${STATE_DIR}/changes-summary.md")"
  assert_contains "$s" "snooty.toml" "summary names the cause"
}

# Taxonomy and other non-page files are noise: real example, commit 37fab6c1
# touched only source/facets.toml.
test_non_page_commit_is_filtered_as_noise() {
  seed_base_site
  run_git_watcher --full

  printf 'genre = "reference"\n' > "${GIT_FIXTURE}/content/agentengine/source/facets.toml"
  printf 'ignore me\n' > "${GIT_FIXTURE}/content/agentengine/README.md"
  git_fixture_commit "seed facets.toml"
  run_git_watcher --full

  assert_eq 0 "$RUN_RC" "a taxonomy-only commit is not a docs change" || return 1
  assert_eq clean "$(report_field status)" "status clean" || return 1
  assert_eq 0 "$(report_field counts.changed)" "no pages reported"
}

# One CLI release regenerates every cli/ page at once. All of them belong in
# changed[] (the contract), but the human summary must collapse them.
test_cli_regeneration_is_collapsed_in_the_summary() {
  seed_base_site
  local i
  for i in 1 2 3 4 5 6 7; do
    git_fixture_page "cli/agentengine_cmd${i}" "Command ${i}
=========="
  done
  git_fixture_commit "add the CLI reference"
  run_git_watcher --full

  for i in 1 2 3 4 5 6 7; do
    git_fixture_page "cli/agentengine_cmd${i}" "Command ${i}
==========

Regenerated for 0.1.119."
  done
  git_fixture_commit "CLI updates"
  run_git_watcher --full

  assert_eq 10 "$RUN_RC" "exit 10" || return 1
  assert_eq 7 "$(report_field counts.changed)" "every page stays in the contract" || return 1
  local s; s="$(cat "${STATE_DIR}/changes-summary.md")"
  assert_contains "$s" "CLI reference regenerated" "summary collapses the burst" || return 1
  assert_contains "$s" "7" "summary states how many pages"
}

# Retroactive history: the hashing watcher could only ever see changes after
# its own first crawl. A git baseline set to an older commit resolves what
# happened before this tool ever ran.
test_history_before_first_run_is_recoverable() {
  seed_base_site
  local first; first="$(git -C "$GIT_FIXTURE" rev-parse HEAD)"

  git_fixture_page "build/install" "Install
=======

Run the new installer."
  git_fixture_commit "change that predates the watcher"

  # First ever run of the tool happens AFTER the change landed.
  run_git_watcher --full
  assert_eq baseline "$(report_field status)" "first run is still a baseline" || return 1

  # Re-point the baseline at the older commit: the change is recoverable.
  printf '%s\n' "$first" > "${STATE_DIR}/last-commit"
  run_git_watcher --full
  assert_eq 10 "$RUN_RC" "the earlier change is recoverable" || return 1
  assert_contains "$(report_field changed)" "build/install.md" "recovered the page"
}

# If the content path moves, reporting "clean" would be a silent permanent
# blind spot. It must fail loudly instead.
test_moved_content_path_fails_loudly() {
  git_fixture_init
  git_fixture_page "build/install" "Install
======="
  git_fixture_commit "seed"
  run_git_watcher --full
  assert_eq baseline "$(report_field status)" "precondition" || return 1

  git -C "$GIT_FIXTURE" rm -rq content/agentengine
  mkdir -p "${GIT_FIXTURE}/content/somewhere-else"
  printf 'moved\n' > "${GIT_FIXTURE}/content/somewhere-else/x.txt"
  git_fixture_commit "move the docs"
  run_git_watcher --full

  assert_eq 1 "$RUN_RC" "a moved content path must fail, never report clean" || return 1
  assert_file "${STATE_DIR}/last-error" "records last-error"
}

test_quick_mode_reports_without_resolving_pages() {
  seed_base_site
  run_git_watcher --full

  git_fixture_page "build/install" "Install
=======

Changed."
  git_fixture_commit "an edit"
  # The --full above legitimately wrote this marker; clear it so the assertion
  # below tests what --quick does, not what --full already did.
  rm -f "${STATE_DIR}/last-full-run"
  run_git_watcher --quick

  assert_eq quick "$(report_field mode)" "mode recorded" || return 1
  assert_report_contract "quick" || return 1
  assert_no_file "${STATE_DIR}/last-full-run" "quick must not write last-full-run"
}

test_skip_if_ran_today() {
  seed_base_site
  run_git_watcher --full --skip-if-ran-today
  assert_eq 0 "$RUN_RC" "first run crawls" || return 1
  assert_file "${STATE_DIR}/last-full-run" "writes last-full-run" || return 1

  local before; before="$(cat "${STATE_DIR}/report.json")"
  run_git_watcher --full --skip-if-ran-today
  assert_eq 20 "$RUN_RC" "same-day repeat exits 20" || return 1
  assert_eq "$before" "$(cat "${STATE_DIR}/report.json")" "report unchanged on skip" || return 1

  run_git_watcher --quick --skip-if-ran-today
  assert_eq 1 "$RUN_RC" "--quick with the flag is refused"
}
