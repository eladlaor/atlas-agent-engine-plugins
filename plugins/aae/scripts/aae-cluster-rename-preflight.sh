#!/usr/bin/env bash
#
# aae-cluster-rename-preflight.sh — read-only go/no-go check before migrating an
# Atlas Agent Engine workspace onto a differently-named Atlas cluster.
#
# WHY THIS EXISTS
#
# Atlas clusters cannot be renamed. Not in the UI, not in the Admin API, not in
# `atlas clusters update` — the name is part of the deployment's identity and of
# its SRV hostname, so "renaming" one is really: create a second cluster, move
# the data, repoint Agent Engine, delete the first. That is a migration, and a
# migration half-run against a mis-stated precondition is how a workspace ends
# up pointing at an empty cluster with its checkpoints stranded on a cluster
# someone already deleted.
#
# Every check here is a GET. The script creates nothing, deletes nothing and
# changes no link. It exists so the destructive phases that follow start from
# facts rather than from assumptions, and so the common stoppers — a user-account
# Atlas profile that will expire mid-run, a free-tier target, a source cluster
# with no backups, a target name already taken — surface in the first ten seconds
# instead of twenty minutes in.
#
# THE ONE CHECK PEOPLE ARE SURPRISED BY
#
# `atlas` being "logged in" is not enough. A user-account login carries a
# refresh token that expires, and the Atlas CLI reports "session expired"
# mid-command; a migration is long enough to hit that window. This script
# therefore demands a SERVICE ACCOUNT and fails on a user account, which is the
# precondition an unattended run is built on.
#
# Usage:
#   aae-cluster-rename-preflight.sh --target <new-cluster-name> [--agent-dir <dir>]
#
# Exit codes: 0 = all checks passed (safe to proceed), 1 = at least one blocker,
#             2 = usage error.

set -uo pipefail

TARGET=""
AGENT_DIR="$PWD"
BLOCKERS=0
WARNINGS=0

usage() {
  sed -n '2,/^set -uo/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --target)    TARGET="${2:-}"; shift 2 ;;
    --agent-dir) AGENT_DIR="${2:-}"; shift 2 ;;
    -h|--help)   usage ;;
    *)           printf 'unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

[ -n "$TARGET" ] || { printf 'error: --target <new-cluster-name> is required\n' >&2; exit 2; }

ok()    { printf '  \033[32mOK\033[0m      %s\n' "$1"; }
block() { printf '  \033[31mBLOCKER\033[0m %s\n' "$1"; BLOCKERS=$((BLOCKERS + 1)); }
warn()  { printf '  \033[33mWARN\033[0m    %s\n' "$1"; WARNINGS=$((WARNINGS + 1)); }
head_() { printf '\n%s\n' "$1"; }

