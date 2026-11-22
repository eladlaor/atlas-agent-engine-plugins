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

# Found live: doctor's auth row reported the CLI's default profile while the
# data commands used the named one, so it vouched for the wrong identity.
test_doctor_checks_the_identity_of_the_named_profile() {
  am_setup
  am doctor --atlas-profile metrics
  grep -q '\["auth", "whoami", "--profile", "metrics"\]' "${FAKE_ATLAS_LOG}" \
    || { fail "auth whoami must run with the named profile: $(grep whoami "${FAKE_ATLAS_LOG}")"; return 1; }
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
  am snapshot --cluster demo-cluster --last 15m
  assert_eq 3 "$AM_RC" "a 'now' question on a paused cluster must fail" || return 1
  assert_contains "$AM_ERR" "is paused" "the error must say the cluster is paused" || return 1
  assert_contains "$AM_ERR" "--start" "and point to an explicit past window"
}

# Atlas keeps what a cluster recorded before it was paused; an explicit past
# window is a legitimate post-mortem and must work, with a warning.
test_a_paused_cluster_answers_for_an_explicit_past_window() {
  am_setup
  am_edit_json "${SANDBOX}/fx/clusters_describe__demo-cluster.json" 'd["paused"] = True'
  am_edit_json "${SANDBOX}/fx/processes_list.json" \
    'for p in d["results"]: p["lastPing"] = "2026-11-20T22:59:39Z"'
  am snapshot "${AM_WINDOW[@]}" --nodes primary
  case "$AM_RC" in 0|1) : ;; *) fail "explicit window on a paused cluster exited $AM_RC: $AM_ERR"; return 1 ;; esac
  assert_contains "$AM_OUT" "is paused; it last reported at 2026-11-20T22:59:39Z" "paused warning"
}

test_doctor_warns_on_a_paused_cluster() {
  am_setup
  am_edit_json "${SANDBOX}/fx/clusters_describe__demo-cluster.json" 'd["paused"] = True'
  am doctor --cluster demo-cluster
  assert_contains "$AM_OUT" "PAUSED" "doctor names the paused state"
}

# Live 2026-11-22: a primary rejects oplog-lag measurements (INVALID_METRIC_NAME);
# one rejected name must not fail the whole node, and must be named in the report.
test_a_measurement_a_node_rejects_is_dropped_and_named() {
  am_setup
  export FAKE_ATLAS_REJECT="shard-00-00:OPLOG_REPLICATION_LAG_TIME"
  am snapshot "${AM_WINDOW[@]}" --format json
  case "$AM_RC" in 0|1) : ;; *) fail "one rejected measurement failed the run ($AM_RC): $AM_ERR"; return 1 ;; esac
  assert_contains "$AM_OUT" "does not offer OPLOG_REPLICATION_LAG_TIME" "the rejection is reported" || return 1
  assert_contains "$AM_OUT" "secondaries only" "with the reason" || return 1
  local lag_rows
  lag_rows="$(am_json 'sorted({r["scope"].split()[0] for r in d["sections"][0]["rows"] if r["name"]=="OPLOG_REPLICATION_LAG_TIME"})')"
  assert_not_contains "$lag_rows" "shard-00-00" "the primary has no lag row" || return 1
  assert_contains "$lag_rows" "shard-00-01" "the secondaries still do"
}

# Live 2026-11-22: some data points arrive without a "value" key at all.
test_a_data_point_without_a_value_key_is_a_gap() {
  am_setup
  am_edit_json "${SANDBOX}/fx/metrics_processes__${AM_PRIMARY}.json" \
    'for m in d["measurements"]: del m["dataPoints"][1]["value"]'
  am history "${AM_WINDOW[@]}" --nodes primary --format json
  case "$AM_RC" in 0|1) : ;; *) fail "missing value key crashed ($AM_RC): $AM_ERR"; return 1 ;; esac
  assert_contains "$(am_json '[r["gaps"] for r in d["sections"][0]["rows"]][:1]')" "1" "counted as a gap"
}

