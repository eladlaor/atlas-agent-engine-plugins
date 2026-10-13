#!/usr/bin/env bash
#
# aae-cli-docs-check.sh — regression guard for the published agentengine CLI reference.
#
# The CLI reference pages under /docs/agentengine/cli/ are generated from the
# binary's own command tree: `agentengine docs generate <dir>` writes one Markdown
# page per command, the same pages the docs site publishes. So the binary is the
# authority, and any disagreement between the two is drift that nothing else
# announces.
#
# Measured 2026-10-13 at CLI 0.1.118: 117 generated pages, 121 published pages,
# 0 commands missing from the docs, 0 flag-level drift. The four extra published
# pages are hand-written guides, not command pages — see HANDWRITTEN_CLI_PAGES.
# This script is therefore a guard against a regression, not a discovery tool: a
# clean run is the expected result, and anything else is news.
#
# What it compares:
#   1. The command set — one page per command, binary vs published inventory.
#   2. The flag set per command, including each flag's short form.
#
# Both sides are lowercased before comparison, because published URLs are
# lowercase while the generated filenames follow the command spelling.
#
# Output: nothing on stdout while the two agree. On divergence it prints the
# diverging commands and flags on stderr and one machine-readable summary line on
# stdout. Progress logging always goes to stderr (silence it with --quiet).
#
# Exit codes: 0 = docs and binary agree, 30 = divergence found, 1 = error.

set -euo pipefail

readonly DOCS_BASE="https://www.mongodb.com/docs/agentengine"
readonly INVENTORY_URL="${DOCS_BASE}/llms.txt"
readonly CLI_DOCS_BASE="${DOCS_BASE}/cli"
readonly CURL_TIMEOUT=30
readonly PARALLEL=8
# Same problem as the docs watcher: a scheduled run can start before the network
# is up. Retry the first request rather than losing the check.
readonly NET_RETRIES="${AAE_CLI_DOCS_NET_RETRIES:-6}"
readonly NET_RETRY_DELAY="${AAE_CLI_DOCS_NET_RETRY_DELAY:-30}"

readonly EXIT_DIVERGED=30

# ---------------------------------------------------------------------------
# KNOWN NON-COMMAND PAGES — the allowlist. Keep this list current.
# ---------------------------------------------------------------------------
# These pages are published under cli/ but are NOT produced by
# `agentengine docs generate`, because they are hand-written guides rather than
# command reference pages. Reporting them as "published page with no command"
# would make every run noisy, so they are excluded by name.
#
# Verified by reading each page on 2026-10-13 (CLI 0.1.118):
#   artifact-registry-validate  Guide: validating a private artifact registry
#                               against the platform's requirements. Prose and a
#                               checklist, not a command.
#   custom-artifact-source      Guide: pointing builds at a custom artifact
#                               source. Configuration reference, not a command.
#   environment-variables       Reference: the environment variables the CLI
#                               reads. A table, not a command.
#   public-artifacts            Reference: the public artifact images and their
#                               registry paths. Not a command.
#
# To update: if one of these becomes a real command, delete its line — the guard
# will then require a matching generated page. If a new hand-written guide is
# published under cli/, add its page name (the URL basename, no .md) here with a
# one-line reason. AAE_CLI_DOCS_EXTRA_ALLOWLIST appends to this list at runtime
# (space-separated) for a one-off run, but a lasting addition belongs here.
readonly HANDWRITTEN_CLI_PAGES="
artifact-registry-validate
custom-artifact-source
environment-variables
public-artifacts
"

now() { date '+%Y-%m-%d %H:%M:%S %Z'; }
die() {
  printf '%s aae-cli-docs-check: ERROR: %s\n' "$(now)" "$1" >&2
  exit 1
}
log() { [ -n "${AAE_CLI_DOCS_QUIET:-}" ] || printf '%s %s\n' "$(now)" "$1" >&2; }

PRINT_SUMMARY=""

