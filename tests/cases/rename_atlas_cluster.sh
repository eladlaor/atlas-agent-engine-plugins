#!/usr/bin/env bash
#
# The cluster-rename skill and its preflight.
#
# Why these tests exist: this is the plugin's only skill that runs a data
# migration, and the two ways it can go wrong are both silent. A credential
# that expires mid-run leaves a half-migrated workspace; a source cluster
# deleted before the new one is proven loses the checkpoints with it. Neither
# announces itself, so both are pinned here rather than trusted to prose.
#
# The preflight is a pure GET path, which is what makes it testable at all: it
# can be run in CI with no Atlas credentials and must still refuse correctly.

SKILL="plugins/aae/skills/aae-rename-atlas-cluster/SKILL.md"
PREFLIGHT="plugins/aae/scripts/aae-cluster-rename-preflight.sh"

# A skill the host cannot parse is a skill that never loads.
test_the_skill_has_name_and_description_frontmatter() {
  assert_file "${REPO_ROOT}/${SKILL}" "the skill file exists" || return 1
  head -1 "${REPO_ROOT}/${SKILL}" | grep -q -- '---' \
    || { fail "SKILL.md does not open with YAML frontmatter"; return 1; }
  grep -q '^name: aae-rename-atlas-cluster$' "${REPO_ROOT}/${SKILL}" \
    || { fail "frontmatter name is missing or does not match the directory"; return 1; }
  grep -q '^description: ' "${REPO_ROOT}/${SKILL}" \
    || { fail "frontmatter has no description, so the skill never triggers"; return 1; }
}

# The script is referenced from the skill by path and invoked directly. A
# non-executable file turns the first phase into a permission error.
test_the_preflight_is_executable_and_valid_bash() {
  assert_file "${REPO_ROOT}/${PREFLIGHT}" "the preflight exists" || return 1
  [ -x "${REPO_ROOT}/${PREFLIGHT}" ] \
    || { fail "preflight is not executable"; return 1; }
  bash -n "${REPO_ROOT}/${PREFLIGHT}" 2>/dev/null \
    || { fail "preflight is not valid bash"; return 1; }
}

# The skill names the script; if the path drifts, Phase 0 silently stops being
# run and every later phase proceeds on assumptions.
test_the_skill_points_at_the_preflight_that_exists() {
  grep -q 'aae-cluster-rename-preflight.sh' "${REPO_ROOT}/${SKILL}" \
    || { fail "the skill does not reference the preflight script"; return 1; }
}

# --target is the whole input. Without it the script must refuse rather than
# default to something, because every default here names a real cluster.
test_preflight_refuses_without_a_target() {
  set +e
  local out rc
  out="$("${REPO_ROOT}/${PREFLIGHT}" 2>&1)"; rc=$?
  set -e
  assert_eq 2 "$rc" "missing --target must exit 2 (usage)" || return 1
  assert_contains "$out" "target" "the error must name the missing flag"
}

# The headline precondition. A user-account login looks fine until the refresh
# token expires partway through a twenty-minute migration, so the preflight
# must treat it as a blocker and say why.
test_preflight_demands_a_service_account() {
  grep -q 'user_account' "${REPO_ROOT}/${PREFLIGHT}" \
    || { fail "preflight does not detect a user-account credential"; return 1; }
  grep -qi 'service.account' "${REPO_ROOT}/${PREFLIGHT}" \
    || { fail "preflight does not require a service account"; return 1; }
}

# Run outside an agent directory with no credentials, the script must reach a
# verdict and exit non-zero — never hang waiting for input, and never exit 0.
test_preflight_is_non_interactive_and_fails_closed() {
  set +e
  local out rc
  out="$(cd "$SANDBOX" && "${REPO_ROOT}/${PREFLIGHT}" --target some-new-name </dev/null 2>&1)"
  rc=$?
  set -e
  assert_eq 1 "$rc" "a bare sandbox has blockers, so the verdict must be NO-GO" || return 1
  assert_contains "$out" "NO-GO" "it must print a verdict" || return 1
  assert_contains "$out" "agent.yaml" "it must name the missing agent directory"
}

# The safety rule the whole skill is built around. The source cluster holds the
# only copy of the checkpoints until the new one is proven, so no flag may
# delete it automatically.
test_the_skill_never_deletes_the_source_cluster_automatically() {
  grep -qi 'never deleted automatically\|never delete the source cluster' "${REPO_ROOT}/${SKILL}" \
    || { fail "the skill does not state that the source cluster is never auto-deleted"; return 1; }
  # --auto must be explicitly carved out, or a reader assumes it covers everything.
  grep -qi 'never automatic under any flag\|under any flag' "${REPO_ROOT}/${SKILL}" \
    || { fail "the skill does not exempt deletion from --auto"; return 1; }
}

# Restoring documents does not restore index definitions, and the resulting
# failure presents as a hung deploy rather than an error. The skill must say so.
test_the_skill_requires_rebuilding_search_indexes() {
  grep -qi 'Memory: waiting' "${REPO_ROOT}/${SKILL}" \
    || { fail "the skill does not name the 'Memory: waiting' symptom"; return 1; }
  grep -qi 'search index' "${REPO_ROOT}/${SKILL}" \
    || { fail "the skill does not require rebuilding Search indexes"; return 1; }
}

# A bad URI makes app.checkpointer() return None instead of raising, so a
# green deploy proves nothing. Acceptance must be a reused session id.
test_the_skill_verifies_on_a_reused_session() {
  grep -qi 'reused' "${REPO_ROOT}/${SKILL}" \
    || { fail "the skill does not require verifying on a reused session id"; return 1; }
  grep -q 'returns `None`\|returns None' "${REPO_ROOT}/${SKILL}" \
    || { fail "the skill does not warn that the checkpointer fails silently"; return 1; }
}

# The documented defect: any unrecognised deploy subcommand runs a real deploy.
test_the_skill_carries_the_deploy_subcommand_warning() {
  grep -qi 'unrecognized-subcommand\|unrecognised-subcommand' "${REPO_ROOT}/${SKILL}" \
    || { fail "the skill omits the deploy argument-parsing warning"; return 1; }
}

# The new skill must appear in the README table and the user guide, or it ships
# invisible to anyone reading the docs rather than the directory listing.
test_the_skill_is_documented() {
  grep -q 'aae-rename-atlas-cluster' "${REPO_ROOT}/README.md" \
    || { fail "README does not list the skill"; return 1; }
  grep -q 'aae-rename-atlas-cluster' "${REPO_ROOT}/knowledge/usage_guides/USER_GUIDE.md" \
    || { fail "USER_GUIDE does not mention the skill"; return 1; }
  grep -q 'aae-rename-atlas-cluster' "${REPO_ROOT}/CHANGELOG.md" \
    || { fail "CHANGELOG does not record the skill"; return 1; }
}