test_units_seen_live_are_formatted() {
  local out
  out="$(cd "${REPO_ROOT}/plugins/aae/scripts" && python3 -c '
from atlas_metrics.summarize import human
print(human(2048, "KILOBYTES"), "|", human(3, "MEGABYTES"), "|", human(12, "SECONDS"), "|", human(600, "SECONDS"), "|", human(18000, "SECONDS"), "|", human(3319014, "SECONDS"))')"
  assert_eq "2.0 MB | 3.0 MB | 12.0 s | 10.0 min | 5.0 h | 38.4 days" "$out" "KILOBYTES / MEGABYTES / SECONDS formatting"
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

# A refused credential is almost always the missing service-account setup, so
# the error must say how to do it, not just "unauthorized".
test_an_auth_failure_prints_the_service_account_setup() {
  am_setup
  printf 'Error: https://cloud.mongodb.com/api/atlas/v2/groups/x/processes GET: HTTP 401 Unauthorized (Error code: "UNAUTHORIZED")\n' \
    > "${SANDBOX}/fx/processes_list.error"
  am hosts --cluster demo-cluster
  assert_eq 3 "$AM_RC" "auth failure exit" || return 1
  assert_contains "$AM_ERR" "atlas-metrics-readonly" "names the service account to create" || return 1
  assert_contains "$AM_ERR" "Project Read Only + Project Observability Viewer" "names its roles" || return 1
  assert_contains "$AM_ERR" "--profile metrics" "names the CLI profile"
}

# An org that enforces an API access list accepts the login and refuses every
# read. The message must name the IP Atlas saw and how to list it, and must not
# send the user off to recreate a service account that is fine.
test_an_access_list_refusal_names_the_ip_to_add() {
  am_setup
  printf 'Error: https://cloud.mongodb.com/api/atlas/v2/groups/x/clusters/demo-cluster GET: HTTP 403 Forbidden (Error code: "ORG_REQUIRES_ACCESS_LIST") Detail: This organization requires access through an access list of ip ranges. Reason: Forbidden. Params: [203.0.113.7]\n' \
    > "${SANDBOX}/fx/clusters_describe.error"
  am hosts --cluster demo-cluster
  assert_eq 3 "$AM_RC" "access-list exit" || return 1
  assert_contains "$AM_ERR" "come from 203.0.113.7" "names the caller IP" || return 1
  assert_contains "$AM_ERR" '[{"ipAddress": "203.0.113.7"}]' "gives the request body" || return 1
  assert_contains "$AM_ERR" "never run that command themselves" "says it will not self-list" || return 1
  assert_not_contains "$AM_ERR" "create a service account" "not the account-setup hint"
}

test_a_non_auth_failure_does_not_print_the_setup() {
  am_setup
  printf 'Error: cluster is being created\n' > "${SANDBOX}/fx/processes_list.error"
  am hosts --cluster demo-cluster
  assert_not_contains "$AM_ERR" "atlas-metrics-readonly" "setup hint only on auth failures"
}

test_doctor_shows_the_setup_when_auth_fails() {
  am_setup
  printf 'Error: not logged in with an Atlas account, Service Account or API key\n' \
    > "${SANDBOX}/fx/auth_whoami.error"
  am doctor
  assert_eq 1 "$AM_RC" "doctor reports findings" || return 1
  assert_contains "$AM_OUT" "setup" "a setup row" || return 1
  assert_contains "$AM_OUT" "Project Observability Viewer" "with the roles"
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
     --threshold SYSTEM_NORMALIZED_CPU_IOWAIT:warn=50,crit=60 \
     --threshold OPLOG_REPLICATION_LAG_TIME:warn=100,crit=200 --format json
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
  assert_contains "$(am_json 'd["sections"][0]["rows"][0]["scope"]')" "index fake-index-id-1" \
    "the collection's only index is named in scope" || return 1
  am search "${AM_WINDOW[@]}" --namespace app.orders --index default --format json
  assert_contains "$(am_json 'd["sections"][0]["rows"][0]["scope"]')" "app.orders default" "--index names it"
}

# Live 2026-11-22: the per-collection response's series carry no index name, so
# with several indexes they can't be attributed. Refuse rather than merge them.
test_search_refuses_to_merge_several_indexes() {
  am_setup
  am_edit_json "${SANDBOX}/fx/api_monitoringAndLogs_listIndexMeasurements.json" \
    'd["indexIds"] = ["fake-index-id-1", "fake-index-id-2"]'
  am search "${AM_WINDOW[@]}" --namespace app.orders
  assert_eq 2 "$AM_RC" "several indexes without --index" || return 1
  assert_contains "$AM_ERR" "Name one with --index" "message"
}

# Live 2026-11-22: PT10S on an old window is a bare HTTP 500 from Atlas.
test_a_fine_granularity_server_error_explains_retention() {
  am_setup
  printf 'Error: GET: HTTP 500 Internal Server Error (Error code: "UNEXPECTED_ERROR")\n' \
    > "${SANDBOX}/fx/metrics_processes.error"
  am history "${AM_WINDOW[@]}" --granularity PT10S --nodes secondaries
  assert_eq 3 "$AM_RC" "server error exit" || return 1
  assert_contains "$AM_ERR" "10-second points only for a short time" "retention hint"
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

# --------------------------------------- regressions from the code review

am_edit_json() {  # am_edit_json <file> <python statement over d>; aborts the test on a bad edit
  python3 - "$1" "$2" <<'PY' || { fail "fixture edit failed: $2"; return 1; }
import json, sys
path, stmt = sys.argv[1], sys.argv[2]
d = json.load(open(path))
exec(stmt)
json.dump(d, open(path, "w"))
PY
}

test_all_empty_series_are_no_data_not_healthy() {
  am_setup
  am_edit_json "${SANDBOX}/fx/metrics_processes__${AM_PRIMARY}.json" \
    'for m in d["measurements"]:
    for p in m["dataPoints"]: p["value"] = None'
  am snapshot "${AM_WINDOW[@]}" --nodes primary
  assert_eq 4 "$AM_RC" "only-empty series must exit 4, never 0" || return 1
  assert_contains "$AM_ERR" "only empty series" "message"
}

test_a_node_that_stopped_reporting_is_marked_stale() {
  am_setup
  am_edit_json "${SANDBOX}/fx/metrics_processes__${AM_PRIMARY}.json" \
    'for m in d["measurements"]:
    m["dataPoints"][-1]["value"] = None; m["dataPoints"][-2]["value"] = None'
  am snapshot "${AM_WINDOW[@]}" --nodes primary
  assert_contains "$AM_OUT" "stale (2 latest points missing)" "stale status" || return 1
  assert_contains "$AM_OUT" "stale series:" "header counts stale series"
}

test_an_invalid_config_default_is_a_config_error_not_a_crash() {
  am_setup
  mkdir -p "${HOME}/.config/atlas-metrics"
  printf '{"defaults": {"nodes": "primaries"}}' > "${HOME}/.config/atlas-metrics/config.json"
  am hosts --cluster demo-cluster
  assert_eq 2 "$AM_RC" "bad default exit" || return 1
  assert_contains "$AM_ERR" "defaults.nodes" "names the bad key"
}

test_an_unexpected_crash_exits_5_not_1() {
  am_setup
  printf '{"rankedNamespaces": [123]}' > "${SANDBOX}/fx/api_collectionLevelMetrics_getClusterNamespaces.json"
  am collections "${AM_WINDOW[@]}"
  assert_eq 5 "$AM_RC" "a bug must not look like a threshold finding (1)" || return 1
  assert_contains "$AM_ERR" "internal error" "message"
}

test_a_cluster_whose_name_prefixes_another_does_not_take_its_nodes() {
  am_setup
  am_edit_json "${SANDBOX}/fx/processes_list.json" \
    'd["results"].append({"id": "atlas-qqq-shard-00-00.abcde.example.net:27017", "hostname": "atlas-qqq-shard-00-00.abcde.example.net", "port": 27017, "userAlias": "demo-cluster-analytics-shard-00-00.abcde.example.net", "typeName": "REPLICA_PRIMARY", "replicaSetName": "atlas-qqq-shard-0"})'
  am hosts --cluster demo-cluster
  assert_not_contains "$AM_OUT" "analytics" "demo-cluster-analytics must not be part of demo-cluster"
}

test_a_threshold_for_a_measurement_not_in_the_profile_is_rejected() {
  am_setup
  mkdir -p "${HOME}/.config/atlas-metrics"
  printf '{"profiles": {"mine": {"extends": "cpu", "thresholds": {"NOT_A_METRIC": {"warn": 1}}}}}' \
    > "${HOME}/.config/atlas-metrics/config.json"
  am profiles list
  assert_eq 2 "$AM_RC" "unknown threshold name exit" || return 1
  assert_contains "$AM_ERR" "NOT_A_METRIC" "names it"
}

test_a_missing_response_field_is_an_error_not_an_empty_result() {
  am_setup
  printf '{"groupId": "x"}' > "${SANDBOX}/fx/api_collectionLevelMetrics_getClusterNamespaces.json"
  am collections "${AM_WINDOW[@]}"
  assert_eq 3 "$AM_RC" "changed response format exit" || return 1
  assert_contains "$AM_ERR" "expected a 'rankedNamespaces' list" "message"
}

test_incident_never_asks_for_the_future_and_keeps_granularity() {
  am_setup
  local start
  start="$(python3 -c 'import datetime as d; print((d.datetime.now(d.timezone.utc)-d.timedelta(minutes=5)).strftime("%Y-%m-%dT%H:%M:%SZ"))')"
  am incident --cluster demo-cluster --start "$start" --granularity PT10S --nodes primary --format json
  case "$AM_RC" in 0|1) : ;; *) fail "incident exited $AM_RC: $AM_ERR"; return 1 ;; esac
  python3 - "${FAKE_ATLAS_LOG}" <<'PY' || return 1
import datetime as d, json, sys
now = d.datetime.now(d.timezone.utc) + d.timedelta(seconds=5)
for line in open(sys.argv[1]):
    argv = json.loads(line)
    for flag in ("--end", "--maxDate"):
        if flag in argv:
            end = d.datetime.fromisoformat(argv[argv.index(flag) + 1].replace("Z", "+00:00"))
            if end > now:
                sys.exit(f"{flag} {end} is in the future")
    if argv[:2] == ["metrics", "processes"] and argv[argv.index("--granularity") + 1] != "PT10S":
        sys.exit("user granularity was replaced")
PY
  am incident --cluster demo-cluster --start "$start" --pad-minutes -5
  assert_eq 2 "$AM_RC" "negative padding is rejected"
}

