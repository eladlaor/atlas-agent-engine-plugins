#!/usr/bin/env bash
#
# aae-release-check.sh — has the agentengine CLI or an Agent Engine SDK been
# released past the versions the knowledge base was last verified against?
#
# WHY THIS EXISTS
#
# The docs watcher diffs the documentation repository, and nothing else. The CLI
# ships on its own cadence (the GitHub release body is the only CLI changelog that
# exists), the SDKs ship to PyPI and npm, and aae-cli-docs-check.sh only ever ran
# by hand against whatever binary happened to be installed. A daily job could
# therefore run clean for weeks while the knowledge base fell several CLI releases
# behind. This script closes that gap by comparing what has been RELEASED against
# what the knowledge base is STAMPED with (aae-kb-read/kb-versions.json).
#
# What it does:
#   1. Reads the CLI releases from GitHub, and the latest version of each SDK
#      package from PyPI and npm. Unauthenticated; GITHUB_TOKEN is sent to the
#      GitHub API only, and only when it is set.
#   2. Compares each against the stamp with semantic-version precedence.
#      Drift = released > stamped.
#   3. Writes release-report.json (one line), release-notes.md (the body of every
#      CLI release newer than the stamp, newest first) and a section of
#      changes-summary.md.
#   4. On CLI drift, downloads the latest binary for this host into the state
#      directory (cached by version), verifies it, and runs aae-cli-docs-check.sh
#      against THAT binary rather than the installed one. It never installs or
#      upgrades anything (BEHAVIOR_SPEC FR-9).
#
# Verification of a downloaded binary, in order:
#   - its SHA-256 against the digest the GitHub release API publishes. A mismatch
#     refuses the binary.
#   - macOS: `codesign --verify --strict`, and the signing Team ID must match
#     AAE_RELEASE_CODESIGN_TEAM. MongoDB publishes no .sig for macOS builds; the
#     binaries are code-signed instead. A failure refuses the binary.
#   - Linux: the detached .sig, with gpg, when gpg is installed and the key is in
#     the keyring. A bad signature refuses the binary; an unverifiable one is
#     recorded as unverified and the binary is still used.
#
# Exit codes: 0 = no drift, 10 = drift found, 20 = skipped, 1 = error.

set -euo pipefail

# --------------------------------------------------------------------------
# Constants
# --------------------------------------------------------------------------

readonly GH_RELEASES_API="${AAE_RELEASE_GH_API:-https://api.github.com/repos/mongodb/agent-engine-client-libraries/releases?per_page=50}"
readonly PYPI_BASE="${AAE_RELEASE_PYPI_BASE:-https://pypi.org/pypi}"
readonly NPM_BASE="${AAE_RELEASE_NPM_BASE:-https://registry.npmjs.org}"
readonly PYPI_PACKAGES="agent-engine-sdk-langgraph agent-engine-sdk-adk agent-engine-sdk-memory agent-engine-runner-shared agent-engine-sdk-openai-agents"
readonly NPM_PACKAGES="@mongodb-js/agent-engine-sdk-langgraph @mongodb-js/agent-engine-sdk-memory @mongodb-js/agent-engine-runner-shared"
readonly CURL_TIMEOUT=30
readonly DOWNLOAD_TIMEOUT=600
# A scheduled run can start before the network is up. Retry the first request
# rather than losing the day, as the docs watchers do.
readonly NET_RETRIES="${AAE_RELEASE_NET_RETRIES:-6}"
readonly NET_RETRY_DELAY="${AAE_RELEASE_NET_RETRY_DELAY:-30}"
# The Apple Team ID that signs the macOS agentengine builds (read from the 0.1.120
# and 0.1.126 binaries with `codesign -dv`, 2026-11-24).
readonly CODESIGN_TEAM="${AAE_RELEASE_CODESIGN_TEAM:-4XWMY46275}"
readonly KB_STAMP_NAME="kb-versions.json"
readonly KB_STAMP_SUBPATH="plugins/aae/skills/aae-kb-read/${KB_STAMP_NAME}"
readonly SUMMARY_MARKER="<!-- aae-release-check -->"