usage() {
  cat <<'USAGE'
Usage: aae-cli-docs-check.sh [--summary] [--quiet] [-h]

Compare the agentengine CLI binary's own command tree against the published CLI
reference pages, and report any command or flag the two disagree about.

  --summary   Also print the summary line when the two agree (by default a clean
              run prints nothing on stdout).
  --quiet     Suppress progress logging on stderr.

Exit: 0 docs and binary agree, 30 divergence found, 1 error.

Environment (all optional):
  AAE_CLI_DOCS_GENERATED_DIR    Use this directory of generated pages instead of
                                running `agentengine docs generate`. Offline mode.
  AAE_CLI_DOCS_PUBLISHED_DIR    Read the published pages from this local directory
                                (one <command>.md per page) instead of the docs
                                site. Offline mode. An optional .cli-version file
                                in it records the CLI version the corpus was taken
                                from, and is reported as the published-side version.
  AAE_CLI_DOCS_BINARY_VERSION   Binary version to report when AAE_CLI_DOCS_GENERATED_DIR
                                is set and the binary is not available.
  AAE_CLI_DOCS_EXTRA_ALLOWLIST  Space-separated extra hand-written page names to
                                treat as known non-command pages for this run.
  AAE_CLI_DOCS_NET_RETRIES      Retries for the first network request. Default 6.
  AAE_CLI_DOCS_NET_RETRY_DELAY  Seconds between those retries. Default 30.
  AAE_CLI_DOCS_QUIET            Non-empty: same as --quiet.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --summary) PRINT_SUMMARY="1" ;;
    --quiet)   AAE_CLI_DOCS_QUIET="1"; export AAE_CLI_DOCS_QUIET ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
  shift
done

command -v curl >/dev/null 2>&1 || die "curl not found on PATH (${PATH})"
command -v awk  >/dev/null 2>&1 || die "awk not found on PATH (${PATH})"

