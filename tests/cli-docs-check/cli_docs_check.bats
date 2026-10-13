#!/usr/bin/env bats
#
# Tests for plugins/aae/scripts/aae-cli-docs-check.sh — the CLI reference
# regression guard.
#
# Every test runs offline: AAE_CLI_DOCS_GENERATED_DIR and AAE_CLI_DOCS_PUBLISHED_DIR
# point at recorded fixtures, so nothing here touches the network or needs the
# agentengine binary.
#
# Run with bats:            bats tests/cli-docs-check
# Run without bats:         tests/cli-docs-check/run-tests.sh

setup() {
  TEST_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
  REPO_ROOT="$(cd "${TEST_DIR}/../.." && pwd)"
  SCRIPT="${REPO_ROOT}/plugins/aae/scripts/aae-cli-docs-check.sh"
  FIXTURES="${TEST_DIR}/fixtures"
  export AAE_CLI_DOCS_QUIET=1
  unset AAE_CLI_DOCS_EXTRA_ALLOWLIST AAE_CLI_DOCS_BINARY_VERSION || true
}

# Run the guard against a fixture pair. $1 = fixture directory name.
run_guard() {
  AAE_CLI_DOCS_GENERATED_DIR="${FIXTURES}/$1/generated" \
  AAE_CLI_DOCS_PUBLISHED_DIR="${FIXTURES}/$1/published" \
  run bash "$SCRIPT" --summary
}

@test "the script exists and is executable" {
  [ -x "$SCRIPT" ]
}

@test "--help exits 0 and documents the exit codes" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"30 divergence found"* ]]
}

@test "an unknown argument fails fast" {
  run bash "$SCRIPT" --nope
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown argument"* ]]
}

# --- Acceptance: the real recorded corpus -----------------------------------
# 117 generated pages, 121 published pages, CLI 0.1.118, recorded 2026-10-13.
# This is the test that proves the flag extraction is free of the `---` and
# em-dash false positives: the whole real corpus must come back with zero drift.

@test "real corpus: zero drift, exit 0" {
  run_guard real-corpus
  [ "$status" -eq 0 ]
  [[ "$output" == *"status=agree"* ]]
  [[ "$output" == *"flag_drift=0"* ]]
  [[ "$output" == *"missing_from_docs=0"* ]]
  [[ "$output" == *"undocumented_commands=0"* ]]
}

@test "real corpus: the measured command and flag counts are reproduced" {
  run_guard real-corpus
  [ "$status" -eq 0 ]
  [[ "$output" == *"commands_binary=117"* ]]
  [[ "$output" == *"commands_published=121"* ]]
  [[ "$output" == *"commands_checked=117"* ]]
}

@test "real corpus: both CLI versions appear in the summary" {
  run_guard real-corpus
  [ "$status" -eq 0 ]
  [[ "$output" == *"binary_version=0.1.118"* ]]
  [[ "$output" == *"docs_cli_version=0.1.118"* ]]
}

@test "a clean run prints nothing on stdout without --summary" {
  stdout="$(AAE_CLI_DOCS_GENERATED_DIR="${FIXTURES}/real-corpus/generated" \
            AAE_CLI_DOCS_PUBLISHED_DIR="${FIXTURES}/real-corpus/published" \
            bash "$SCRIPT" 2>/dev/null)"
  [ -z "$stdout" ]
}

# --- Divergence detection ---------------------------------------------------

@test "a flag removed from the docs is detected" {
  run_guard flag-removed
  [ "$status" -eq 30 ]
  [[ "$output" == *"flag_drift=1"* ]]
  [[ "$output" == *"agentengine_deploy"* ]]
  [[ "$output" == *"--json"* ]]
  [[ "$output" == *"status=diverged"* ]]
}

@test "the removed flag is caught even though prose still names it" {
  # The published fixture page still says "--json" in a paragraph. An extractor
  # that scraped the page text would call this clean; a structural one does not.
  grep -q -- '--json' "${FIXTURES}/flag-removed/published/agentengine_deploy.md"
  run_guard flag-removed
  [ "$status" -eq 30 ]
}

@test "a command with no published page is detected" {
  run_guard command-missing
  [ "$status" -eq 30 ]
  [[ "$output" == *"missing_from_docs=1"* ]]
  [[ "$output" == *"agentengine_build"* ]]
}

@test "divergence writes exactly one summary line to stdout" {
  stdout="$(AAE_CLI_DOCS_GENERATED_DIR="${FIXTURES}/command-missing/generated" \
            AAE_CLI_DOCS_PUBLISHED_DIR="${FIXTURES}/command-missing/published" \
            bash "$SCRIPT" 2>/dev/null || true)"
  [ "$(printf '%s\n' "$stdout" | wc -l | tr -d ' ')" -eq 1 ]
  [[ "$stdout" == status=diverged* ]]
}