STATE_DIR="${AAE_WATCH_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/aae-docs-watch}"
readonly STATE_DIR
readonly REPORT_FILE="${STATE_DIR}/release-report.json"
readonly NOTES_FILE="${STATE_DIR}/release-notes.md"
readonly ERROR_FILE="${STATE_DIR}/release-check-error"
readonly LAST_RUN_FILE="${STATE_DIR}/release-last-run"
readonly SUMMARY_FILE="${STATE_DIR}/changes-summary.md"
readonly BIN_CACHE_DIR="${STATE_DIR}/cli-bin"
readonly CDC_LOG_FILE="${STATE_DIR}/release-cli-docs-check.log"

readonly EXIT_DRIFT=10
readonly EXIT_SKIPPED=20

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly CLI_DOCS_CHECK="${AAE_RELEASE_CLI_DOCS_CHECK:-${SCRIPT_DIR}/aae-cli-docs-check.sh}"

SKIP_IF_RAN_TODAY=""
RUN_CLI_DOCS_CHECK=1

# --------------------------------------------------------------------------
# Logging and failure
# --------------------------------------------------------------------------

now() { date '+%Y-%m-%d %H:%M:%S %Z'; }

log() {
  [ -n "${AAE_WATCH_QUIET:-}" ] && return 0
  printf '%s  aae-release-check: %s\n' "$(now)" "$*" >&2
  return 0
}

die() {
  mkdir -p "$STATE_DIR" 2>/dev/null || true
  printf '%s\t%s\n' "$(now)" "$*" > "$ERROR_FILE" 2>/dev/null || true
  printf '%s  aae-release-check: ERROR: %s\n' "$(now)" "$*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage: aae-release-check.sh [--skip-if-ran-today] [--no-cli-docs-check] [-h]

Compares the latest agentengine CLI release (GitHub) and the latest Agent Engine
SDK packages (PyPI, npm) against the knowledge base's version stamp,
aae-kb-read/kb-versions.json. On CLI drift it downloads that release's binary for
this host into the state directory and runs aae-cli-docs-check.sh against it.

  --skip-if-ran-today   Exit 20 if a check already completed today.
  --no-cli-docs-check   On CLI drift, report it without downloading the binary.
  -h, --help            This text.

Writes, in the state directory: release-report.json (one line),
release-notes.md (only while the CLI has drifted), and a release section of
changes-summary.md. A failure writes release-check-error.

Exit codes: 0 no drift, 10 drift found, 20 skipped, 1 error.

Environment:
  AAE_WATCH_STATE_DIR            State directory (shared with the docs watchers)
  AAE_RELEASE_KB_VERSIONS        The stamp to compare against. Default: the clone's
                                 (AAE_KB_REPO), else the plugin's, else the
                                 scheduled copy beside this script.
  GITHUB_TOKEN                   Sent to the GitHub API only, when set.
  AAE_RELEASE_GH_API             CLI releases URL (tests)
  AAE_RELEASE_PYPI_BASE          PyPI JSON API base (tests)
  AAE_RELEASE_NPM_BASE           npm registry base (tests)
  AAE_RELEASE_PLATFORM           Binary platform, e.g. darwin_arm64 (default: this host)
  AAE_RELEASE_CLI_DOCS_CHECK     The guard to run (default: beside this script)
  AAE_RELEASE_CODESIGN_TEAM      Expected macOS signing Team ID
  AAE_RELEASE_SKIP_PLATFORM_SIGNATURE  Non-empty: skip codesign/gpg (tests only;
                                 the SHA-256 digest is still checked)
  AAE_RELEASE_NET_RETRIES        Retries for the first request (default 6)
  AAE_RELEASE_NET_RETRY_DELAY    Seconds between them (default 30)
  AAE_WATCH_QUIET                Suppress progress logging
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --skip-if-ran-today) SKIP_IF_RAN_TODAY=1 ;;
    --no-cli-docs-check) RUN_CLI_DOCS_CHECK="" ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
  shift
done

command -v curl >/dev/null 2>&1 || die "curl not found on PATH (${PATH})"
command -v python3 >/dev/null 2>&1 || die "python3 not found on PATH (${PATH})"
mkdir -p "$STATE_DIR" || die "cannot create state directory ${STATE_DIR}"

