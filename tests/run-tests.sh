#!/usr/bin/env bash
#
# Test runner for the AAE plugin.
#
# Usage:
#   tests/run-tests.sh                 run every case
#   tests/run-tests.sh detector        run cases whose filename matches "detector"
#   VERBOSE=1 tests/run-tests.sh       show each case's stderr on failure
#
# A case file lives in tests/cases/ and defines shell functions named test_*.
# Each function runs in a fresh sandbox; a non-zero return is a failure.
#
# Exit codes: 0 = all passed, 1 = at least one failed, 2 = no cases matched.

set -uo pipefail

TESTS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TESTS_ROOT
# shellcheck source=lib/harness.sh
. "${TESTS_ROOT}/lib/harness.sh"

FILTER="${1:-}"
PASSED=0
FAILED=0
FAILED_NAMES=()

run_case_file() {
  local file="$1" name
  name="$(basename "$file" .sh)"
  printf '\n%s\n' "$name"

  # Source in a subshell-free way so the test functions are visible, then
  # discover them. Each case file is independent.
  local fns
  # shellcheck disable=SC1090
  . "$file"
  fns="$(declare -F | awk '{print $3}' | grep '^test_' || true)"
  [ -n "$fns" ] || { printf '  (no test_* functions)\n'; return; }

  local fn
  while IFS= read -r fn; do
    new_sandbox
    local out rc
    # </dev/null so a test can never consume the here-string feeding this loop,
    # which would silently truncate the run after that test.
    out="$( "$fn" 2>&1 </dev/null )"
    rc=$?
    if [ "$rc" -eq 0 ]; then
      PASSED=$(( PASSED + 1 ))
      printf '  ok   %s\n' "${fn#test_}"
    else
      FAILED=$(( FAILED + 1 ))
      FAILED_NAMES+=("${name}::${fn#test_}")
      printf '  FAIL %s\n' "${fn#test_}"
      printf '%s\n' "$out" | sed 's/^/       /'
      if [ -n "${VERBOSE:-}" ] && [ -f "${SANDBOX}/stderr.log" ]; then
        printf '       --- watcher stderr ---\n'
        sed 's/^/       /' "${SANDBOX}/stderr.log"
      fi
    fi
    cleanup_sandbox
    unset -f "$fn"
  done <<< "$fns"
}

shopt -s nullglob
CASES=("${TESTS_ROOT}"/cases/*.sh)
shopt -u nullglob

MATCHED=0
for f in "${CASES[@]}"; do
  if [ -n "$FILTER" ]; then
    case "$(basename "$f")" in
      *"$FILTER"*) : ;;
      *) continue ;;
    esac
  fi
  MATCHED=$(( MATCHED + 1 ))
  run_case_file "$f"
done

if [ "$MATCHED" -eq 0 ]; then
  printf '\nno test cases matched %s\n' "${FILTER:-(all)}" >&2
  exit 2
fi

printf '\n---\n%d passed, %d failed\n' "$PASSED" "$FAILED"
if [ "$FAILED" -gt 0 ]; then
  printf 'failed:\n'
  printf '  %s\n' "${FAILED_NAMES[@]}"
  exit 1
fi
exit 0