# --- The hand-written guide allowlist ---------------------------------------

@test "hand-written guide pages alone do not count as divergence" {
  run_guard guides-only
  [ "$status" -eq 0 ]
  [[ "$output" == *"undocumented_commands=0"* ]]
  [[ "$output" == *"commands_published=7"* ]]
}

@test "a published page outside the allowlist is reported" {
  tmp="$(mktemp -d)"
  cp -R "${FIXTURES}/guides-only/generated" "${tmp}/generated"
  cp -R "${FIXTURES}/guides-only/published" "${tmp}/published"
  cp "${tmp}/published/agentengine_version.md" "${tmp}/published/agentengine_ghost.md"
  AAE_CLI_DOCS_GENERATED_DIR="${tmp}/generated" \
  AAE_CLI_DOCS_PUBLISHED_DIR="${tmp}/published" \
  run bash "$SCRIPT" --summary
  rm -rf "$tmp"
  [ "$status" -eq 30 ]
  [[ "$output" == *"undocumented_commands=1"* ]]
  [[ "$output" == *"agentengine_ghost"* ]]
}

@test "AAE_CLI_DOCS_EXTRA_ALLOWLIST silences a one-off extra page" {
  tmp="$(mktemp -d)"
  cp -R "${FIXTURES}/guides-only/generated" "${tmp}/generated"
  cp -R "${FIXTURES}/guides-only/published" "${tmp}/published"
  cp "${tmp}/published/agentengine_version.md" "${tmp}/published/agentengine_ghost.md"
  AAE_CLI_DOCS_GENERATED_DIR="${tmp}/generated" \
  AAE_CLI_DOCS_PUBLISHED_DIR="${tmp}/published" \
  AAE_CLI_DOCS_EXTRA_ALLOWLIST="agentengine_ghost" \
  run bash "$SCRIPT" --summary
  rm -rf "$tmp"
  [ "$status" -eq 0 ]
}

# --- False positives the naive extraction produced --------------------------

@test "horizontal rules and em-dash prose are not read as flags" {
  # The fixture adds `---`, `----`, an em dash, an escaped `\--auto` and two
  # invented flag names in prose, to one side only. A grep-based extractor would
  # report them as drift.
  run_guard false-positives
  [ "$status" -eq 0 ]
  [[ "$output" == *"flag_drift=0"* ]]
}

# --- Fail-fast behaviour ----------------------------------------------------

@test "a missing generated directory fails fast, not clean" {
  AAE_CLI_DOCS_GENERATED_DIR="/nonexistent/generated" \
  AAE_CLI_DOCS_PUBLISHED_DIR="${FIXTURES}/real-corpus/published" \
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not a directory"* ]]
}

@test "an empty published directory fails fast, not clean" {
  tmp="$(mktemp -d)"
  AAE_CLI_DOCS_GENERATED_DIR="${FIXTURES}/real-corpus/generated" \
  AAE_CLI_DOCS_PUBLISHED_DIR="$tmp" \
  run bash "$SCRIPT"
  rm -rf "$tmp"
  [ "$status" -eq 1 ]
  [[ "$output" == *"0 published CLI pages"* ]]
}

@test "a published corpus that shares no command name fails fast, not clean" {
  tmp="$(mktemp -d)"
  cp "${FIXTURES}/real-corpus/published/agentengine_deploy.md" "${tmp}/totally_other_name.md"
  AAE_CLI_DOCS_GENERATED_DIR="${FIXTURES}/real-corpus/generated" \
  AAE_CLI_DOCS_PUBLISHED_DIR="$tmp" \
  run bash "$SCRIPT"
  rm -rf "$tmp"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no command page exists on both sides"* ]]
}

@test "a page with no Options section fails fast, not clean" {
  tmp="$(mktemp -d)"
  mkdir -p "${tmp}/generated" "${tmp}/published"
  printf '# agentengine_deploy\n\nProse only, no options block.\n' \
    > "${tmp}/generated/agentengine_deploy.md"
  cp "${tmp}/generated/agentengine_deploy.md" "${tmp}/published/agentengine_deploy.md"
  AAE_CLI_DOCS_GENERATED_DIR="${tmp}/generated" \
  AAE_CLI_DOCS_PUBLISHED_DIR="${tmp}/published" \
  run bash "$SCRIPT"
  rm -rf "$tmp"
  [ "$status" -eq 1 ]
  [[ "$output" == *"parsed 0 flags from both sides"* ]]
}
