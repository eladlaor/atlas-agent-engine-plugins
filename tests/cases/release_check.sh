#!/usr/bin/env bash
#
# The CLI and SDK release check (aae-release-check.sh), the daily entry point that
# runs it after the docs watcher (aae-daily-check.sh), and their consumers: the
# session notice, the knowledge-base runner's inputs and the launchd job.
#
# Everything runs against the harness's local HTTP server. Its files stand in for
# the GitHub releases API, PyPI's JSON API, the npm registry and the release
# download host; http.server ignores the query string, so the GitHub URL maps onto
# one file. The "binary" is a shell script that logs how it was called, which is
# how the tests prove that the CLI reference guard ran against the downloaded
# release rather than against whatever agentengine is installed.

readonly REL_PLATFORM="testos_arm64"
readonly REL_PYPI="agent-engine-sdk-langgraph agent-engine-sdk-adk agent-engine-sdk-memory agent-engine-runner-shared agent-engine-sdk-openai-agents"
readonly REL_NPM="agent-engine-sdk-langgraph agent-engine-sdk-memory agent-engine-runner-shared"
readonly REL_GUARD_FIXTURE="${TESTS_ROOT}/cli-docs-check/fixtures/guides-only"

# rel_stamp <cli> <sdk_python> <sdk_npm>
rel_stamp() {
  printf '{"cli":"%s","sdk_python":"%s","sdk_npm":"%s","verified_at":"2026-11-24"}\n' \
    "$1" "$2" "$3" > "${SANDBOX}/kb-versions.json"
}

# rel_packages <python-version> <npm-version> [<python-package>=<version>]...
rel_packages() {
  local py="$1" js="$2" pkg override name version
  shift 2
  for pkg in $REL_PYPI; do
    version="$py"
    for override in "$@"; do
      name="${override%%=*}"
      [ "$name" = "$pkg" ] && version="${override#*=}"
    done
    mkdir -p "${SERVE_DIR}/pypi/${pkg}"
    printf '{"info":{"name":"%s","version":"%s"}}\n' "$pkg" "$version" > "${SERVE_DIR}/pypi/${pkg}/json"
  done
  for pkg in $REL_NPM; do
    mkdir -p "${SERVE_DIR}/npm/@mongodb-js/${pkg}"
    printf '{"name":"@mongodb-js/%s","version":"%s"}\n' "$pkg" "$js" > "${SERVE_DIR}/npm/@mongodb-js/${pkg}/latest"
  done
}

# rel_fake_binary <version> — a stand-in agentengine that logs every call and
# generates the guides-only fixture's command pages.
rel_fake_binary() {
  local version="$1"
  mkdir -p "${SERVE_DIR}/dl"
  : > "${SANDBOX}/fake-agentengine.log"
  cat > "${SERVE_DIR}/dl/agentengine_${version}_${REL_PLATFORM}" <<FAKE
#!/bin/sh
printf '%s\n' "\$*" >> "${SANDBOX}/fake-agentengine.log"
case "\$1" in
  --version) echo "${version}" ;;
  docs) cp "${REL_GUARD_FIXTURE}/generated/"*.md "\$3/" ;;
  *) exit 2 ;;
esac
FAKE
}

# rel_releases <tag|date|draft|prerelease>... — newest first, as GitHub returns
# them. The newest non-draft, non-prerelease tag gets the binary asset and its
# real SHA-256 digest; REL_DIGEST overrides the digest.
rel_releases() {
  mkdir -p "${SERVE_DIR}/gh"
  python3 - "$DOCS_BASE" "$REL_PLATFORM" "${SERVE_DIR}/dl" "${REL_DIGEST:-}" "$@" \
    > "${SERVE_DIR}/gh/releases" <<'PY'
import hashlib, json, os, sys
base, platform, dl, digest_override = sys.argv[1:5]
out, asset_done = [], False
for spec in sys.argv[5:]:
    tag, date, draft, pre = spec.split("|")
    rel = {
        "tag_name": tag, "published_at": date, "draft": draft == "1", "prerelease": pre == "1",
        "html_url": f"https://example.invalid/releases/tag/{tag}",
        "body": f"## What's Changed\n\n- change shipped in {tag}\n", "assets": [],
    }
    name = f"agentengine_{tag[1:]}_{platform}"
    path = os.path.join(dl, name)
    if not asset_done and not rel["draft"] and not rel["prerelease"] and os.path.exists(path):
        digest = "sha256:" + hashlib.sha256(open(path, "rb").read()).hexdigest()
        rel["assets"].append({"name": name, "browser_download_url": f"{base}/dl/{name}",
                              "digest": digest_override or digest})
        asset_done = True
    out.append(rel)
json.dump(out, sys.stdout)
PY
}