if [ -n "$SKIP_IF_RAN_TODAY" ] && [ -f "$LAST_RUN_FILE" ]; then
  if [ "$(cut -d' ' -f1 < "$LAST_RUN_FILE")" = "$(date '+%Y-%m-%d')" ]; then
    log "a release check already completed today; skipping"
    printf 'status=skipped last_run=%s report=%s\n' "$(cat "$LAST_RUN_FILE")" "$REPORT_FILE"
    exit "$EXIT_SKIPPED"
  fi
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/aae-release-check.XXXXXX")" || die "cannot create a temp dir"
# shellcheck disable=SC2329  # invoked by the EXIT trap below
cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT
readonly CURL_ERR="${WORK_DIR}/curl.err"
: > "$CURL_ERR"

# --------------------------------------------------------------------------
# The stamp
# --------------------------------------------------------------------------

resolve_stamp() {
  if [ -n "${AAE_RELEASE_KB_VERSIONS:-}" ]; then
    printf '%s' "$AAE_RELEASE_KB_VERSIONS"
  elif [ -n "${AAE_KB_REPO:-}" ]; then
    # The clone is what the --update-kb runner edits, so its stamp is the one
    # that moves when drift is applied.
    printf '%s' "${AAE_KB_REPO}/${KB_STAMP_SUBPATH}"
  elif [ -f "${SCRIPT_DIR}/../skills/aae-kb-read/${KB_STAMP_NAME}" ]; then
    printf '%s' "${SCRIPT_DIR}/../skills/aae-kb-read/${KB_STAMP_NAME}"
  else
    # The scheduled copy, installed beside this script by install-schedule.sh.
    printf '%s' "${SCRIPT_DIR}/${KB_STAMP_NAME}"
  fi
}

STAMP_FILE="$(resolve_stamp)"
readonly STAMP_FILE
[ -f "$STAMP_FILE" ] || die "knowledge-base version stamp not found: ${STAMP_FILE} (set AAE_RELEASE_KB_VERSIONS, or re-run install-schedule.sh install)"

# --------------------------------------------------------------------------
# HTTP
# --------------------------------------------------------------------------

# http_get <url> <out> [github] — sets HTTP_CODE; returns non-zero only when curl
# itself failed (no connection, timeout), so the caller can tell a network that is
# not up yet from a server that answered with an error.
HTTP_CODE="000"
http_get() {
  local url="$1" out="$2" github="${3:-}"
  local -a args=(-sS -L --max-time "$CURL_TIMEOUT" -o "$out" -w '%{http_code}')
  HTTP_CODE="000"
  if [ -n "$github" ]; then
    args+=(-H 'Accept: application/vnd.github+json' -H 'X-GitHub-Api-Version: 2022-11-28')
  fi
  if [ -n "$github" ] && [ -n "${GITHUB_TOKEN:-}" ]; then
    # Through a file descriptor, so the token never appears in the process list.
    HTTP_CODE="$(curl "${args[@]}" -H @<(printf 'Authorization: Bearer %s\n' "$GITHUB_TOKEN") "$url" 2>>"$CURL_ERR")" || return 1
  else
    HTTP_CODE="$(curl "${args[@]}" "$url" 2>>"$CURL_ERR")" || return 1
  fi
}

last_curl_error() { tail -1 "$CURL_ERR" 2>/dev/null | tr -d '\n'; }

# get_required <label> <url> <out> — any failure is fatal.
get_required() {
  local label="$1" url="$2" out="$3"
  http_get "$url" "$out" \
    || die "network failure fetching ${label}: ${url} ($(last_curl_error))"
  [ "$HTTP_CODE" = "200" ] || die "${label} returned HTTP ${HTTP_CODE}: ${url}"
  [ -s "$out" ] || die "${label} returned an empty body: ${url}"
}

safe_name() { printf '%s' "$1" | tr '/@' '__'; }

# --------------------------------------------------------------------------
# Step 1: what has been released
# --------------------------------------------------------------------------

