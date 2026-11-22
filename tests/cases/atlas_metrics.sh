#!/usr/bin/env bash
#
# The atlas-metrics engine behind the atlas-metrics-* skills.
#
# Why these tests exist: the skills promise two things a reader cannot check by
# eye. They never change the cluster, and they never turn a failure into an
# empty "all quiet" report. Both are pinned here against a fake atlas binary
# that records every command it is asked to run, so the suite needs no Atlas
# account and runs in CI.

AM_ENGINE="plugins/aae/scripts/atlas-metrics.sh"
AM_FIXTURES="tests/fixtures/atlas_metrics"
AM_WINDOW=(--cluster demo-cluster --start 2026-11-20T14:00:00Z --end 2026-11-20T14:20:00Z)
AM_PRIMARY="atlas-abc123-shard-00-00.abcde.example.net:27017"

am_setup() {
  mkdir -p "${SANDBOX}/fx" "${SANDBOX}/home"
  cp "${REPO_ROOT}/${AM_FIXTURES}/responses/"*.json "${SANDBOX}/fx/"
  export ATLAS_METRICS_ATLAS_BIN="${REPO_ROOT}/${AM_FIXTURES}/fake-atlas"
  export FAKE_ATLAS_FIXTURES="${SANDBOX}/fx"
  export FAKE_ATLAS_LOG="${SANDBOX}/atlas.log"
  export HOME="${SANDBOX}/home"
  unset ATLAS_METRICS_CONFIG FAKE_ATLAS_MISSING FAKE_ATLAS_VERSION
}

# am <args...> : run the engine; sets AM_OUT (stdout), AM_ERR (stderr), AM_RC.
am() {
  AM_OUT="$("${REPO_ROOT}/${AM_ENGINE}" "$@" 2>"${SANDBOX}/err")"
  AM_RC=$?
  AM_ERR="$(cat "${SANDBOX}/err")"
}

am_json() {  # am_json <python expr over `d`> ; reads AM_OUT
  printf '%s' "$AM_OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print($1)"
}

# ------------------------------------------------------------------ read-only

# The allowlist is the safety boundary. If someone adds a pin / acknowledge /
# enable command to it, this fails before the change ships.
test_the_allowlist_contains_no_known_mutating_operation() {
  local out
  out="$(cd "${REPO_ROOT}/plugins/aae/scripts" && python3 -c '
from atlas_metrics.constants import READ_ONLY_COMMANDS, KNOWN_MUTATING_OPERATIONS
bad = [c for c in READ_ONLY_COMMANDS if set(c) & KNOWN_MUTATING_OPERATIONS]
verbs = [c for c in READ_ONLY_COMMANDS if c[-1].startswith(("create","delete","update","pin","unpin","enable","disable","acknowledge","pause","start"))]
print(bad + verbs)')"
  assert_eq "[]" "$out" "no mutating operation may be allowlisted"
}

test_the_wrapper_refuses_a_command_outside_the_allowlist() {
  am_setup
  local out rc
  out="$(cd "${REPO_ROOT}/plugins/aae/scripts" && python3 -c '
from atlas_metrics.atlas_cli import AtlasCli
from atlas_metrics.errors import ReadOnlyViolation
cli = AtlasCli()
try:
    cli.api(("api", "collectionLevelMetrics", "pinNamespaces"), {"clusterName": "x"})
    print("RAN")
except ReadOnlyViolation as exc:
    print("REFUSED", exc)
' 2>&1)"
  assert_contains "$out" "REFUSED" "a pin call must be refused" || return 1
  [ ! -s "${FAKE_ATLAS_LOG}" ] || { fail "the refused command still reached the binary"; return 1; }
}

# Run every command, then read what the fake binary was actually asked to do.
test_every_command_run_by_every_subcommand_is_allowlisted() {
  am_setup
  local c
  for c in "hosts --cluster demo-cluster" "snapshot" "history --compare 1d" "storage" \
           "collections" "query-shapes" "search" "search --namespace app.orders" "advisor" \
           "incident" "doctor --cluster demo-cluster"; do
    case "$c" in
      hosts*|doctor*) am ${c} ;;
      *) am ${c%% *} "${AM_WINDOW[@]}" $( [ "${c#* }" != "$c" ] && echo "${c#* }") ;;
    esac
    case "$AM_RC" in 0|1) : ;; *) fail "$c exited $AM_RC: $AM_ERR"; return 1 ;; esac
  done
  local bad
  bad="$(cd "${REPO_ROOT}/plugins/aae/scripts" && python3 -c '