rel_run() {
  set +e
  RUN_OUT="$(
    AAE_WATCH_STATE_DIR="$STATE_DIR" \
    AAE_WATCH_QUIET=1 \
    AAE_RELEASE_KB_VERSIONS="${SANDBOX}/kb-versions.json" \
    AAE_RELEASE_GH_API="${REL_GH_API:-${DOCS_BASE}/gh/releases?per_page=50}" \
    AAE_RELEASE_PYPI_BASE="${DOCS_BASE}/pypi" \
    AAE_RELEASE_NPM_BASE="${DOCS_BASE}/npm" \
    AAE_RELEASE_PLATFORM="${REL_PLATFORM_OVERRIDE:-$REL_PLATFORM}" \
    AAE_RELEASE_NET_RETRIES=1 AAE_RELEASE_NET_RETRY_DELAY=0 \
    AAE_CLI_DOCS_PUBLISHED_DIR="${REL_GUARD_FIXTURE}/published" \
    AAE_CLI_DOCS_QUIET=1 \
    "${REPO_ROOT}/plugins/aae/scripts/aae-release-check.sh" "$@" 2>"${SANDBOX}/stderr.log"
  )"
  RUN_RC=$?
  set -e
}

rel_field() {
  python3 -c '
import json,sys
v=json.load(open(sys.argv[1]))
for k in sys.argv[2].split("."):
    v=v[k]
print(json.dumps(v) if isinstance(v,(list,dict)) else v)
' "${STATE_DIR}/release-report.json" "$1"
}

# The common fixture: releases v0.1.125 to v0.1.127, a newer draft and pre-release
# that must be ignored, and every SDK at 0.11.15.
rel_fixture() {
  start_server || return 1
  rel_fake_binary 0.1.127
  rel_releases "v0.1.129|2026-11-30T00:00:00Z|1|0" \
               "v0.1.128|2026-11-29T00:00:00Z|0|1" \
               "v0.1.127|2026-11-26T00:00:00Z|0|0" \
               "v0.1.126|2026-11-19T00:00:00Z|0|0" \
               "v0.1.125|2026-11-11T00:00:00Z|0|0"
  rel_packages 0.11.15 0.11.15
}

# --------------------------------------------------------------------------
# The release check
# --------------------------------------------------------------------------

test_no_drift_exits_zero_and_writes_a_clean_report() {
  rel_fixture || return 1
  rel_stamp 0.1.127 0.11.15 0.11.15
  rel_run
  assert_eq 0 "$RUN_RC" "no drift exits 0" || return 1
  assert_eq clean "$(rel_field status)" "status" || return 1
  assert_eq 1 "$(wc -l < "${STATE_DIR}/release-report.json" | tr -d ' ')" "report is one line" || return 1
  assert_not_contains "$(cat "${STATE_DIR}/release-report.json")" '": ' "compact report" || return 1
  assert_eq not-run "$(rel_field cli_docs_check.status)" "no guard run without CLI drift" || return 1
  assert_no_file "${STATE_DIR}/release-notes.md" "no release notes without CLI drift" || return 1
  assert_no_file "${STATE_DIR}/release-check-error" "no error file" || return 1
  assert_eq "" "$(cat "${SANDBOX}/fake-agentengine.log")" "binary never run" || return 1
  assert_contains "$(cat "${STATE_DIR}/changes-summary.md")" "No release newer than the stamp" "summary section"
}