log "reading CLI releases"
attempt=1
while ! http_get "$GH_RELEASES_API" "${WORK_DIR}/releases.json" github; do
  [ "$attempt" -lt "$NET_RETRIES" ] \
    || die "network failure fetching CLI releases after ${NET_RETRIES} attempt(s): ${GH_RELEASES_API} ($(last_curl_error))"
  log "network not reachable (attempt ${attempt}/${NET_RETRIES}); retrying in ${NET_RETRY_DELAY}s"
  sleep "$NET_RETRY_DELAY"
  attempt=$(( attempt + 1 ))
done
if [ "$HTTP_CODE" != "200" ]; then
  hint=""
  case "$HTTP_CODE" in
    403|429) hint=" (GitHub's unauthenticated limit is 60 requests an hour per IP address; set GITHUB_TOKEN to raise it)" ;;
  esac
  die "CLI releases returned HTTP ${HTTP_CODE}: ${GH_RELEASES_API}${hint}"
fi

log "reading SDK versions from PyPI and npm"
for pkg in $PYPI_PACKAGES; do
  get_required "PyPI ${pkg}" "${PYPI_BASE}/${pkg}/json" "${WORK_DIR}/pypi-$(safe_name "$pkg").json"
done
for pkg in $NPM_PACKAGES; do
  get_required "npm ${pkg}" "${NPM_BASE}/${pkg}/latest" "${WORK_DIR}/npm-$(safe_name "$pkg").json"
done

# --------------------------------------------------------------------------
# Step 2: compare against the stamp
# --------------------------------------------------------------------------

host_platform() {
  local os arch
  case "$(uname -s)" in
    Darwin) os="darwin" ;;
    Linux) os="linux" ;;
    *) return 1 ;;
  esac
  case "$(uname -m)" in
    arm64|aarch64) arch="arm64" ;;
    x86_64|amd64) arch="x86_64" ;;
    *) return 1 ;;
  esac
  printf '%s_%s' "$os" "$arch"
}

PLATFORM="${AAE_RELEASE_PLATFORM:-$(host_platform || true)}"
readonly PLATFORM

# The analysis prints KEY=VALUE lines for this script and writes the full result to
# analysis.json for the finishing step. -I: it reads downloaded JSON, so nothing
# from the working directory may shadow a module.
ANALYSIS="${WORK_DIR}/analysis.json"
analysis_out="$(python3 -I - "$WORK_DIR" "$STAMP_FILE" "$PLATFORM" "$PYPI_PACKAGES" "$NPM_PACKAGES" "$ANALYSIS" <<'PY' 2>"${WORK_DIR}/analysis.err"
import json, os, re, sys

work, stamp_path, platform, pypi_pkgs, npm_pkgs, out_path = sys.argv[1:7]

def fail(msg):
    print(msg, file=sys.stderr)
    sys.exit(1)

SEMVER = re.compile(r"^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$")
# PyPI publishes PEP 440 pre-releases (0.12.0rc1, 0.12.0.dev1); they sort below the release.
PEP440_PRE = re.compile(r"^(\d+)\.(\d+)\.(\d+)\.?(a|b|rc|dev)(\d+)$")

def version_key(v, where):
    """Semantic-version precedence: a pre-release sorts below its release."""
    if not isinstance(v, str):
        fail(f"not a version string: {v!r} ({where})")
    m = SEMVER.match(v.strip())
    if m:
        major, minor, patch, pre = m.groups()
        if pre is None:
            return (int(major), int(minor), int(patch), 1, ())
        ids = tuple((0, int(p), "") if p.isdigit() else (1, 0, p) for p in pre.split("."))
        return (int(major), int(minor), int(patch), 0, ids)
    m = PEP440_PRE.match(v.strip())
    if m:
        major, minor, patch, kind, num = m.groups()
        return (int(major), int(minor), int(patch), 0, ((1, 0, kind), (0, int(num), "")))
    fail(f"not a semantic version: {v!r} ({where})")

def load(path, where):
    try:
        with open(path) as fh:
            return json.load(fh)
    except (OSError, ValueError) as exc:
        fail(f"cannot parse {where}: {exc}")

stamp = load(stamp_path, f"the version stamp {stamp_path}")
for key in ("cli", "sdk_python", "sdk_npm", "verified_at"):
    if key not in stamp:
        fail(f"the version stamp {stamp_path} has no {key!r}")