test_alerts_page_until_the_total_is_reached() {
  am_setup
  am_edit_json "${SANDBOX}/fx/api_alerts_listAlerts.json" \
    'd["results"] = (d["results"] * 167)[:500]; d["totalCount"] = 600'
  am incident "${AM_WINDOW[@]}" --nodes primary
  grep -q '"--pageNum", "2"' "${FAKE_ATLAS_LOG}" || { fail "page 2 was not requested"; return 1; }
  ! grep -q '"--pageNum", "3"' "${FAKE_ATLAS_LOG}" || { fail "paged past totalCount"; return 1; }
}

test_every_api_call_pins_its_version() {
  am_setup
  am collections "${AM_WINDOW[@]}"
  am advisor "${AM_WINDOW[@]}"
  local unpinned
  unpinned="$(python3 -c '
import json, sys
bad = [a[:3] for a in map(json.loads, open(sys.argv[1])) if a[:1] == ["api"] and "--help" not in a and "--version" not in a]
print(bad)' "${FAKE_ATLAS_LOG}")"
  assert_eq "[]" "$unpinned" "every atlas api call must carry --version" || return 1
  grep -q '"listClusterSuggestedIndexes".*"--version", "2024-08-05"' "${FAKE_ATLAS_LOG}" \
    || { fail "cluster advisor ops must pin 2024-08-05"; return 1; }
}