test_cli_drift_writes_notes_and_runs_the_guard_on_the_downloaded_binary() {
  rel_fixture || return 1
  rel_stamp 0.1.125 0.11.15 0.11.15
  printf '# Agent Engine docs changes\n\nCommits in range: docs part\n' > "${STATE_DIR}/changes-summary.md"

  rel_run
  assert_eq 10 "$RUN_RC" "CLI drift exits 10" || return 1
  assert_eq drift "$(rel_field status)" "status" || return 1
  assert_eq True "$(rel_field drift.cli)" "drift.cli" || return 1
  assert_eq 0.1.127 "$(rel_field latest.cli)" "draft and pre-release ignored" || return 1
  assert_eq '[{"tag": "v0.1.127", "published_at": "2026-11-26T00:00:00Z"}, {"tag": "v0.1.126", "published_at": "2026-11-19T00:00:00Z"}]' \
    "$(rel_field cli_releases_newer)" "exactly the releases newer than the stamp, newest first" || return 1

  local notes; notes="$(cat "${STATE_DIR}/release-notes.md")"
  assert_contains "$notes" "## v0.1.127 — 2026-11-26" "notes carry tag and date" || return 1
  assert_contains "$notes" "change shipped in v0.1.126" "notes carry the release body" || return 1
  assert_not_contains "$notes" "v0.1.125" "the stamped release is not newer" || return 1
  assert_not_contains "$notes" "v0.1.128" "a pre-release is not a release" || return 1
  local first second
  first="$(grep -n '^## v0.1.127' "${STATE_DIR}/release-notes.md" | cut -d: -f1)"
  second="$(grep -n '^## v0.1.126' "${STATE_DIR}/release-notes.md" | cut -d: -f1)"
  [ "$first" -lt "$second" ] || { fail "notes must be newest first"; return 1; }

  local bin="${STATE_DIR}/cli-bin/0.1.127/agentengine"
  assert_file "$bin" "binary cached by version" || return 1
  [ -x "$bin" ] || { fail "cached binary must be executable"; return 1; }
  assert_contains "$(cat "${SANDBOX}/fake-agentengine.log")" "docs generate" "the guard ran the downloaded binary" || return 1
  assert_eq agree "$(rel_field cli_docs_check.status)" "guard result recorded" || return 1
  assert_eq "$bin" "$(rel_field cli_docs_check.binary)" "guard binary recorded" || return 1
  assert_contains "$(rel_field cli_docs_check.verification)" "sha256 matches" "digest verified" || return 1

  local summary; summary="$(cat "${STATE_DIR}/changes-summary.md")"
  assert_contains "$summary" "Commits in range: docs part" "the docs watcher's part is kept" || return 1
  assert_contains "$summary" "2 release(s) newer than 0.1.125" "drift in the human summary" || return 1

  # A second run replaces its own section instead of appending another.
  rel_run
  assert_eq 1 "$(grep -c 'aae-release-check' "${STATE_DIR}/changes-summary.md")" "one release section" || return 1
  assert_contains "$(cat "${STATE_DIR}/changes-summary.md")" "Commits in range: docs part" "docs part still kept"
}

test_sdk_only_drift_reports_packages_and_downloads_nothing() {
  rel_fixture || return 1
  rel_packages 0.11.15 0.11.16 "agent-engine-sdk-adk=0.11.16"
  rel_stamp 0.1.127 0.11.15 0.11.15
  rel_run
  assert_eq 10 "$RUN_RC" "SDK drift exits 10" || return 1
  assert_eq False "$(rel_field drift.cli)" "no CLI drift" || return 1
  assert_eq '["agent-engine-sdk-adk"]' "$(rel_field drift.sdk_python)" "only the drifted Python package" || return 1
  assert_eq 3 "$(python3 -c 'import json,sys;print(len(json.load(open(sys.argv[1]))["drift"]["sdk_npm"]))' "${STATE_DIR}/release-report.json")" \
    "every npm package drifted" || return 1
  assert_eq not-run "$(rel_field cli_docs_check.status)" "no guard run" || return 1
  assert_no_file "${STATE_DIR}/release-notes.md" "no CLI notes" || return 1
  assert_no_file "${STATE_DIR}/cli-bin" "nothing downloaded" || return 1
  assert_contains "$(cat "${STATE_DIR}/changes-summary.md")" "agent-engine-sdk-adk 0.11.16" "SDK drift in the summary"
}