import json, sys
from atlas_metrics.constants import READ_ONLY_COMMANDS
bad = []
for line in open(sys.argv[1]):
    argv = json.loads(line)
    if argv in (["--version"],):
        continue
    if not any(tuple(argv[:len(c)]) == c for c in READ_ONLY_COMMANDS):
        bad.append(argv[:4])
print(bad)' "${FAKE_ATLAS_LOG}")"
  assert_eq "[]" "$bad" "every command sent to atlas must be allowlisted"
}

# ------------------------------------------------------------ credentials

# The atlas CLI lets exported MONGODB_ATLAS_* credentials beat a saved profile.
# A named profile must therefore reach the CLI without them, or an unrelated
# exported key silently replaces the identity the user configured.
test_a_named_profile_is_not_overridden_by_exported_credentials() {
  am_setup
  export FAKE_ATLAS_ENV_LOG="${SANDBOX}/env.log"
  MONGODB_ATLAS_CLIENT_ID=stale MONGODB_ATLAS_CLIENT_SECRET=stale MONGODB_ATLAS_BASE_URL=keep \
    am hosts --cluster demo-cluster --atlas-profile metrics
  assert_eq 0 "$AM_RC" "hosts with a named profile" || return 1
  assert_eq '["MONGODB_ATLAS_BASE_URL"]' "$(sort -u "${SANDBOX}/env.log")" \
    "only non-credential variables may reach the CLI" || return 1
  grep -q '"--profile", "metrics"' "${FAKE_ATLAS_LOG}" \
    || { fail "the named profile was not passed to the CLI"; return 1; }
}

test_without_a_named_profile_exported_credentials_are_left_alone() {
  am_setup
  export FAKE_ATLAS_ENV_LOG="${SANDBOX}/env.log"
  MONGODB_ATLAS_CLIENT_ID=x MONGODB_ATLAS_CLIENT_SECRET=y am hosts --cluster demo-cluster
  assert_eq '["MONGODB_ATLAS_CLIENT_ID", "MONGODB_ATLAS_CLIENT_SECRET"]' "$(sort -u "${SANDBOX}/env.log")" \
    "with no profile named, the CLI's normal precedence applies"
}

# ---------------------------------------------------------------- topology

test_hosts_lists_only_the_named_clusters_processes() {
  am_setup
  am hosts --cluster demo-cluster --format json
  assert_eq 0 "$AM_RC" "hosts exit" || return 1
  assert_eq 3 "$(am_json 'len(d["sections"][0]["rows"])')" "three demo-cluster nodes" || return 1
  assert_not_contains "$AM_OUT" "other-cluster" "another cluster's process leaked in"
}

test_nodes_primary_selects_the_primary_only() {
  am_setup
  am snapshot "${AM_WINDOW[@]}" --nodes primary --format json
  assert_eq "['demo-cluster-shard-00-00.abcde.example.net:27017 (REPLICA_PRIMARY)']" \
    "$(am_json 'sorted({r["scope"] for r in d["sections"][0]["rows"]})')" "primary only"
}

test_a_paused_cluster_fails_loudly() {
  am_setup
  python3 - "${SANDBOX}/fx/clusters_describe__demo-cluster.json" <<'EOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p)); d["paused"] = True; json.dump(d, open(p, "w"))
EOF
  am snapshot "${AM_WINDOW[@]}"
  assert_eq 3 "$AM_RC" "paused cluster exit" || return 1
  assert_contains "$AM_ERR" "paused" "the error must say the cluster is paused"
}

test_an_unknown_cluster_fails_with_the_describe_error() {
  am_setup
  am hosts --cluster nope-cluster
  assert_eq 3 "$AM_RC" "unknown cluster exit" || return 1
  assert_contains "$AM_ERR" "could not describe cluster 'nope-cluster'" "message"
}