jqf() { python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
for k in sys.argv[1].split("."):
    if isinstance(d, list):
        try: d = d[int(k)]
        except Exception: sys.exit(1)
    elif isinstance(d, dict) and k in d:
        d = d[k]
    else:
        sys.exit(1)
print(d if not isinstance(d, (dict, list)) else json.dumps(d))
' "$1" 2>/dev/null; }

# ---------------------------------------------------------------- toolchain
head_ "Toolchain"

if command -v atlas >/dev/null 2>&1; then
  ok "atlas CLI present ($(atlas --version 2>/dev/null | head -1))"
else
  block "atlas CLI not installed — this procedure is built on it. See https://www.mongodb.com/docs/atlas/cli/current/install-atlas-cli/"
fi

if command -v agentengine >/dev/null 2>&1; then
  ok "agentengine CLI present ($(agentengine --version 2>/dev/null | head -1))"
else
  block "agentengine CLI not installed"
fi

command -v mongodump >/dev/null 2>&1 \
  && ok "mongodump present (fallback migration path available)" \
  || warn "mongodump absent — only the Cloud Backup restore path is available"

# ------------------------------------------------------------------- atlas auth
head_ "Atlas authentication"

# What the atlas CLI actually reads. A service account is a client ID + secret;
# a user-account login (browser/PKCE since atlascli 1.60.0, device flow before
# that, now kept as `--authType UserAccountLegacy`) is an access + refresh token
# pair that expires. Profiles written with `atlas config set` carry no
# `auth_type`, so a service-account profile is recognised by its fields.
PROFILE="${ATLAS_PROFILE:-default}"
SA_ENV_HINT="export MONGODB_ATLAS_CLIENT_ID and MONGODB_ATLAS_CLIENT_SECRET, or point ATLAS_PROFILE at a service-account profile"
USER_ACCOUNT_WHY="Its refresh token expires (atlas reports 'session expired') and will fail mid-migration. Create a service account with Project Owner on the target project, then ${SA_ENV_HINT}."

profile_field() { jqf "$1" <<<"$PROFILE_JSON"; }

if [ -n "${MONGODB_ATLAS_SERVICE_ACCOUNT_CLIENT_ID:-}${MONGODB_ATLAS_SERVICE_ACCOUNT_CLIENT_SECRET:-}" ]; then
  warn "MONGODB_ATLAS_SERVICE_ACCOUNT_CLIENT_ID / _SECRET are set, but the atlas CLI does not read those names; it reads MONGODB_ATLAS_CLIENT_ID / MONGODB_ATLAS_CLIENT_SECRET"
fi

if [ -n "${MONGODB_ATLAS_CLIENT_ID:-}" ] && [ -n "${MONGODB_ATLAS_CLIENT_SECRET:-}" ]; then
  ok "service account supplied via environment (MONGODB_ATLAS_CLIENT_ID / _SECRET)"
elif [ -n "${MONGODB_ATLAS_CLIENT_ID:-}${MONGODB_ATLAS_CLIENT_SECRET:-}" ]; then
  block "only one of MONGODB_ATLAS_CLIENT_ID / MONGODB_ATLAS_CLIENT_SECRET is set; a service account needs both"
elif [ -n "${MONGODB_ATLAS_ACCESS_TOKEN:-}${MONGODB_ATLAS_REFRESH_TOKEN:-}" ]; then
  block "MONGODB_ATLAS_ACCESS_TOKEN / _REFRESH_TOKEN are USER-account tokens. ${USER_ACCOUNT_WHY}"
elif ! command -v atlas >/dev/null 2>&1; then
  block "cannot inspect Atlas credentials without the atlas CLI"
elif ! PROFILE_JSON="$(atlas config describe "$PROFILE" -o json 2>&1)"; then
  block "atlas profile '${PROFILE}' could not be read (${PROFILE_JSON##*$'\n'}). ${SA_ENV_HINT}."
else
  AUTH_TYPE="$(profile_field auth_type)"
  # 1.60.0 spells it UserAccount / UserAccountLegacy; older profiles user_account.
  AUTH_TYPE_NORM="$(printf '%s' "$AUTH_TYPE" | tr '[:upper:]' '[:lower:]' | tr -d '_')"
  if [ -n "$(profile_field client_id)" ] && [ -n "$(profile_field client_secret)" ]; then
    ok "profile '${PROFILE}' authenticates with a service account (client_id + client_secret)"
  elif [ "$AUTH_TYPE_NORM" = "useraccountlegacy" ]; then
    block "profile '${PROFILE}' is a USER account on the deprecated device-code flow (UserAccountLegacy; atlascli 1.60.0 converted it). ${USER_ACCOUNT_WHY}"
  elif [ "$AUTH_TYPE_NORM" = "useraccount" ]; then
    block "profile '${PROFILE}' is a USER account (atlas auth login). ${USER_ACCOUNT_WHY}"
  elif [ -n "$(profile_field access_token)$(profile_field refresh_token)" ]; then
    block "profile '${PROFILE}' holds user-login tokens but no service-account client_id / client_secret. ${USER_ACCOUNT_WHY}"
  elif [ -n "$(profile_field client_id)" ]; then
    block "profile '${PROFILE}' has a client_id but no client_secret; set it with atlas config set client_secret -P ${PROFILE}"
  else
    block "no usable Atlas credential found in profile '${PROFILE}' (auth_type '${AUTH_TYPE:-unset}'). To fix, ${SA_ENV_HINT}."
  fi
fi

# --------------------------------------------------------------- local state
head_ "Workspace state"

STATE="${AGENT_DIR}/.agentengine/state.json"
WS_ID=""; PROJECT_ID=""; SRC_CLUSTER=""; DB_USER=""

if [ ! -f "${AGENT_DIR}/agent.yaml" ]; then
  block "no agent.yaml in ${AGENT_DIR} — run from the agent directory, the one the CLI resolves the workspace from"
fi

if [ -f "$STATE" ]; then
  ok "state.json found"
  read -r WS_ID PROJECT_ID SRC_CLUSTER DB_USER <<<"$(python3 -c '
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    print("- - - -"); sys.exit(0)
ctx = (d.get("pin") or {}).get("context_id")
reg = (d.get("registrations") or {}).get(ctx) or {}
atlas = reg.get("atlas") or {}
print(reg.get("workspace_id") or "-",
      atlas.get("atlas_project_id") or "-",
      atlas.get("cluster_name") or "-",
      atlas.get("database_user") or "-")
' "$STATE" 2>/dev/null)"

  [ "$WS_ID" != "-" ]       && ok "workspace: ${WS_ID}"           || block "no workspace_id in state.json — supply --workspace-id explicitly and do not guess"
  [ "$PROJECT_ID" != "-" ]  && ok "atlas project: ${PROJECT_ID}"  || block "no atlas_project_id recorded"
  [ "$SRC_CLUSTER" != "-" ] && ok "source cluster: ${SRC_CLUSTER}" || block "no cluster_name recorded"
  # Read, never reconstruct: the user is agent-engine-<full ws id>, and the ws id
  # already starts with "ws-", so the obvious template doubles the prefix.
  [ "$DB_USER" != "-" ]     && ok "database user: ${DB_USER}"     || warn "no database_user recorded — atlas setup will recreate one"
else
  block "no .agentengine/state.json under ${AGENT_DIR}"
fi

[ "$SRC_CLUSTER" = "$TARGET" ] && block "target name '${TARGET}' is the source cluster's current name — nothing to do"

# ------------------------------------------------------------------- clusters
head_ "Clusters"

if [ "$BLOCKERS" -eq 0 ] && [ -n "$PROJECT_ID" ] && [ "$PROJECT_ID" != "-" ]; then
  CLUSTERS="$(atlas clusters list --projectId "$PROJECT_ID" ${ATLAS_PROFILE:+-P "$ATLAS_PROFILE"} -o json 2>/dev/null)"
  if [ -z "$CLUSTERS" ]; then
    block "could not list clusters in project ${PROJECT_ID} — check the service account has Project Owner there"
  else
    SRC_JSON="$(printf '%s' "$CLUSTERS" | python3 -c '
import json, sys
name = sys.argv[1]
d = json.load(sys.stdin)
for c in (d.get("results") if isinstance(d, dict) else d) or []:
    if c.get("name") == name:
        print(json.dumps(c)); break
' "$SRC_CLUSTER" 2>/dev/null)"

    if [ -n "$SRC_JSON" ]; then
      TIER="$(printf '%s' "$SRC_JSON" | jqf replicationSpecs.0.regionConfigs.0.electableSpecs.instanceSize)"
      [ -z "$TIER" ] && TIER="$(printf '%s' "$SRC_JSON" | jqf clusterType)"
      ok "source cluster '${SRC_CLUSTER}' reachable (tier: ${TIER:-unknown})"
      case "$TIER" in
        M0|M2|M5) block "source is a free/shared tier (${TIER}); Agent Engine does not support it and it has no backups to restore from" ;;
      esac
      PAUSED="$(printf '%s' "$SRC_JSON" | jqf paused)"
      [ "$PAUSED" = "True" ] && block "source cluster is PAUSED — resume it and let it serve connections before migrating"
      BACKUP="$(printf '%s' "$SRC_JSON" | jqf backupEnabled)"
      [ "$BACKUP" = "True" ] \
        && ok "Cloud Backup enabled — snapshot restore path available" \
        || warn "Cloud Backup disabled on the source — you must use mongodump/mongorestore"
    else
      block "source cluster '${SRC_CLUSTER}' not found in project ${PROJECT_ID}"
    fi

    printf '%s' "$CLUSTERS" | python3 -c '