test_semver_comparison_is_numeric_not_textual() {
  start_server || return 1
  rel_fake_binary 0.1.10
  rel_releases "v0.1.10|2026-11-26T00:00:00Z|0|0" "v0.1.9|2026-11-19T00:00:00Z|0|0"
  rel_packages 0.11.15 0.11.15
  rel_stamp 0.1.9 0.11.15 0.11.15
  rel_run --no-cli-docs-check
  assert_eq 10 "$RUN_RC" "0.1.10 is newer than 0.1.9" || return 1
  assert_eq 0.1.10 "$(rel_field latest.cli)" "latest by precedence, not by text" || return 1
  assert_eq skipped "$(rel_field cli_docs_check.status)" "--no-cli-docs-check honoured"
}

test_network_error_exits_one_and_records_it() {
  start_server || return 1
  rel_packages 0.11.15 0.11.15
  rel_stamp 0.1.127 0.11.15 0.11.15
  local port
  port="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"
  REL_GH_API="http://127.0.0.1:${port}/releases" rel_run
  assert_eq 1 "$RUN_RC" "unreachable API exits 1" || return 1
  assert_file "${STATE_DIR}/release-check-error" "release-check-error written" || return 1
  assert_contains "$(cat "${STATE_DIR}/release-check-error")" "network failure" "error names the cause" || return 1
  assert_no_file "${STATE_DIR}/release-report.json" "no report from a failed run"
}

test_http_error_exits_one_and_keeps_the_previous_report() {
  rel_fixture || return 1
  rel_stamp 0.1.127 0.11.15 0.11.15
  rel_run
  assert_eq 0 "$RUN_RC" "precondition: a good run" || return 1
  local before; before="$(cat "${STATE_DIR}/release-report.json")"
  rm -f "${SERVE_DIR}/pypi/agent-engine-sdk-adk/json"
  rel_run
  assert_eq 1 "$RUN_RC" "a 404 exits 1" || return 1
  assert_contains "$(cat "${STATE_DIR}/release-check-error")" "HTTP 404" "error names the status" || return 1
  assert_eq "$before" "$(cat "${STATE_DIR}/release-report.json")" "the previous report stands"
}

test_digest_mismatch_refuses_the_binary() {
  start_server || return 1
  rel_fake_binary 0.1.127
  REL_DIGEST="sha256:0000000000000000000000000000000000000000000000000000000000000000" \
    rel_releases "v0.1.127|2026-11-26T00:00:00Z|0|0"
  rel_packages 0.11.15 0.11.15
  rel_stamp 0.1.126 0.11.15 0.11.15
  rel_run
  assert_eq 10 "$RUN_RC" "drift is still reported" || return 1
  assert_eq error "$(rel_field cli_docs_check.status)" "guard not run" || return 1
  assert_contains "$(rel_field cli_docs_check.message)" "SHA-256 mismatch" "mismatch named" || return 1
  assert_eq "" "$(cat "${SANDBOX}/fake-agentengine.log")" "a refused binary is never executed" || return 1
  assert_no_file "${STATE_DIR}/cli-bin/0.1.127/agentengine" "a refused binary is not kept"
}