for key in ("cli", "sdk_python", "sdk_npm"):
    version_key(stamp[key], f"stamp {key}")

releases = load(os.path.join(work, "releases.json"), "the CLI releases list")
if not isinstance(releases, list):
    fail(f"the CLI releases list is not a list: {str(releases)[:200]}")
cli = []
for rel in releases:
    tag = rel.get("tag_name", "")
    # Only plain vX.Y.Z tags are CLI releases; drafts and pre-releases are not released.
    if rel.get("draft") or rel.get("prerelease") or not re.match(r"^v\d+\.\d+\.\d+$", tag):
        continue
    cli.append(rel)
if not cli:
    fail("no vX.Y.Z CLI release found in the releases list — has the tag format changed?")
cli.sort(key=lambda r: version_key(r["tag_name"], "release tag"), reverse=True)
stamp_cli = version_key(stamp["cli"], "stamp cli")
newer = [r for r in cli if version_key(r["tag_name"], "release tag") > stamp_cli]
latest = cli[0]
latest_version = latest["tag_name"][1:]

asset_name = f"agentengine_{latest_version}_{platform}" if platform else ""
asset = next((a for a in latest.get("assets", []) if a.get("name") == asset_name), None)
sig = next((a for a in latest.get("assets", []) if a.get("name") == asset_name + ".sig"), None)

def package_versions(names, prefix, field_path, stamp_key):
    out, drifted = {}, []
    for name in names.split():
        safe = name.replace("/", "_").replace("@", "_")
        data = load(os.path.join(work, f"{prefix}-{safe}.json"), f"{prefix} {name}")
        value = data
        for part in field_path:
            if not isinstance(value, dict) or part not in value:
                fail(f"{prefix} {name}: no {'.'.join(field_path)} in the response")
            value = value[part]
        version_key(value, f"{prefix} {name}")
        out[name] = value
        if version_key(value, name) > version_key(stamp[stamp_key], f"stamp {stamp_key}"):
            drifted.append(name)
    return out, drifted

pypi, pypi_drift = package_versions(pypi_pkgs, "pypi", ("info", "version"), "sdk_python")
npm, npm_drift = package_versions(npm_pkgs, "npm", ("version",), "sdk_npm")

key_parts = []
if newer:
    key_parts.append(f"cli={latest_version}")
key_parts += [f"pypi:{n}={pypi[n]}" for n in pypi_drift]
key_parts += [f"npm:{n}={npm[n]}" for n in npm_drift]
status = "drift" if key_parts else "clean"

result = {
    "status": status,
    "stamp": {k: stamp[k] for k in ("cli", "sdk_python", "sdk_npm", "verified_at")},
    "stamp_file": stamp_path,
    "latest": {
        "cli": latest_version,
        "cli_published_at": latest.get("published_at", ""),
        "pypi": pypi,
        "npm": npm,
    },
    "drift": {"cli": bool(newer), "sdk_python": pypi_drift, "sdk_npm": npm_drift},
    "drift_key": ";".join(key_parts),
    "newer_releases": [
        {"tag": r["tag_name"], "published_at": r.get("published_at", ""),
         "url": r.get("html_url", ""), "body": r.get("body") or ""}
        for r in newer
    ],
    "platform": platform,
}
with open(out_path, "w") as fh:
    json.dump(result, fh)

print(f"STATUS={status}")
print(f"CLI_DRIFT={1 if newer else 0}")
print(f"LATEST_CLI={latest_version}")
print(f"ASSET_URL={(asset or {}).get('browser_download_url', '')}")
print(f"ASSET_DIGEST={(asset or {}).get('digest', '') or ''}")
print(f"SIG_URL={(sig or {}).get('browser_download_url', '')}")
PY
)" || die "comparing releases with the stamp failed: $(tr '\n' ' ' < "${WORK_DIR}/analysis.err")"

STATUS=""; CLI_DRIFT=""; LATEST_CLI=""; ASSET_URL=""; ASSET_DIGEST=""; SIG_URL=""
while IFS='=' read -r key value; do
  case "$key" in
    STATUS) STATUS="$value" ;;
    CLI_DRIFT) CLI_DRIFT="$value" ;;
    LATEST_CLI) LATEST_CLI="$value" ;;
    ASSET_URL) ASSET_URL="$value" ;;
    ASSET_DIGEST) ASSET_DIGEST="$value" ;;
    SIG_URL) SIG_URL="$value" ;;
    *) die "unexpected analysis output line: ${key}" ;;
  esac