# A cluster Atlas knows but with no per-process metrics (Flex / M0, or a name
# whose hosts the matcher misses) must say so and show what it did see.
test_a_cluster_with_no_matching_processes_names_what_was_seen() {
  am_setup
  printf '{"name": "ghost", "paused": false, "connectionStrings": {"standardSrv": "mongodb+srv://ghost.abcde.example.net"}}' \
    > "${SANDBOX}/fx/clusters_describe__ghost.json"
  am hosts --cluster ghost
  assert_eq 3 "$AM_RC" "no-process exit" || return 1
  assert_contains "$AM_ERR" "no processes in this project belong to cluster 'ghost'" "message" || return 1
  assert_contains "$AM_ERR" "Processes seen" "the processes it saw are listed"
}

# ------------------------------------------------------------ fail fast

test_an_atlas_failure_surfaces_the_command_and_its_error() {
  am_setup
  printf 'Error: unauthorized\n' > "${SANDBOX}/fx/processes_list.error"
  am snapshot "${AM_WINDOW[@]}"
  assert_eq 3 "$AM_RC" "CLI failure exit" || return 1
  assert_contains "$AM_ERR" "atlas processes list" "the failing command is shown" || return 1
  assert_contains "$AM_ERR" "unauthorized" "the CLI's own error is shown" || return 1
  assert_eq "" "$AM_OUT" "no report may be printed on failure"
}

test_non_json_output_is_an_error_not_an_empty_report() {
  am_setup
  printf 'not json' > "${SANDBOX}/fx/metrics_processes.json"
  cp "${SANDBOX}/fx/metrics_processes.json" "${SANDBOX}/fx/metrics_processes__${AM_PRIMARY}.json"
  am snapshot "${AM_WINDOW[@]}"
  assert_eq 3 "$AM_RC" "non-JSON exit" || return 1
  assert_contains "$AM_ERR" "not JSON" "message"
}

# ----------------------------------------------------- thresholds and stats

test_a_crossed_threshold_sets_the_verdict_and_exit_code() {
  am_setup
  am snapshot "${AM_WINDOW[@]}" --format json
  assert_eq 1 "$AM_RC" "findings exit code" || return 1
  assert_eq crit "$(am_json 'd["verdict"]')" "primary CPU at 95% is crit"
}

test_missing_points_are_gaps_not_zeros() {
  am_setup
  am history "${AM_WINDOW[@]}" --nodes primary --format json
  local row
  row="$(am_json '[r for r in d["sections"][0]["rows"] if r["name"]=="PROCESS_NORMALIZED_CPU_USER"][0]')"
  assert_contains "$row" "'gaps': 1" "the null point is counted as a gap" || return 1
  assert_contains "$row" "'min': 40.0" "the null point is not averaged in as 0"
}

test_a_threshold_flag_overrides_the_profile() {
  am_setup
  am snapshot "${AM_WINDOW[@]}" --threshold PROCESS_NORMALIZED_CPU_USER:warn=99,crit=100 \
     --threshold SYSTEM_NORMALIZED_CPU_IOWAIT:warn=50,crit=60 --format json
  assert_eq 0 "$AM_RC" "with relaxed thresholds nothing is crossed" || return 1
  assert_eq ok "$(am_json 'd["verdict"]')" "verdict"
}

test_a_unit_mismatch_stops_instead_of_comparing() {
  am_setup
  am snapshot "${AM_WINDOW[@]}" --threshold PROCESS_NORMALIZED_CPU_USER:warn=1,units=MILLISECONDS
  assert_eq 2 "$AM_RC" "unit mismatch exit" || return 1
  assert_contains "$AM_ERR" "expects units MILLISECONDS" "message"
}

test_compare_fetches_a_second_window_and_reports_deltas() {
  am_setup
  am history "${AM_WINDOW[@]}" --nodes primary --compare 7d --format json
  assert_contains "$AM_OUT" "avg_change_pct" "baseline deltas present" || return 1
  grep -q '"2026-11-13T14:00:00Z"' "${FAKE_ATLAS_LOG}" \
    || { fail "the baseline window 7 days earlier was not requested"; return 1; }
}