WORK_DIR="$(mktemp -d)" || die "cannot create temp dir"
# shellcheck disable=SC2329  # invoked by the EXIT trap below
cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Flag extraction
# ---------------------------------------------------------------------------
# A naive `grep -o -- '--[a-z0-9-]*'` over a page is wrong twice over: it matches
# the `---` of a Markdown horizontal rule and of front-matter delimiters, and it
# matches flags named inside prose, including the `\--auto` escaping the docs
# pipeline emits when a paragraph starts with a flag. Both produce flags that
# exist on one side only, which reads as drift that is not there.
#
# So extraction is structural, not textual. Only fenced code blocks that follow an
# "Options" or "Options inherited from parent commands" heading are read — the
# heading level differs between the two sides (### generated, ## published), so
# any level matches — and within those blocks a flag must sit at the start of its
# own line, optionally behind its short form. A horizontal rule has no letter
# after the two dashes and an em dash is not two ASCII hyphens, so neither can
# match; a flag named in a description sits mid-line, so it cannot match either.
#
# Each flag is emitted as its canonical token: "-h,--help" when it has a short
# form, "--json" when it does not, so that a dropped short form is drift too.
extract_flags() {
  local page="$1"
  awk '
    /^[[:space:]]*#+[[:space:]]+Options([[:space:]]+inherited[[:space:]]+from[[:space:]]+parent[[:space:]]+commands)?[[:space:]]*$/ {
      in_options = 1; in_fence = 0; next
    }
    /^[[:space:]]*#+[[:space:]]/ { if (!in_fence) in_options = 0; next }
    /^[[:space:]]*```/ { if (in_options) in_fence = !in_fence; next }
    {
      if (!in_options || !in_fence) next
      if (match($0, /^[[:space:]]*-[A-Za-z],[[:space:]]+--[A-Za-z0-9][A-Za-z0-9-]*/)) {
        token = substr($0, RSTART, RLENGTH)
        gsub(/[[:space:]]/, "", token)
        print token
      } else if (match($0, /^[[:space:]]*--[A-Za-z0-9][A-Za-z0-9-]*/)) {
        token = substr($0, RSTART, RLENGTH)
        gsub(/[[:space:]]/, "", token)
        print token
      }
    }
  ' "$page" | tr '[:upper:]' '[:lower:]' | sort -u
}

# ---------------------------------------------------------------------------
# Step 1: the binary's side
# ---------------------------------------------------------------------------
BINARY_VERSION=""
GENERATED_DIR=""
if [ -n "${AAE_CLI_DOCS_GENERATED_DIR:-}" ]; then
  GENERATED_DIR="$AAE_CLI_DOCS_GENERATED_DIR"
  [ -d "$GENERATED_DIR" ] \
    || die "AAE_CLI_DOCS_GENERATED_DIR is not a directory: ${GENERATED_DIR}"
  BINARY_VERSION="${AAE_CLI_DOCS_BINARY_VERSION:-}"
  if [ -z "$BINARY_VERSION" ] && command -v agentengine >/dev/null 2>&1; then
    BINARY_VERSION="$(agentengine --version 2>/dev/null | tr -d ' \n')"
  fi
  [ -n "$BINARY_VERSION" ] || BINARY_VERSION="unknown"
  log "generated pages: using ${GENERATED_DIR} (binary version ${BINARY_VERSION})"
else
  command -v agentengine >/dev/null 2>&1 \
    || die "agentengine not found on PATH (${PATH}); install the CLI or set AAE_CLI_DOCS_GENERATED_DIR"
  BINARY_VERSION="$(agentengine --version 2>/dev/null | tr -d ' \n')" \
    || die "'agentengine --version' failed"
  [ -n "$BINARY_VERSION" ] || die "'agentengine --version' printed nothing"
  GENERATED_DIR="${WORK_DIR}/generated"
  mkdir -p "$GENERATED_DIR" || die "cannot create ${GENERATED_DIR}"
  # NOTE: `docs generate` takes a positional directory, not --dir.
  agentengine docs generate "$GENERATED_DIR" > "${WORK_DIR}/generate.log" 2>&1 \
    || die "'agentengine docs generate ${GENERATED_DIR}' failed: $(tr '\n' ' ' < "${WORK_DIR}/generate.log")"
  log "generated pages from agentengine ${BINARY_VERSION}"
fi

GENERATED_SET="${WORK_DIR}/generated.set"
find "$GENERATED_DIR" -maxdepth 1 -type f -name '*.md' -exec basename {} .md \; \
  | tr '[:upper:]' '[:lower:]' | sort -u > "$GENERATED_SET"
generated_count="$(wc -l < "$GENERATED_SET" | tr -d ' ')"
[ "$generated_count" -gt 0 ] \
  || die "parsed 0 generated command pages from ${GENERATED_DIR} — the generator's output layout may have changed"
log "binary: ${generated_count} command pages"

# ---------------------------------------------------------------------------
# Step 2: the published side
# ---------------------------------------------------------------------------
# The published inventory comes from llms.txt. It is NOT a complete inventory of
# the docs site in general — it omits pages elsewhere — but for cli/ it was
# complete when measured (121 of 121). If that stops being true, the symptom is
# commands reported as missing from the docs that are in fact published, so treat
# a sudden crop of "missing" entries as a question about llms.txt first.
PUBLISHED_SET="${WORK_DIR}/published.set"
PUBLISHED_DIR="${WORK_DIR}/published"
mkdir -p "$PUBLISHED_DIR" || die "cannot create ${PUBLISHED_DIR}"
PUBLISHED_SOURCE=""
PUBLISHED_VERSION="unversioned"

if [ -n "${AAE_CLI_DOCS_PUBLISHED_DIR:-}" ]; then
  [ -d "$AAE_CLI_DOCS_PUBLISHED_DIR" ] \
    || die "AAE_CLI_DOCS_PUBLISHED_DIR is not a directory: ${AAE_CLI_DOCS_PUBLISHED_DIR}"
  PUBLISHED_SOURCE="$AAE_CLI_DOCS_PUBLISHED_DIR"
  PUBLISHED_DIR="$AAE_CLI_DOCS_PUBLISHED_DIR"
  find "$PUBLISHED_DIR" -maxdepth 1 -type f -name '*.md' -exec basename {} .md \; \
    | tr '[:upper:]' '[:lower:]' | sort -u > "$PUBLISHED_SET"
  if [ -f "${PUBLISHED_DIR}/.cli-version" ]; then
    PUBLISHED_VERSION="$(tr -d ' \n' < "${PUBLISHED_DIR}/.cli-version")"
  fi
else
  PUBLISHED_SOURCE="$INVENTORY_URL"
  inventory="${WORK_DIR}/llms.txt"
  attempt=1
  while :; do
    if http_code="$(curl -sL --max-time "$CURL_TIMEOUT" -o "$inventory" -w '%{http_code}' "$INVENTORY_URL")"; then
      break
    fi
    [ "$attempt" -lt "$NET_RETRIES" ] \
      || die "network failure fetching the inventory after ${NET_RETRIES} attempts: ${INVENTORY_URL}"
    log "network not reachable (attempt ${attempt}/${NET_RETRIES}); retrying in ${NET_RETRY_DELAY}s"
    sleep "$NET_RETRY_DELAY"
    attempt=$(( attempt + 1 ))
  done
  [ "$http_code" = "200" ] || die "inventory returned HTTP ${http_code}: ${INVENTORY_URL}"
  [ -s "$inventory" ] || die "inventory is empty: ${INVENTORY_URL}"
  grep -o 'agentengine/cli/[A-Za-z0-9_.-]*\.md' "$inventory" \
    | sed -e 's|.*/||' -e 's|\.md$||' \
    | tr '[:upper:]' '[:lower:]' | sort -u > "$PUBLISHED_SET" || true
fi

published_count="$(wc -l < "$PUBLISHED_SET" | tr -d ' ')"
[ "$published_count" -gt 0 ] \
  || die "parsed 0 published CLI pages from ${PUBLISHED_SOURCE} — refusing to report agreement on an empty corpus"
log "docs: ${published_count} published cli pages (source ${PUBLISHED_SOURCE})"

# ---------------------------------------------------------------------------
# Step 3: command-set comparison
# ---------------------------------------------------------------------------
ALLOWLIST="${WORK_DIR}/allowlist.set"
{ printf '%s\n' "$HANDWRITTEN_CLI_PAGES"
  printf '%s\n' "${AAE_CLI_DOCS_EXTRA_ALLOWLIST:-}"
} | tr '[:blank:]' '\n' | sed '/^[[:space:]]*$/d' | tr '[:upper:]' '[:lower:]' | sort -u > "$ALLOWLIST"

MISSING_FROM_DOCS="$(comm -23 "$GENERATED_SET" "$PUBLISHED_SET" || true)"
EXTRA_IN_DOCS="$(comm -13 "$GENERATED_SET" "$PUBLISHED_SET" | comm -23 - "$ALLOWLIST" || true)"
COMMON="${WORK_DIR}/common.set"
comm -12 "$GENERATED_SET" "$PUBLISHED_SET" > "$COMMON" || true
common_count="$(wc -l < "$COMMON" | tr -d ' ')"
[ "$common_count" -gt 0 ] \
  || die "no command page exists on both sides — the page-naming convention has probably changed; refusing to report agreement"

# ---------------------------------------------------------------------------
# Step 4: fetch the published bodies for the commands both sides know
# ---------------------------------------------------------------------------
if [ -z "${AAE_CLI_DOCS_PUBLISHED_DIR:-}" ]; then
  log "fetching ${common_count} published pages (${PARALLEL} parallel)…"
  FETCHER="${WORK_DIR}/fetch.sh"
  cat > "$FETCHER" <<'FETCH'
#!/bin/sh
cmd="$1"
out="${PUBLISHED_DIR}/${cmd}.md"
code=$(curl -sL --retry 2 --retry-delay 2 --max-time "$CURL_TIMEOUT" \
         -o "$out" -w '%{http_code}' "${CLI_DOCS_BASE}/${cmd}.md" 2>/dev/null) || code="000"
if [ "$code" = "200" ] && [ -s "$out" ]; then
  printf '%s\tok\n' "$cmd"
else
  rm -f "$out"
  printf '%s\thttp_%s\n' "$cmd" "$code"
fi
FETCH
  chmod +x "$FETCHER"
  export PUBLISHED_DIR CLI_DOCS_BASE CURL_TIMEOUT
  xargs -P "$PARALLEL" -n 1 "$FETCHER" < "$COMMON" > "${WORK_DIR}/fetch.tsv" \
    || die "fetching the published pages failed"
  fetch_errors="$(awk -F'\t' '$2!="ok" {print $1" ("$2")"}' "${WORK_DIR}/fetch.tsv" || true)"
  # A fetch failure means this run could not check those commands. Never call that
  # clean: stop, so a network problem can't read as agreement.
  [ -z "$fetch_errors" ] \
    || die "could not fetch $(printf '%s\n' "$fetch_errors" | wc -l | tr -d ' ') published page(s); the comparison is incomplete: $(printf '%s' "$fetch_errors" | tr '\n' ' ')"
fi

# ---------------------------------------------------------------------------
# Step 5: flag-set comparison, per command
# ---------------------------------------------------------------------------
FLAG_DRIFT="${WORK_DIR}/flag-drift.txt"
: > "$FLAG_DRIFT"
checked_commands=0
checked_flags=0
while IFS= read -r cmd; do
  [ -n "$cmd" ] || continue
  gen_page="${GENERATED_DIR}/${cmd}.md"
  pub_page="${PUBLISHED_DIR}/${cmd}.md"
  # The generated filename keeps the command's own spelling; the set was
  # lowercased for comparison, so fall back to a case-insensitive lookup.
  [ -f "$gen_page" ] || gen_page="$(find "$GENERATED_DIR" -maxdepth 1 -type f -iname "${cmd}.md" | head -1)"
  [ -f "$pub_page" ] || pub_page="$(find "$PUBLISHED_DIR" -maxdepth 1 -type f -iname "${cmd}.md" | head -1)"
  [ -n "$gen_page" ] && [ -f "$gen_page" ] || die "generated page for '${cmd}' vanished from ${GENERATED_DIR}"
  [ -n "$pub_page" ] && [ -f "$pub_page" ] || die "published page for '${cmd}' is missing from ${PUBLISHED_DIR}"

  extract_flags "$gen_page" > "${WORK_DIR}/gen.flags"
  extract_flags "$pub_page" > "${WORK_DIR}/pub.flags"
  n_gen="$(wc -l < "${WORK_DIR}/gen.flags" | tr -d ' ')"
  n_pub="$(wc -l < "${WORK_DIR}/pub.flags" | tr -d ' ')"
  # Every agentengine command carries at least -h/--help plus the inherited
  # flags, so zero parsed flags means the page layout changed under us.
  if [ "$n_gen" -eq 0 ] && [ "$n_pub" -eq 0 ]; then
    die "parsed 0 flags from both sides for '${cmd}' — the Options section layout has changed; refusing to report agreement"
  fi
  only_gen="$(comm -23 "${WORK_DIR}/gen.flags" "${WORK_DIR}/pub.flags" | tr '\n' ' ' | sed 's/ *$//')"
  only_pub="$(comm -13 "${WORK_DIR}/gen.flags" "${WORK_DIR}/pub.flags" | tr '\n' ' ' | sed 's/ *$//')"
  [ -z "$only_gen" ] || printf '%s\tmissing_from_docs\t%s\n' "$cmd" "$only_gen" >> "$FLAG_DRIFT"
  [ -z "$only_pub" ] || printf '%s\tnot_in_binary\t%s\n' "$cmd" "$only_pub" >> "$FLAG_DRIFT"
  checked_commands=$(( checked_commands + 1 ))
  checked_flags=$(( checked_flags + n_gen ))
done < "$COMMON"

# ---------------------------------------------------------------------------
# Step 6: report
# ---------------------------------------------------------------------------
count_lines() { [ -z "$1" ] && printf '0' || printf '%s' "$(printf '%s\n' "$1" | sed '/^$/d' | wc -l | tr -d ' ')"; }

n_missing="$(count_lines "$MISSING_FROM_DOCS")"
n_extra="$(count_lines "$EXTRA_IN_DOCS")"
n_flag_drift="$(wc -l < "$FLAG_DRIFT" | tr -d ' ')"
total=$(( n_missing + n_extra + n_flag_drift ))

summary="$(printf 'status=%s binary_version=%s docs_cli_version=%s docs_source=%s commands_binary=%s commands_published=%s commands_checked=%s flags_checked=%s missing_from_docs=%s undocumented_commands=%s flag_drift=%s' \
  "$([ "$total" -eq 0 ] && printf 'agree' || printf 'diverged')" \
  "$BINARY_VERSION" "$PUBLISHED_VERSION" "$PUBLISHED_SOURCE" \
  "$generated_count" "$published_count" "$checked_commands" "$checked_flags" \
  "$n_missing" "$n_extra" "$n_flag_drift")"

if [ "$total" -eq 0 ]; then
  log "agree: ${checked_commands} commands, ${checked_flags} flags, 0 drift (binary ${BINARY_VERSION})"
  # A zero-drift result only proves agreement with the binary it was run against.
  # Both versions are in the summary line so a stale binary cannot be mistaken
  # for a current all-clear.
  [ -z "$PRINT_SUMMARY" ] || printf '%s\n' "$summary"
  exit 0
fi

{
  printf '%s aae-cli-docs-check: DIVERGENCE between agentengine %s and the published CLI reference (%s)\n' \
    "$(now)" "$BINARY_VERSION" "$PUBLISHED_SOURCE"
  if [ "$n_missing" -gt 0 ]; then
    printf '\n  Commands in the binary with no published page (%s):\n' "$n_missing"
    printf '%s\n' "$MISSING_FROM_DOCS" | sed '/^$/d' | sed 's|^|    |'
  fi
  if [ "$n_extra" -gt 0 ]; then
    printf '\n  Published pages with no such command (%s) — add to HANDWRITTEN_CLI_PAGES if hand-written:\n' "$n_extra"
    printf '%s\n' "$EXTRA_IN_DOCS" | sed '/^$/d' | sed 's|^|    |'
  fi
  if [ "$n_flag_drift" -gt 0 ]; then
    printf '\n  Flag drift (%s entries):\n' "$n_flag_drift"
    while IFS=$'\t' read -r cmd kind flags; do
      case "$kind" in
        missing_from_docs) printf '    %s: in the binary, absent from the docs: %s\n' "$cmd" "$flags" ;;
        not_in_binary)     printf '    %s: in the docs, absent from the binary: %s\n' "$cmd" "$flags" ;;
      esac
    done < "$FLAG_DRIFT"
  fi
  printf '\n'
} >&2

printf '%s\n' "$summary"
exit "$EXIT_DIVERGED"