test_unsigned_macos_binary_is_refused() {
  command -v codesign >/dev/null 2>&1 || return 0
  start_server || return 1
  # The fake is named for darwin_arm64 here, so the codesign check applies to it.
  mkdir -p "${SERVE_DIR}/dl"
  : > "${SANDBOX}/fake-agentengine.log"
  printf '#!/bin/sh\necho run >> "%s"\n' "${SANDBOX}/fake-agentengine.log" > "${SERVE_DIR}/dl/agentengine_0.1.127_darwin_arm64"
  python3 - "$DOCS_BASE" "${SERVE_DIR}/dl/agentengine_0.1.127_darwin_arm64" > "${SANDBOX}/releases.json" <<'PY'
import hashlib, json, sys
base, path = sys.argv[1:3]
digest = "sha256:" + hashlib.sha256(open(path, "rb").read()).hexdigest()
json.dump([{"tag_name": "v0.1.127", "published_at": "2026-11-26T00:00:00Z", "draft": False,
            "prerelease": False, "html_url": "", "body": "notes",
            "assets": [{"name": "agentengine_0.1.127_darwin_arm64", "digest": digest,
                        "browser_download_url": f"{base}/dl/agentengine_0.1.127_darwin_arm64"}]}], sys.stdout)
PY
  mkdir -p "${SERVE_DIR}/gh"; cp "${SANDBOX}/releases.json" "${SERVE_DIR}/gh/releases"
  rel_packages 0.11.15 0.11.15
  rel_stamp 0.1.126 0.11.15 0.11.15
  REL_PLATFORM_OVERRIDE=darwin_arm64 rel_run
  assert_eq 10 "$RUN_RC" "drift is still reported" || return 1
  assert_eq error "$(rel_field cli_docs_check.status)" "unsigned binary refused" || return 1
  assert_contains "$(rel_field cli_docs_check.message)" "codesign" "codesign named" || return 1
  assert_eq "" "$(cat "${SANDBOX}/fake-agentengine.log")" "a refused binary is never executed"
}

test_skip_if_ran_today() {
  rel_fixture || return 1
  rel_stamp 0.1.127 0.11.15 0.11.15
  rel_run --skip-if-ran-today
  assert_eq 0 "$RUN_RC" "first run checks" || return 1
  rel_run --skip-if-ran-today
  assert_eq 20 "$RUN_RC" "second run the same day skips" || return 1
  printf '2000-01-01 10:00 UTC\n' > "${STATE_DIR}/release-last-run"
  rel_run --skip-if-ran-today
  assert_eq 0 "$RUN_RC" "a run from another day does not skip"
}

test_a_bad_stamp_is_an_error() {
  rel_fixture || return 1
  printf '{"cli":"latest","sdk_python":"0.11.15","sdk_npm":"0.11.15","verified_at":"2026-11-24"}\n' \
    > "${SANDBOX}/kb-versions.json"
  rel_run
  assert_eq 1 "$RUN_RC" "a non-semver stamp exits 1" || return 1
  assert_contains "$(cat "${STATE_DIR}/release-check-error")" "not a semantic version" "names the problem"
}

test_the_shipped_stamp_is_valid() {
  local stamp="${REPO_ROOT}/plugins/aae/skills/aae-kb-read/kb-versions.json"
  python3 - "$stamp" <<'PY' || { fail "kb-versions.json is not a valid stamp"; return 1; }
import json, re, sys
d = json.load(open(sys.argv[1]))
assert set(d) == {"cli", "sdk_python", "sdk_npm", "verified_at"}, d
for k in ("cli", "sdk_python", "sdk_npm"):
    assert re.match(r"^\d+\.\d+\.\d+$", d[k]), (k, d[k])
assert re.match(r"^\d{4}-\d{2}-\d{2}$", d["verified_at"]), d
PY
}

# --------------------------------------------------------------------------
# Session notice
# --------------------------------------------------------------------------

rel_hook() {
  set +e
  RUN_OUT="$(
    AAE_WATCH_STATE_DIR="$STATE_DIR" AAE_WATCH_ON_SESSION=off HOME="$SANDBOX" \
    "${REPO_ROOT}/plugins/aae/scripts/session-notice.sh" 2>"${SANDBOX}/hook-stderr.log"
  )"
  RUN_RC=$?
  set -e
}