test_granularity_follows_the_window_length() {
  am_setup
  am history --cluster demo-cluster --start 2026-11-10T00:00:00Z --end 2026-11-12T00:00:00Z --nodes primary
  grep -q '"PT1H"' "${FAKE_ATLAS_LOG}" || { fail "a 2-day window must use PT1H"; return 1; }
}

test_conflicting_window_flags_are_rejected() {
  am_setup
  am snapshot --cluster demo-cluster --last 1h --start 2026-11-20T14:00:00Z
  assert_eq 2 "$AM_RC" "usage exit" || return 1
  assert_contains "$AM_ERR" "either --last or --start" "message"
}

# ---------------------------------------------------------------- profiles

test_an_unknown_profile_lists_the_known_ones() {
  am_setup
  am snapshot "${AM_WINDOW[@]}" --profile nope
  assert_eq 2 "$AM_RC" "unknown profile exit" || return 1
  assert_contains "$AM_ERR" "overview" "known profiles are listed"
}

test_a_profile_of_the_wrong_source_is_rejected() {
  am_setup
  am snapshot "${AM_WINDOW[@]}" --profile disk
  assert_eq 2 "$AM_RC" "wrong-source exit" || return 1
  assert_contains "$AM_ERR" "reads disk metrics" "message"
}

test_a_user_profile_extends_a_builtin() {
  am_setup
  mkdir -p "${HOME}/.config/atlas-metrics"
  cat > "${HOME}/.config/atlas-metrics/config.json" <<'EOF'
{"defaults": {"cluster": "demo-cluster"},
 "profiles": {"mine": {"extends": "cpu", "add": ["CONNECTIONS"], "remove": ["SYSTEM_NORMALIZED_CPU_STEAL"],
                       "thresholds": {"PROCESS_NORMALIZED_CPU_USER": {"warn": 80}}}}}
EOF
  am snapshot --start 2026-11-20T14:00:00Z --end 2026-11-20T14:20:00Z --profile mine --format json
  local names
  names="$(am_json 'sorted({r["name"] for r in d["sections"][0]["rows"]})')"
  assert_contains "$names" "CONNECTIONS" "added measurement present" || return 1
  assert_not_contains "$names" "SYSTEM_NORMALIZED_CPU_STEAL" "removed measurement gone" || return 1
  assert_eq crit "$(am_json 'd["verdict"]')" "inherited crit=90 still fires at 95"
}

test_inverted_warn_and_crit_are_rejected() {
  am_setup
  am snapshot "${AM_WINDOW[@]}" --threshold PROCESS_NORMALIZED_CPU_USER:warn=99
  assert_eq 2 "$AM_RC" "warn above the inherited crit must be rejected" || return 1
  assert_contains "$AM_ERR" "wrong order" "message"
}

test_a_typo_in_a_user_profile_fails_with_the_bad_name() {
  am_setup
  mkdir -p "${HOME}/.config/atlas-metrics"
  printf '{"profiles": {"bad": {"source": "process", "measurements": ["CPU_TYPO"]}}}' \
    > "${HOME}/.config/atlas-metrics/config.json"
  am profiles list
  assert_eq 2 "$AM_RC" "config error exit" || return 1
  assert_contains "$AM_ERR" "CPU_TYPO" "the bad name is shown"
}

test_profiles_init_writes_a_valid_example_and_refuses_to_overwrite() {
  am_setup
  am profiles init
  assert_eq 0 "$AM_RC" "init exit" || return 1
  assert_file "${HOME}/.config/atlas-metrics/config.json" "example config written" || return 1
  am profiles validate
  assert_eq 0 "$AM_RC" "the example validates" || return 1
  am profiles init
  assert_eq 2 "$AM_RC" "a second init must refuse" || return 1
}

test_profiles_commands_need_no_atlas_binary() {
  am_setup
  export ATLAS_METRICS_ATLAS_BIN="/nonexistent/atlas"
  am profiles list
  assert_eq 0 "$AM_RC" "profiles list runs offline"
}

# ------------------------------------------------------------ finer scope

test_collections_ranks_namespaces_and_marks_pinned() {
  am_setup
  am collections "${AM_WINDOW[@]}" --top 2 --format json
  assert_eq "['app.orders', 'app.users']" \
    "$(am_json '[r["namespace"] for r in d["sections"][0]["rows"]]')" "top 2 ranked" || return 1
  assert_eq True "$(am_json 'd["sections"][0]["rows"][1]["pinned"]')" "app.users is pinned"
}