done <<EOF
$analysis_out
EOF
[ -n "$STATUS" ] && [ -n "$LATEST_CLI" ] || die "the release analysis returned no result"
log "status=${STATUS}, latest CLI ${LATEST_CLI}"

# --------------------------------------------------------------------------
# Step 3: on CLI drift, check the published CLI reference against the new binary
# --------------------------------------------------------------------------

CDC_STATUS="not-run"
CDC_MESSAGE=""
CDC_SUMMARY=""
CDC_EXIT=""
CDC_BINARY=""
VERIFICATION=""

sha256_of() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | cut -d' ' -f1
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    return 1
  fi
}

# verify_binary <path> — sets VERIFICATION; returns 1 (with CDC_MESSAGE) to refuse.
verify_binary() {
  local bin="$1" actual expected team gpg_rc
  VERIFICATION=""
  if [ -n "$ASSET_DIGEST" ]; then
    expected="${ASSET_DIGEST#sha256:}"
    actual="$(sha256_of "$bin")" || { CDC_MESSAGE="no shasum or sha256sum to check the download"; return 1; }
    if [ "$actual" != "$expected" ]; then
      CDC_MESSAGE="SHA-256 mismatch for ${bin}: release says ${expected}, file is ${actual}; refused"
      return 1
    fi
    VERIFICATION="sha256 matches the release digest"
  else
    VERIFICATION="no release digest published"
  fi

  if [ -n "${AAE_RELEASE_SKIP_PLATFORM_SIGNATURE:-}" ]; then
    VERIFICATION="${VERIFICATION}; platform signature check skipped (AAE_RELEASE_SKIP_PLATFORM_SIGNATURE)"
    return 0
  fi
  case "$PLATFORM" in
    darwin_*)
      command -v codesign >/dev/null 2>&1 \
        || { CDC_MESSAGE="codesign not found; cannot verify the macOS binary"; return 1; }
      codesign --verify --strict "$bin" 2>"${WORK_DIR}/codesign.err" \
        || { CDC_MESSAGE="codesign rejected ${bin}: $(tr '\n' ' ' < "${WORK_DIR}/codesign.err")"; return 1; }
      team="$(codesign -dv "$bin" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
      [ "$team" = "$CODESIGN_TEAM" ] \
        || { CDC_MESSAGE="${bin} is signed by Team ID ${team:-none}, expected ${CODESIGN_TEAM}; refused"; return 1; }
      VERIFICATION="${VERIFICATION}; codesign valid, Team ID ${team}"
      ;;
    linux_*)
      if [ -z "$SIG_URL" ]; then
        VERIFICATION="${VERIFICATION}; no .sig published, signature not verified"
      elif ! command -v gpg >/dev/null 2>&1; then
        VERIFICATION="${VERIFICATION}; .sig published but gpg is not installed, signature not verified"
      else
        get_required ".sig for ${LATEST_CLI}" "$SIG_URL" "${WORK_DIR}/agentengine.sig"
        gpg_rc=0
        gpg --verify "${WORK_DIR}/agentengine.sig" "$bin" >/dev/null 2>"${WORK_DIR}/gpg.err" || gpg_rc=$?
        case "$gpg_rc" in
          0) VERIFICATION="${VERIFICATION}; gpg signature valid" ;;
          1) CDC_MESSAGE="BAD gpg signature for ${bin}; refused"; return 1 ;;
          *) VERIFICATION="${VERIFICATION}; .sig not verified ($(tail -1 "${WORK_DIR}/gpg.err" | tr -d '\n'))" ;;
        esac
      fi
      ;;
    *) VERIFICATION="${VERIFICATION}; no platform signature check for ${PLATFORM}" ;;
  esac
}