test_hook_shows_release_drift_once() {
  rel_fixture || return 1
  rel_stamp 0.1.125 0.11.15 0.11.15
  rel_run
  assert_eq 10 "$RUN_RC" "precondition: drift" || return 1

  rel_hook
  assert_eq 0 "$RUN_RC" "hook exits 0" || return 1
  python3 -c '
import json,sys
d=json.loads(sys.argv[1])
assert "CLI 0.1.127" in d["systemMessage"], d["systemMessage"]
ctx=d["hookSpecificOutput"]["additionalContext"]
assert "v0.1.127" in ctx and "release-notes.md" in ctx, ctx
' "$RUN_OUT" || { fail "hook output is not the contracted shape: $RUN_OUT"; return 1; }

  rel_hook
  assert_eq "" "$RUN_OUT" "the same drift is shown once" || return 1

  # A newer release is a new drift, shown again.
  rel_fake_binary 0.1.128
  rel_releases "v0.1.128|2026-11-29T00:00:00Z|0|0" "v0.1.127|2026-11-26T00:00:00Z|0|0"
  rel_run
  rel_hook
  assert_contains "$RUN_OUT" "CLI 0.1.128" "a new drift is shown"
}

test_hook_names_a_failed_release_check() {
  printf '2026-11-24 10:00:00 UTC\tCLI releases returned HTTP 403\n' > "${STATE_DIR}/release-check-error"
  rel_hook
  assert_eq 0 "$RUN_RC" "hook exits 0" || return 1
  assert_contains "$RUN_OUT" "release check failed" "health notice names the release check" || return 1
  assert_contains "$RUN_OUT" "403" "and carries the error"
}

# --------------------------------------------------------------------------
# The daily entry point, and the knowledge-base runner's inputs
# --------------------------------------------------------------------------

# A fake claude runner: records its prompt, then does what the skill asks of a
# successful run, recording every report key the prompt names.
rel_fake_runner() {
  mkdir -p "${SANDBOX}/bin"
  cat > "${SANDBOX}/bin/claude" <<FAKE
#!/bin/sh
prompt="\$2"
n=\$(ls "${SANDBOX}"/prompt-*.txt 2>/dev/null | wc -l | tr -d ' ')
printf '%s' "\$prompt" > "${SANDBOX}/prompt-\$n.txt"
for key in \$(printf '%s' "\$prompt" | grep -o 'under the key \`[^\`]*\`' | sed -e 's/under the key //' -e 's/\`//g'); do
  printf '%s\t2026-11-24\tdocs-auto\n' "\$key" >> "${STATE_DIR}/kb-update-processed"
done
for key in \$(printf '%s' "\$prompt" | grep -o 'Docs changes report: [^ ]* (checked_at=[^)]*' | sed 's/.*checked_at=//'); do
  printf '%s\t2026-11-24\tdocs-auto\n' "\$key" >> "${STATE_DIR}/kb-update-processed"
done
sleep 1
printf 'The release notes were applied; nothing else changed.\n' > "${STATE_DIR}/kb-update.md"
echo '{"total_cost_usd":0}'
FAKE
  chmod +x "${SANDBOX}/bin/claude"
}

rel_daily() {
  set +e
  RUN_OUT="$(
    PATH="${REL_DAILY_PATH:-/usr/bin:/bin}" \
    AAE_WATCH_STATE_DIR="$STATE_DIR" AAE_WATCH_QUIET=1 \
    AAE_WATCH_DOCS_REPO="$GIT_FIXTURE" \
    AAE_WATCH_DOCS_BASE="https://www.mongodb.com/docs/agentengine" \
    AAE_WATCH_NO_FETCH_PAGES=1 \
    AAE_RELEASE_KB_VERSIONS="${SANDBOX}/kb-versions.json" \
    AAE_RELEASE_GH_API="${REL_GH_API:-${DOCS_BASE}/gh/releases?per_page=50}" \
    AAE_RELEASE_PYPI_BASE="${DOCS_BASE}/pypi" \
    AAE_RELEASE_NPM_BASE="${DOCS_BASE}/npm" \
    AAE_RELEASE_PLATFORM="$REL_PLATFORM" \
    AAE_RELEASE_NET_RETRIES=1 AAE_RELEASE_NET_RETRY_DELAY=0 \
    AAE_CLI_DOCS_PUBLISHED_DIR="${REL_GUARD_FIXTURE}/published" AAE_CLI_DOCS_QUIET=1 \
    AAE_KB_SKILL="${REPO_ROOT}/plugins/aae/skills/aae-kb-update/SKILL.md" \
    AAE_KB_NOTES="${SANDBOX}/notes.md" \
    AAE_KB_REPO="${REL_KB_REPO:-}" \
    "${REPO_ROOT}/plugins/aae/scripts/aae-daily-check.sh" \
      --watcher "${REPO_ROOT}/plugins/aae/scripts/aae-docs-watch-git.sh" "$@" 2>"${SANDBOX}/stderr.log"
  )"
  RUN_RC=$?
  set -e
}

