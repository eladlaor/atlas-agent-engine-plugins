#!/usr/bin/env bash
#
# Live verification of the atlas-metrics engine against a real Atlas cluster.
#
# Opt-in and read-only: it runs every engine command (which can only issue
# allowlisted GETs) and prints a summary with no hostnames, project IDs or
# query text, so the result can be pasted into the public verification record.
#
# Usage:
#   tests/live/atlas_metrics_live.sh --cluster <name> [--project-id <id>] [--atlas-profile <p>]
#                                    [--namespace db.coll] [--search-namespace db.coll]
#                                    [--end <ISO time>]
#
#   --end measures every window back from that time instead of from now. Use it for
#   a paused cluster, with a time just before it last reported (atlas-metrics hosts).
#
# Exit codes: 0 = every command ran (0/1/4 are all "ran"), 1 = at least one
# command failed with a usage or CLI error (2/3).

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AM="${REPO_ROOT}/plugins/aae/scripts/atlas-metrics.sh"
TARGET=()
NAMESPACE=""
SEARCH_NS=""
CLUSTER=""
END=""

while [ $# -gt 0 ]; do
  case "$1" in
    --cluster)          CLUSTER="$2"; TARGET+=(--cluster "$2"); shift 2 ;;
    --project-id)       TARGET+=(--project-id "$2"); shift 2 ;;
    --atlas-profile)    TARGET+=(--atlas-profile "$2"); shift 2 ;;
    --namespace)        NAMESPACE="$2"; shift 2 ;;
    --search-namespace) SEARCH_NS="$2"; shift 2 ;;
    --end)              END="$2"; shift 2 ;;
    -h|--help)          sed -n '2,/^set -uo/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)                  echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "$CLUSTER" ] || { echo "error: --cluster is required" >&2; exit 2; }

OUT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/atlas-metrics-live.XXXXXX")"
FAILED=0

# win <span>: window flags. Relative to now (--last) by default; with --end, an
# explicit window ending there, which also works on a paused cluster.
win() {
  if [ -z "$END" ]; then printf -- '--last %s' "$1"; return; fi
  python3 - "$END" "$1" <<'PY'
import datetime as d, re, sys
end = d.datetime.fromisoformat(sys.argv[1].replace("Z", "+00:00"))
n, unit = re.match(r"(\d+)([mhd])$", sys.argv[2]).groups()
span = d.timedelta(**{{"m": "minutes", "h": "hours", "d": "days"}[unit]: int(n)})
fmt = "%Y-%m-%dT%H:%M:%SZ"
print(f"--start {(end - span).strftime(fmt)} --end {end.strftime(fmt)}")
PY
}

summarize() {  # summarize <label> <rc> <json file> <stderr file>
  python3 - "$@" <<'EOF'
import json, re, sys
HOST = re.compile(r"[A-Za-z0-9-]+(\.[A-Za-z0-9-]+){2,}(:\d+)?")
HEX = re.compile(r"\b[0-9a-f]{24}\b")
def clean(text):
    return HEX.sub("<id>", HOST.sub("<host>", text)).replace("|", "/")
label, rc, out_path, err_path = sys.argv[1:5]
try:
    d = json.load(open(out_path))
except Exception:
    err = open(err_path).read().strip().splitlines()
    print(f"| {label} | {rc} | — | — | {clean(err[-1] if err else '')[:160]} |")
    sys.exit(0)
rows = ", ".join(f"{clean(s['title'])[:40]}: {len(s['rows'])}" for s in d.get("sections", []))
warn = "; ".join(clean(w)[:90] for w in d.get("atlasWarnings", [])) or ""
print(f"| {label} | {rc} | {d.get('verdict')} | {rows} | {warn} |")
EOF
}

run() {  # run <label> <engine args...>
  local label="$1"; shift
  local out="${OUT_DIR}/$(echo "$label" | tr ' /' '__').json" err="${OUT_DIR}/$(echo "$label" | tr ' /' '__').err"
  "$AM" "$@" --format json >"$out" 2>"$err"
  local rc=$?
  case "$rc" in 0|1|4) : ;; *) FAILED=$((FAILED + 1)) ;; esac
  summarize "$label" "$rc" "$out" "$err"
}

echo "atlas CLI: $(atlas --version 2>/dev/null | head -1)   date: $(date -u +%Y-%m-%dT%H:%MZ)"
echo
echo "| command | exit | verdict | sections: rows | Atlas warnings / error |"
echo "|---|---|---|---|---|"
"$AM" doctor "${TARGET[@]}" >"${OUT_DIR}/doctor.txt" 2>&1; echo "| doctor | $? | — | see below | |"
run "hosts"                      hosts "${TARGET[@]}"
run "snapshot overview"          snapshot "${TARGET[@]}" $(win 15m)
for p in cpu memory-cache operations latency query-efficiency connections replication concurrency network errors; do
  run "snapshot $p"              snapshot "${TARGET[@]}" --profile "$p" --nodes primary $(win 15m)
done
run "history 24h compare 1d"     history "${TARGET[@]}" $(win 24h) --compare 1d --nodes primary
run "history 7d"                 history "${TARGET[@]}" $(win 7d) --nodes primary
run "history 10s granularity"    history "${TARGET[@]}" $(win 30m) --granularity PT10S --nodes primary
run "storage"                    storage "${TARGET[@]}" $(win 6h)
run "collections"                collections "${TARGET[@]}" $(win 24h)
[ -n "$NAMESPACE" ] && run "collections percentiles" collections "${TARGET[@]}" $(win 24h) \
                                   --namespace "$NAMESPACE" --profile collection-percentiles
run "query-shapes"               query-shapes "${TARGET[@]}" $(win 24h)
run "search hardware"            search "${TARGET[@]}" $(win 24h) --nodes all
[ -n "$SEARCH_NS" ] && run "search index" search "${TARGET[@]}" $(win 24h) --namespace "$SEARCH_NS"
run "advisor"                    advisor "${TARGET[@]}" $(win 24h)
# incident always needs an explicit --start, even without --end.
if [ -n "$END" ]; then INCIDENT_WIN="$(win 2h)"; else
  INCIDENT_WIN="--start $(python3 -c 'import datetime as d; print((d.datetime.now(d.timezone.utc)-d.timedelta(hours=2)).strftime("%Y-%m-%dT%H:%M:%SZ"))')"
fi
run "incident 2h"                incident "${TARGET[@]}" $INCIDENT_WIN
echo
echo "doctor:"
grep -E '^(atlas CLI|authentication|commands|config|cluster)' "${OUT_DIR}/doctor.txt" \
  | sed -E 's/[A-Za-z][A-Za-z0-9-]*(\.[A-Za-z0-9-]+){2,}(:[0-9]+)?/<host>/g; s/[0-9a-f]{24}/<id>/g; s/mdb_sa_id_[0-9a-f]+/mdb_sa_id_…/g'
echo
echo "raw JSON (contains hostnames; do not publish): ${OUT_DIR}"
[ "$FAILED" -eq 0 ]