# fetch_binary — sets CDC_BINARY; returns 1 (with CDC_MESSAGE) on failure.
fetch_binary() {
  local dir="${BIN_CACHE_DIR}/${LATEST_CLI}" bin part
  bin="${dir}/agentengine"
  part="${bin}.part"
  mkdir -p "$dir" || { CDC_MESSAGE="cannot create ${dir}"; return 1; }
  if [ -f "$bin" ]; then
    log "using the cached ${LATEST_CLI} binary"
  else
    log "downloading agentengine ${LATEST_CLI} for ${PLATFORM}"
    rm -f "$part"
    curl -fsSL --max-time "$DOWNLOAD_TIMEOUT" -o "$part" "$ASSET_URL" 2>>"$CURL_ERR" \
      || { rm -f "$part"; CDC_MESSAGE="download failed: ${ASSET_URL} ($(last_curl_error))"; return 1; }
    mv "$part" "$bin" || { CDC_MESSAGE="cannot move the download into ${bin}"; return 1; }
  fi
  # Verified on every use, cached or not: the cache is a plain directory.
  if ! verify_binary "$bin"; then
    rm -f "$bin"
    return 1
  fi
  chmod 0755 "$bin" || { CDC_MESSAGE="cannot chmod ${bin}"; return 1; }
  CDC_BINARY="$bin"
}

if [ "$CLI_DRIFT" = "1" ]; then
  if [ -z "$RUN_CLI_DOCS_CHECK" ]; then
    CDC_STATUS="skipped"
    CDC_MESSAGE="--no-cli-docs-check"
  elif [ -z "$PLATFORM" ]; then
    CDC_STATUS="error"
    CDC_MESSAGE="unsupported host $(uname -s)/$(uname -m): no agentengine build to download"
  elif [ -z "$ASSET_URL" ]; then
    CDC_STATUS="error"
    CDC_MESSAGE="release v${LATEST_CLI} publishes no agentengine_${LATEST_CLI}_${PLATFORM} binary"
  elif [ ! -x "$CLI_DOCS_CHECK" ]; then
    CDC_STATUS="error"
    CDC_MESSAGE="aae-cli-docs-check.sh not found or not executable: ${CLI_DOCS_CHECK}"
  elif ! fetch_binary; then
    CDC_STATUS="error"
  else
    log "running the CLI reference check against ${CDC_BINARY}"
    CDC_EXIT=0
    CDC_SUMMARY="$("$CLI_DOCS_CHECK" --binary "$CDC_BINARY" --summary --quiet 2>"$CDC_LOG_FILE")" || CDC_EXIT=$?
    case "$CDC_EXIT" in
      0) CDC_STATUS="agree" ;;
      30) CDC_STATUS="diverged"; CDC_MESSAGE="details in ${CDC_LOG_FILE}" ;;
      *) CDC_STATUS="error"; CDC_MESSAGE="aae-cli-docs-check.sh exited ${CDC_EXIT}: $(grep -v '^[[:space:]]*$' "$CDC_LOG_FILE" | tail -1)" ;;
    esac
  fi
  if [ "$CDC_STATUS" = "error" ]; then
    log "CLI reference check: ${CDC_MESSAGE}"
  fi
fi

# --------------------------------------------------------------------------
# Step 4: report
# --------------------------------------------------------------------------

python3 -I - "$ANALYSIS" "$REPORT_FILE" "$NOTES_FILE" "$SUMMARY_FILE" "$SUMMARY_MARKER" \
  "$CDC_STATUS" "$CDC_MESSAGE" "$CDC_SUMMARY" "$CDC_EXIT" "$CDC_BINARY" "$VERIFICATION" \
  "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$(date '+%Y-%m-%d %H:%M %Z')" <<'PY' 2>"${WORK_DIR}/report.err" \
  || die "writing the release report failed: $(tr '\n' ' ' < "${WORK_DIR}/report.err")"
import json, os, sys

(analysis_path, report_path, notes_path, summary_path, marker,
 cdc_status, cdc_message, cdc_summary, cdc_exit, cdc_binary, verification,
 checked_at, local_time) = sys.argv[1:14]

with open(analysis_path) as fh:
    a = json.load(fh)
stamp, latest, drift = a["stamp"], a["latest"], a["drift"]
newer = a["newer_releases"]