rel_docs_fixture() {
  git_fixture_init
  git_fixture_page "build/install" "Install
======="
  git_fixture_commit "seed"
}

test_daily_runs_the_release_check_after_the_docs_watcher() {
  rel_fixture || return 1
  rel_docs_fixture
  rel_stamp 0.1.125 0.11.15 0.11.15
  rel_daily
  assert_eq 10 "$RUN_RC" "release drift makes the day exit 10" || return 1
  assert_eq baseline "$(report_field status)" "the docs watcher ran" || return 1
  assert_eq drift "$(rel_field status)" "the release check ran" || return 1

  rel_daily
  assert_eq 20 "$RUN_RC" "both steps skip once they succeeded today"
}

test_a_failed_release_check_does_not_stop_the_docs_watcher() {
  rel_fixture || return 1
  rel_docs_fixture
  rel_stamp 0.1.127 0.11.15 0.11.15
  local port
  port="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"
  REL_GH_API="http://127.0.0.1:${port}/releases" rel_daily
  assert_eq 1 "$RUN_RC" "a failed step makes the day exit 1" || return 1
  assert_eq baseline "$(report_field status)" "the docs report is written" || return 1
  assert_file "${STATE_DIR}/last-full-run" "the docs run counts as done" || return 1
  assert_no_file "${STATE_DIR}/last-error" "the docs watcher did not fail" || return 1
  assert_file "${STATE_DIR}/release-check-error" "the release failure is recorded" || return 1

  # The hourly retry: the docs step skips (done today), the release step runs.
  rel_daily
  assert_eq 0 "$RUN_RC" "the retry skips the docs step and passes the release step" || return 1
  assert_no_file "${STATE_DIR}/release-check-error" "success clears the error"
}

test_update_kb_feeds_release_drift_to_the_runner_once() {
  rel_fixture || return 1
  rel_docs_fixture
  rel_stamp 0.1.125 0.11.15 0.11.15
  rel_fake_runner
  # A minimal plugin-repository clone, so the prompt carries the stamp-bump rule.
  REL_KB_REPO="${SANDBOX}/clone"
  mkdir -p "${REL_KB_REPO}/.git" "${REL_KB_REPO}/plugins/aae/skills/aae-kb-read/references"
  export REL_KB_REPO
  REL_DAILY_PATH="${SANDBOX}/bin:/usr/bin:/bin" rel_daily --update-kb
  assert_eq 10 "$RUN_RC" "exit 10" || return 1
  assert_no_file "${STATE_DIR}/kb-update-error" "the runner succeeded" || return 1
  assert_file "${SANDBOX}/prompt-0.txt" "the runner was started" || return 1
  local prompt; prompt="$(cat "${SANDBOX}/prompt-0.txt")"
  assert_contains "$prompt" "${STATE_DIR}/release-report.json" "prompt names the release report" || return 1
  assert_contains "$prompt" "${STATE_DIR}/release-notes.md" "prompt names the release notes" || return 1
  assert_contains "$prompt" "only to a version whose release notes" "prompt limits the stamp bump" || return 1
  assert_contains "$prompt" "Docs changes report: not part of this run" "a baseline docs report is not an input" || return 1
  local key="release:$(rel_field drift_key)"
  assert_contains "$(cat "${STATE_DIR}/kb-update-processed")" "$key" "release drift recorded as processed" || return 1

  # The next day's check reports the same drift under a new checked_at. It was
  # applied already, so no runner starts.
  REL_DAILY_PATH="${SANDBOX}/bin:/usr/bin:/bin" rel_daily --update-kb --force
  assert_eq 10 "$RUN_RC" "the drift is still reported" || return 1
  assert_no_file "${SANDBOX}/prompt-1.txt" "an applied drift is not applied again" || return 1
  assert_no_file "${STATE_DIR}/kb-update-error" "and that is not an error" || return 1

  # A new release is a new drift, and reaches the runner.
  rel_fake_binary 0.1.128
  rel_releases "v0.1.128|2026-11-29T00:00:00Z|0|0" "v0.1.127|2026-11-26T00:00:00Z|0|0"
  REL_DAILY_PATH="${SANDBOX}/bin:/usr/bin:/bin" rel_daily --update-kb --force
  assert_file "${SANDBOX}/prompt-1.txt" "a new drift starts the runner"
}