test_a_lowercase_z_time_is_accepted() {
  am_setup
  am snapshot --cluster demo-cluster --start 2026-11-20t14:00:00z --end 2026-11-20T14:20:00Z --nodes primary
  case "$AM_RC" in 0|1) : ;; *) fail "lowercase z rejected: $AM_ERR"; return 1 ;; esac
}

test_storage_rejects_an_unknown_database() {
  am_setup
  am storage "${AM_WINDOW[@]}" --part databases --database nosuch
  assert_eq 2 "$AM_RC" "unknown --database exit" || return 1
  assert_contains "$AM_ERR" "nosuch" "names it"
}

# ------------------------------------ regressions from the second review

test_a_node_that_rejects_every_measurement_is_no_data_not_ok() {
  am_setup
  local all
  all="$(cd "${REPO_ROOT}/plugins/aae/scripts" && python3 -c '
import json
p = json.load(open("atlas_metrics/builtin_profiles.json"))["disk"]["measurements"]
print(",".join("shard-00:" + m for m in p))')"
  export FAKE_ATLAS_REJECT="$all"
  am storage "${AM_WINDOW[@]}" --part disks
  assert_eq 4 "$AM_RC" "every disk measurement rejected must be exit 4, never 0" || return 1
  assert_contains "$AM_ERR" "offers none of profile disk" "message"
}