test_collections_rejects_a_malformed_namespace() {
  am_setup
  am collections "${AM_WINDOW[@]}" --namespace orders
  assert_eq 2 "$AM_RC" "malformed namespace exit" || return 1
  assert_contains "$AM_ERR" "<database>.<collection>" "message"
}

test_query_shapes_hides_system_queries_and_sorts() {
  am_setup
  am query-shapes "${AM_WINDOW[@]}" --sort count --format json
  assert_eq "['app.orders', 'app.users']" \
    "$(am_json '[r["namespace"] for r in d["sections"][0]["rows"]]')" "sorted by count, no system" || return 1
  am query-shapes "${AM_WINDOW[@]}" --include-system --format json
  assert_contains "$AM_OUT" "local.oplog.rs" "--include-system shows them"
}

test_query_shapes_rejects_an_unknown_command_type() {
  am_setup
  am query-shapes "${AM_WINDOW[@]}" --command explode
  assert_eq 2 "$AM_RC" "bad --command exit"
}

test_search_index_mode_labels_rows_by_index() {
  am_setup
  am search "${AM_WINDOW[@]}" --namespace app.orders --format json
  assert_contains "$(am_json 'd["sections"][0]["rows"][0]["scope"]')" "default" "index name in scope"
}

test_advisor_unwraps_the_content_envelope_and_passes_bool_flags_correctly() {
  am_setup
  am advisor "${AM_WINDOW[@]}" --format json
  assert_contains "$AM_OUT" "412.5" "suggested index from the enveloped response" || return 1
  grep -q '"--includeMetrics=true"' "${FAKE_ATLAS_LOG}" \
    || { fail "bool flags must be passed as --flag=true"; return 1; }
}

test_incident_keeps_only_alerts_of_this_cluster_inside_the_window() {
  am_setup
  am incident "${AM_WINDOW[@]}" --format json
  assert_eq "['a1']" "$(am_json '[a["id"] for s in d["sections"] if s["title"].startswith("Alerts") for a in s["rows"]]')" \
    "only the in-window demo-cluster alert" || return 1
  grep -q '"--minDate", "2026-11-20T13:45:00Z"' "${FAKE_ATLAS_LOG}" \
    || { fail "events must be requested for the padded window"; return 1; }
}

test_incident_requires_a_start() {
  am_setup
  am incident --cluster demo-cluster --last 1h
  assert_eq 2 "$AM_RC" "incident without --start"
}

test_storage_ranks_databases_by_size() {
  am_setup
  am storage "${AM_WINDOW[@]}" --part databases --format json
  assert_eq "['app', 'analytics', 'admin']" \
    "$(am_json '[r["database"] for r in d["sections"][0]["rows"]]')" "largest first"
}

# ------------------------------------------------------------------ doctor

test_doctor_flags_an_operation_missing_from_the_installed_cli() {
  am_setup
  export FAKE_ATLAS_MISSING="api_queryShapeInsights_listQueryShapeSummaries"
  am doctor
  assert_eq 1 "$AM_RC" "doctor reports findings" || return 1
  assert_contains "$AM_OUT" "missing: api queryShapeInsights listQueryShapeSummaries" "names it"
}

test_doctor_warns_on_a_different_cli_version() {
  am_setup
  export FAKE_ATLAS_VERSION="1.70.0"
  am doctor
  assert_contains "$AM_OUT" "1.70.0 (skills verified on" "version drift is reported"
}

# ------------------------------------------------------------ portability

# macOS ships python3 3.9 at /usr/bin/python3; the engine must run on it.
test_the_engine_runs_on_the_oldest_supported_python() {
  am_setup
  local py=""
  for candidate in /usr/bin/python3 python3.9; do
    if command -v "$candidate" >/dev/null 2>&1 \
       && "$candidate" -c 'import sys; sys.exit(0 if sys.version_info[:2] == (3, 9) else 1)' 2>/dev/null; then
      py="$candidate"; break
    fi
  done
  [ -n "$py" ] || { printf '    (skipped: no python 3.9 on this machine)\n'; return 0; }
  "$py" -E -s "${REPO_ROOT}/plugins/aae/scripts/atlas_metrics/__main__.py" snapshot "${AM_WINDOW[@]}" \
    >/dev/null 2>"${SANDBOX}/err39"
  local rc=$?
  [ "$rc" -eq 1 ] || { fail "python 3.9 run exited $rc: $(cat "${SANDBOX}/err39")"; return 1; }
}