report = {
    "checked_at": checked_at,
    "status": a["status"],
    "stamp": stamp,
    "latest": latest,
    "drift": drift,
    "drift_key": a["drift_key"],
    "cli_releases_newer": [{"tag": r["tag"], "published_at": r["published_at"]} for r in newer],
    "release_notes": notes_path if newer else None,
    "cli_docs_check": {
        "status": cdc_status,
        "binary": cdc_binary or None,
        "binary_version": latest["cli"] if cdc_binary else None,
        "verification": verification or None,
        "exit_code": int(cdc_exit) if cdc_exit else None,
        "summary": cdc_summary or None,
        "message": cdc_message or None,
    },
}
# One line, no spaces after separators: the same textual contract as report.json.
tmp = report_path + ".tmp"
with open(tmp, "w") as fh:
    fh.write(json.dumps(report, separators=(",", ":")) + "\n")
os.replace(tmp, report_path)

if newer:
    lines = [
        "# agentengine CLI releases newer than the knowledge base",
        "",
        f"Knowledge base stamped CLI {stamp['cli']} (verified {stamp['verified_at']}). "
        f"Newest first. Checked {local_time}.",
        "",
    ]
    for r in newer:
        lines += [f"## {r['tag']} — {r['published_at'][:10]}", "", r["url"], "", r["body"].strip(), ""]
    with open(notes_path, "w") as fh:
        fh.write("\n".join(lines) + "\n")
elif os.path.exists(notes_path):
    # Stale notes would be applied again by the knowledge-base runner.
    os.remove(notes_path)

section = [marker, "## CLI and SDK releases", "",
           f"Checked {local_time} against the knowledge-base stamp: CLI {stamp['cli']}, "
           f"Python SDK {stamp['sdk_python']}, npm SDK {stamp['sdk_npm']} (verified {stamp['verified_at']}).", ""]
if a["status"] == "clean":
    section.append(f"No release newer than the stamp. Latest CLI {latest['cli']}.")
else:
    if drift["cli"]:
        tags = ", ".join(f"{r['tag']} ({r['published_at'][:10]})" for r in newer)
        section.append(f"- CLI: {len(newer)} release(s) newer than {stamp['cli']}: {tags}. "
                       f"Release notes: `{notes_path}`")
        if cdc_status == "agree":
            section.append(f"- CLI reference check against agentengine {latest['cli']}: the published reference agrees.")
        elif cdc_status == "diverged":
            section.append(f"- CLI reference check against agentengine {latest['cli']}: DIVERGED. {cdc_summary} ({cdc_message})")
        else:
            section.append(f"- CLI reference check against agentengine {latest['cli']}: {cdc_status}. {cdc_message}")
    for name in drift["sdk_python"]:
        section.append(f"- Python SDK: {name} {latest['pypi'][name]} (stamp {stamp['sdk_python']})")
    for name in drift["sdk_npm"]:
        section.append(f"- npm SDK: {name} {latest['npm'][name]} (stamp {stamp['sdk_npm']})")

existing = ""
if os.path.exists(summary_path):
    with open(summary_path) as fh:
        existing = fh.read()
    # Replace this script's previous section; keep the docs watcher's part as it is.
    if marker in existing:
        existing = existing[: existing.index(marker)]
    existing = existing.rstrip("\n") + "\n\n" if existing.strip() else ""
with open(summary_path, "w") as fh:
    fh.write(existing + "\n".join(section) + "\n")
PY

rm -f "$ERROR_FILE"
date '+%Y-%m-%d %H:%M %Z' > "$LAST_RUN_FILE"

printf 'status=%s cli_latest=%s cli_stamp=%s cli_drift=%s sdk_drift=%s cli_docs_check=%s report=%s\n' \
  "$STATUS" "$LATEST_CLI" \
  "$(python3 -I -c 'import json,sys;print(json.load(open(sys.argv[1]))["stamp"]["cli"])' "$REPORT_FILE")" \
  "$CLI_DRIFT" \
  "$(python3 -I -c 'import json,sys;d=json.load(open(sys.argv[1]))["drift"];print(len(d["sdk_python"])+len(d["sdk_npm"]))' "$REPORT_FILE")" \
  "$CDC_STATUS" "$REPORT_FILE"

[ "$STATUS" = "drift" ] && exit "$EXIT_DRIFT"
exit 0