test_update_kb_without_runner_keeps_the_exit_code() {
  rel_fixture || return 1
  rel_docs_fixture
  rel_stamp 0.1.125 0.11.15 0.11.15
  rel_daily --update-kb
  assert_eq 10 "$RUN_RC" "a runner failure does not change the exit code" || return 1
  assert_file "${STATE_DIR}/kb-update-error" "the runner failure is recorded"
}

# --------------------------------------------------------------------------
# Scheduling
# --------------------------------------------------------------------------

rel_print_plist() {
  set +e
  RUN_OUT="$(HOME="$SANDBOX" AAE_WATCH_STATE_DIR="$STATE_DIR" \
    "${REPO_ROOT}/plugins/aae/scripts/install-schedule.sh" print-plist "$@" 2>"${SANDBOX}/stderr.log")"
  RUN_RC=$?
  set -e
}

test_the_scheduled_job_runs_the_daily_check() {
  [ "$(uname -s)" = Darwin ] || return 0
  rel_print_plist
  assert_eq 0 "$RUN_RC" "print-plist exits 0" || return 1
  printf '%s\n' "$RUN_OUT" > "${SANDBOX}/job.plist"
  plutil -lint "${SANDBOX}/job.plist" >/dev/null || { fail "plist does not lint"; return 1; }
  local args
  args="$(python3 -c 'import plistlib,sys;print(" ".join(plistlib.load(open(sys.argv[1],"rb"))["ProgramArguments"]))' "${SANDBOX}/job.plist")"
  assert_eq "${SANDBOX}/.local/share/aae-docs-watch/bin/aae-daily-check.sh --watcher ${SANDBOX}/.local/share/aae-docs-watch/bin/aae-docs-watch.sh" \
    "$args" "the job runs the daily check on the watcher copy" || return 1

  mkdir -p "${SANDBOX}/.local/bin"
  printf '#!/bin/sh\n' > "${SANDBOX}/.local/bin/claude"; chmod +x "${SANDBOX}/.local/bin/claude"
  rel_print_plist --update-kb
  assert_eq 0 "$RUN_RC" "print-plist --update-kb exits 0" || return 1
  assert_contains "$RUN_OUT" "<string>--update-kb</string>" "the flag reaches the daily check"
}

test_every_script_the_job_runs_is_copied_by_install() {
  local f
  for f in aae-daily-check.sh aae-release-check.sh aae-cli-docs-check.sh; do
    [ -x "${REPO_ROOT}/plugins/aae/scripts/${f}" ] || { fail "${f} is not executable"; return 1; }
    grep -q "$f" "${REPO_ROOT}/plugins/aae/scripts/install-schedule.sh" \
      || { fail "install-schedule.sh does not copy ${f}"; return 1; }
  done
  grep -q 'kb-versions.json' "${REPO_ROOT}/plugins/aae/scripts/install-schedule.sh" \
    || { fail "install-schedule.sh does not copy the version stamp"; return 1; }
}
