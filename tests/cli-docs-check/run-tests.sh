#!/usr/bin/env bash
#
# run-tests.sh — entry point for the CLI reference regression guard's tests.
#
# Prefers bats-core. When bats is not installed it runs the very same
# cli_docs_check.bats file through a small built-in shim, so the suite is never
# blocked on a missing test framework and there is only ever one copy of the
# tests. The shim implements the part of the bats surface this suite uses:
# `@test` blocks, `setup`, `run`, `$status` and `$output`.
#
# Usage: tests/cli-docs-check/run-tests.sh [--no-bats]
# Exit:  0 all tests passed, 1 one or more failed.

set -uo pipefail

__SHIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly __SHIM_DIR
readonly BATS_FILE="${__SHIM_DIR}/cli_docs_check.bats"

FORCE_SHIM=""
[ "${1:-}" = "--no-bats" ] && FORCE_SHIM=1

[ -f "$BATS_FILE" ] || { printf 'ERROR: %s not found\n' "$BATS_FILE" >&2; exit 1; }

if [ -z "$FORCE_SHIM" ] && command -v bats >/dev/null 2>&1; then
  printf 'Running with bats-core (%s)\n' "$(bats --version 2>/dev/null)"
  exec bats "$BATS_FILE"
fi

printf 'bats-core not found on PATH — running the same suite through the built-in shim.\n'
printf 'Install bats for nicer output: brew install bats-core\n\n'

# ---------------------------------------------------------------------------
# The shim. Rewrite each `@test "name" { ... }` into a shell function, then
# source the result and run the functions one at a time.
# ---------------------------------------------------------------------------
GENERATED="$(mktemp -t aae-cli-docs-tests.XXXXXX)"
NAMES="$(mktemp -t aae-cli-docs-names.XXXXXX)"
trap 'rm -f "$GENERATED" "$NAMES"' EXIT

awk -v names="$NAMES" '
  /^@test[[:space:]]+/ {
    line = $0
    sub(/^@test[[:space:]]+/, "", line)
    # Strip the trailing " {" and the surrounding quotes around the name.
    sub(/[[:space:]]*\{[[:space:]]*$/, "", line)
    gsub(/^"|"$/, "", line)
    n++
    printf "%s\n", line >> names
    printf "__bats_test_%d() { # %s\n", n, line
    next
  }
  { print }
' "$BATS_FILE" > "$GENERATED"

test_count="$(wc -l < "$NAMES" | tr -d ' ')"
[ "$test_count" -gt 0 ] || { printf 'ERROR: the shim found no @test blocks in %s\n' "$BATS_FILE" >&2; exit 1; }

# bats' `run`: execute the command, never abort on failure, and expose its
# combined output as $output and its status as $status. Both are read by the test
# bodies sourced below, not by this file.
# shellcheck disable=SC2329,SC2034
run() {
  output="$("$@" 2>&1)"
  status=$?
  return 0
}

BATS_TEST_FILENAME="$BATS_FILE"
export BATS_TEST_FILENAME
# shellcheck source=/dev/null  # a temp file generated from the .bats suite
source "$GENERATED"

passed=0
failed=0
i=0
while IFS= read -r name; do
  i=$(( i + 1 ))
  if ( set +e
       BATS_TEST_FILENAME="$BATS_FILE"
       declare -F setup >/dev/null && setup
       "__bats_test_${i}" ) >/dev/null 2>&1; then
    printf ' ok %d %s\n' "$i" "$name"
    passed=$(( passed + 1 ))
  else
    printf ' not ok %d %s\n' "$i" "$name"
    # Re-run noisily so the failure is diagnosable.
    ( set +e
      BATS_TEST_FILENAME="$BATS_FILE"
      declare -F setup >/dev/null && setup
      set -x
      "__bats_test_${i}" ) 2>&1 | sed 's/^/     /'
    failed=$(( failed + 1 ))
  fi
done < "$NAMES"

printf '\n%d tests, %d passed, %d failed\n' "$test_count" "$passed" "$failed"
[ "$failed" -eq 0 ] || exit 1
exit 0