import json, sys
name = sys.argv[1]
d = json.load(sys.stdin)
sys.exit(0 if any(c.get("name") == name for c in (d.get("results") if isinstance(d, dict) else d) or []) else 1)
' "$TARGET" 2>/dev/null \
      && block "target name '${TARGET}' is already taken in this project" \
      || ok "target name '${TARGET}' is free"
  fi
else
  warn "skipped cluster checks — resolve the blockers above first"
fi

# ---------------------------------------------------------------- egress link
head_ "Platform link"

if command -v agentengine >/dev/null 2>&1 && [ -f "${AGENT_DIR}/agent.yaml" ]; then
  STATUS="$(cd "$AGENT_DIR" && agentengine atlas status 2>&1)"
  printf '%s' "$STATUS" | grep -qi "egress sync: ok" \
    && ok "egress sync: ok" \
    || warn "egress sync is not ok right now — re-check after the migration; 'No clusters' means Atlas is still provisioning"
else
  warn "skipped — agentengine unavailable or not in an agent directory"
fi

# -------------------------------------------------------------------- verdict
head_ "Verdict"

if [ "$BLOCKERS" -gt 0 ]; then
  printf '  NO-GO — %d blocker(s), %d warning(s). Fix the blockers before any destructive step.\n\n' "$BLOCKERS" "$WARNINGS"
  exit 1
fi

printf '  GO — 0 blockers, %d warning(s).\n' "$WARNINGS"
printf '  Source: %s   Target: %s   Project: %s   Workspace: %s\n\n' \
  "$SRC_CLUSTER" "$TARGET" "$PROJECT_ID" "$WS_ID"
exit 0