# ------------------------------------------------------- skills and docs

AM_SKILLS="snapshot history storage collections query-shapes search advisor incident profiles"
AM_GUIDE="knowledge/atlas_metrics/ATLAS_METRICS_USER_GUIDE.md"

# A skill the host cannot parse never loads; one whose engine path is wrong
# fails on its first command.
test_every_metrics_skill_has_frontmatter_and_points_at_the_engine() {
  local s file
  for s in $AM_SKILLS; do
    file="${REPO_ROOT}/plugins/aae/skills/atlas-metrics-${s}/SKILL.md"
    assert_file "$file" "skill atlas-metrics-${s}" || return 1
    head -1 "$file" | grep -q -- '---' || { fail "${s}: no frontmatter"; return 1; }
    grep -q "^name: atlas-metrics-${s}\$" "$file" || { fail "${s}: name does not match its directory"; return 1; }
    grep -q '^description: ' "$file" || { fail "${s}: no description"; return 1; }
    grep -q '\.\./\.\./scripts/atlas-metrics\.sh' "$file" || { fail "${s}: does not name the engine"; return 1; }
  done
  [ -x "${REPO_ROOT}/plugins/aae/skills/atlas-metrics-snapshot/../../scripts/atlas-metrics.sh" ] \
    || { fail "the engine is not at the path the skills give"; return 1; }
}

# Documentation that shows a flag the engine does not accept teaches the
# assistant to fail. Every example line is parsed by the real argument parser.
test_every_documented_example_command_parses() {
  local out seen
  out="$(cd "${REPO_ROOT}/plugins/aae/scripts" \
         && python3 "${REPO_ROOT}/tests/fixtures/atlas_metrics/parse_doc_examples.py" "${REPO_ROOT}" 2>&1)"
  assert_not_contains "$out" "BAD" "documented commands that do not parse: $out" || return 1
  seen="$(printf '%s\n' "$out" | awk '/^SEEN/{print $2}')"
  [ "${seen:-0}" -ge 25 ] || { fail "expected at least 25 documented examples, found ${seen:-0}: $out"; return 1; }
}

test_the_guide_exists_and_the_readme_links_it() {
  assert_file "${REPO_ROOT}/${AM_GUIDE}" "user guide" || return 1
  sed -n 3p "${REPO_ROOT}/${AM_GUIDE}" | grep -q '^- \[Summary\](#summary)' \
    || { fail "the guide must open with a clickable TOC"; return 1; }
  grep -q "${AM_GUIDE}" "${REPO_ROOT}/README.md" || { fail "README does not link the guide"; return 1; }
  local s
  for s in $AM_SKILLS; do
    grep -q "atlas-metrics-${s}" "${REPO_ROOT}/${AM_GUIDE}" || { fail "guide omits atlas-metrics-${s}"; return 1; }
  done
}

# This repo is public: no real Atlas hostnames or 24-hex project / org IDs in
# anything the metrics work added. The all-zero ID in fixtures is a placeholder.
test_no_real_hostnames_or_ids_in_the_metrics_files() {
  local hits
  hits="$(grep -rnE 'mongodb\.net|[^0-9a-f][0-9a-f]{24}[^0-9a-f]' \
      "${REPO_ROOT}/plugins/aae/scripts/atlas_metrics" "${REPO_ROOT}/plugins/aae/scripts/atlas-metrics.sh" \
      "${REPO_ROOT}"/plugins/aae/skills/atlas-metrics-* "${REPO_ROOT}/knowledge/atlas_metrics" \
      "${REPO_ROOT}/${AM_FIXTURES}" "${REPO_ROOT}/tests/live" 2>/dev/null \
    | grep -v '000000000000000000000000' | grep -v 'mongodb\\\\\.net' | grep -v '__pycache__' || true)"
  assert_eq "" "$hits" "real-looking hostnames or IDs found"
}
