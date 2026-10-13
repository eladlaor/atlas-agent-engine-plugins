#!/usr/bin/env bash
#
# The manifest contract.
#
# Why these tests exist: this repo is two marketplaces over one plugin. Claude
# Code reads .claude-plugin/marketplace.json at the root; Codex reads
# .agents/plugins/marketplace.json. Each host hardcodes where it looks, so the
# files cannot be merged — which leaves the same name, version, license and
# description copied across three manifests with nothing keeping them in step.
#
# That is not hypothetical. 0.8.0 shipped with the Codex manifest still at
# 0.6.0, while the changelog announced that the two counters had been collapsed
# onto one number; and all three manifests advertised "a hash-based docs
# watcher" after the git-sourced detector became the scheduled default. A
# visitor reads those strings before they read anything else.
#
# Copies that must agree are an interface. These tests fail when they drift.

MANIFEST_CLAUDE_MARKET=".claude-plugin/marketplace.json"
MANIFEST_CLAUDE_PLUGIN="plugins/aae/.claude-plugin/plugin.json"
MANIFEST_CODEX_PLUGIN="plugins/aae/.codex-plugin/plugin.json"
MANIFEST_CODEX_MARKET=".agents/plugins/marketplace.json"

# Read one field from a manifest, unwrapping the marketplace's plugins[0].
manifest_field() {
  python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
e = d["plugins"][0] if "plugins" in d else d
print(e.get(sys.argv[2], "<missing>"))
' "${REPO_ROOT}/$1" "$2"
}

# Every manifest must be parseable at all. A broken one fails the install with
# a message that points at the host, not at us.
test_every_manifest_is_valid_json() {
  local m
  for m in "$MANIFEST_CLAUDE_MARKET" "$MANIFEST_CLAUDE_PLUGIN" \
           "$MANIFEST_CODEX_PLUGIN" "$MANIFEST_CODEX_MARKET"; do
    python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "${REPO_ROOT}/${m}" 2>/dev/null \
      || { fail "not valid JSON: ${m}"; return 1; }
  done
}

# The bug that shipped: Codex on 0.6.0 while everything else said 0.8.0.
test_the_three_versions_agree() {
  local a b c
  a="$(manifest_field "$MANIFEST_CLAUDE_MARKET" version)"
  b="$(manifest_field "$MANIFEST_CLAUDE_PLUGIN" version)"
  c="$(manifest_field "$MANIFEST_CODEX_PLUGIN" version)"
  assert_eq "$a" "$b" "root marketplace vs Claude plugin version" || return 1
  assert_eq "$b" "$c" "Claude plugin vs Codex plugin version"
}

# The version a user installs must be the version the changelog documents,
# otherwise the release notes describe something nobody is running.
test_the_version_has_a_changelog_entry() {
  local v; v="$(manifest_field "$MANIFEST_CLAUDE_PLUGIN" version)"
  grep -q "^## \[${v}\] - " "${REPO_ROOT}/CHANGELOG.md" \
    || { fail "CHANGELOG.md has no released section for ${v}"; return 1; }
}

# The description is what renders in the install list, before the README. All
# three copies must say the same thing.
test_the_three_descriptions_agree() {
  local a b c
  a="$(manifest_field "$MANIFEST_CLAUDE_MARKET" description)"
  b="$(manifest_field "$MANIFEST_CLAUDE_PLUGIN" description)"
  c="$(manifest_field "$MANIFEST_CODEX_PLUGIN" description)"
  assert_eq "$a" "$b" "root marketplace vs Claude plugin description" || return 1
  assert_eq "$b" "$c" "Claude plugin vs Codex plugin description"
}

# A description that names the detector must name the one that actually runs.
test_the_description_does_not_advertise_a_replaced_detector() {
  local d; d="$(manifest_field "$MANIFEST_CLAUDE_PLUGIN" description)"
  case "$d" in
    *"hash-based docs watcher"*)
      fail "the description still advertises the hash-based watcher; the git-sourced one is the scheduled default"
      return 1 ;;
  esac
}

# Declaring a license with no LICENSE file in the repo tells a reader they may
# use this, while the file that would grant it is absent.
test_a_declared_license_has_a_license_file() {
  local l; l="$(manifest_field "$MANIFEST_CLAUDE_PLUGIN" license)"
  [ "$l" = "<missing>" ] && return 0
  [ -f "${REPO_ROOT}/LICENSE" ] \
    || { fail "manifests declare license ${l} but there is no LICENSE file"; return 1; }
}

# Nothing here needs credentials: the repository it reads is public. A docs
# watcher asking to authenticate on install is what makes a stranger close the
# tab, so the request must not come back.
test_codex_marketplace_requests_no_authentication() {
  grep -q "ON_INSTALL" "${REPO_ROOT}/${MANIFEST_CODEX_MARKET}" \
    && { fail "the Codex marketplace manifest requests authentication on install"; return 1; }
  return 0
}

# Both plugin manifests must point at files that exist, or the host installs a
# plugin whose skills never load.
test_plugin_manifests_reference_real_paths() {
  local src
  src="$(python3 -c '
import json
d = json.load(open("'"${REPO_ROOT}/${MANIFEST_CLAUDE_MARKET}"'"))
s = d["plugins"][0]["source"]
print(s if isinstance(s, str) else s.get("path", ""))
')"
  [ -d "${REPO_ROOT}/${src}" ] \
    || { fail "root marketplace source does not exist: ${src}"; return 1; }
  [ -f "${REPO_ROOT}/plugins/aae/hooks/hooks.json" ] \
    || { fail "the hooks file referenced by both plugin manifests is missing"; return 1; }
  [ -d "${REPO_ROOT}/plugins/aae/skills" ] \
    || { fail "the skills directory referenced by both plugin manifests is missing"; return 1; }
}