test_cluster_level_commands_refuse_now_on_a_paused_cluster() {
  am_setup
  am_edit_json "${SANDBOX}/fx/clusters_describe__demo-cluster.json" 'd["paused"] = True'
  local c
  for c in collections query-shapes advisor; do
    am "$c" --cluster demo-cluster --last 1h
    assert_eq 3 "$AM_RC" "$c --last on a paused cluster" || return 1
    assert_contains "$AM_ERR" "is paused" "$c names the paused state" || return 1
  done
  am collections "${AM_WINDOW[@]}"
  case "$AM_RC" in 0|1) : ;; *) fail "collections past window on paused cluster: $AM_RC $AM_ERR"; return 1 ;; esac
  assert_contains "$AM_OUT" "is paused" "past-window report carries the paused warning"
}

test_the_paused_note_survives_a_no_data_failure() {
  am_setup
  am_edit_json "${SANDBOX}/fx/clusters_describe__demo-cluster.json" 'd["paused"] = True'
  am_edit_json "${SANDBOX}/fx/metrics_processes__${AM_PRIMARY}.json" \
    'for m in d["measurements"]:
    for p in m["dataPoints"]: p["value"] = None'
  am snapshot "${AM_WINDOW[@]}" --nodes primary
  assert_eq 4 "$AM_RC" "no data" || return 1
  assert_contains "$AM_ERR" "note: cluster demo-cluster is paused" "paused note kept on failure"
}

test_database_filter_tolerates_a_shard_without_that_database() {
  am_setup
  printf '{"results": [{"databaseName": "admin"}]}' \
    > "${SANDBOX}/fx/metrics_databases_list__atlas-abc123-shard-00-01.abcde.example.net:27017.json"
  am storage "${AM_WINDOW[@]}" --part databases --database app
  case "$AM_RC" in 0|1) : ;; *) fail "a node lacking 'app' broke the run ($AM_RC): $AM_ERR"; return 1 ;; esac
  assert_contains "$AM_OUT" "app" "the database is still reported"
}

test_rejected_names_are_not_re_requested_per_disk() {
  am_setup
  export FAKE_ATLAS_REJECT="shard-00-00:DISK_QUEUE_DEPTH"
  am_edit_json "${SANDBOX}/fx/metrics_disks_list.json" \
    'd["results"] = [{"partitionName": "data"}, {"partitionName": "journal"}]'
  am storage "${AM_WINDOW[@]}" --part disks --nodes primary
  local asks
  asks="$(grep -c 'DISK_QUEUE_DEPTH' "${FAKE_ATLAS_LOG}")"
  assert_eq 1 "$asks" "DISK_QUEUE_DEPTH asked once, then remembered for the node's other disk"
}

# Live 2026-11-22: database sizes are sampled rarely; a 15-minute window was all-empty.
test_storage_databases_default_to_a_six_hour_window() {
  am_setup
  am storage --cluster demo-cluster --part databases
  case "$AM_RC" in 0|1) : ;; *) fail "storage exited $AM_RC: $AM_ERR"; return 1 ;; esac
  python3 - "${FAKE_ATLAS_LOG}" <<'PY' || return 1
import datetime as d, json, sys
for argv in map(json.loads, open(sys.argv[1])):
    if argv[:3] == ["metrics", "databases", "describe"]:
        start = d.datetime.fromisoformat(argv[argv.index("--start") + 1].replace("Z", "+00:00"))
        end = d.datetime.fromisoformat(argv[argv.index("--end") + 1].replace("Z", "+00:00"))
        if end - start < d.timedelta(hours=5, minutes=59):
            sys.exit(f"database window is only {end - start}")
        sys.exit(0)
sys.exit("no database describe call was made")
PY
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
