#!/usr/bin/env bash
#
# atlas-metrics.sh — read-only Atlas cluster metrics through the atlas CLI.
#
# The engine behind the atlas-metrics-* skills. It runs only allowlisted read
# commands (see atlas_metrics/constants.py) and never changes the cluster.
#
# Usage:
#   atlas-metrics.sh <command> [flags]     commands: hosts snapshot history storage
#                                          collections query-shapes search advisor
#                                          incident profiles doctor
#   atlas-metrics.sh <command> --help
#
# Exit codes: 0 = ok, 1 = a threshold was crossed, 2 = usage or config error,
#             3 = the atlas CLI failed, 4 = Atlas returned no data,
#             5 = internal error (a bug in the engine, not a finding).
#
# Needs: python3 (3.9+) and the atlas CLI. Nothing else.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v python3 >/dev/null 2>&1 || { echo "error: python3 is required" >&2; exit 2; }
# -E -s: ignore PYTHON* env vars and the user site dir, so a stray module cannot shadow ours.
exec python3 -E -s "${DIR}/atlas_metrics/__main__.py" "$@"
