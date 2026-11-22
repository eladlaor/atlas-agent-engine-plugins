"""Immutable values for the atlas-metrics engine.

Every Atlas CLI command the engine may run is named here, and nowhere else. The
CLI wrapper refuses anything that is not in READ_ONLY_COMMANDS, which is what
makes "these skills never change your cluster" a property of the code rather
than a promise in prose.

Operation names are pinned to the CLI version below. The CLI renames `atlas api`
operations between releases (the Admin API spec already calls
`getProcessMeasurements` `getGroupProcessMeasurements`), so `doctor` re-checks
every name against `--help` on the installed binary.
"""

from __future__ import annotations

from enum import Enum

ENGINE_NAME = "atlas-metrics"
VERIFIED_CLI_VERSION = "1.59.1"
ATLAS_BINARY_ENV = "ATLAS_METRICS_ATLAS_BIN"
DEFAULT_ATLAS_BINARY = "atlas"
CONFIG_PATH_ENV = "ATLAS_METRICS_CONFIG"
DEFAULT_CONFIG_RELATIVE_PATH = (".config", "atlas-metrics", "config.json")
LOG_LEVEL_ENV = "ATLAS_METRICS_LOG_LEVEL"
BUILTIN_PROFILES_FILE = "builtin_profiles.json"
CLI_TIMEOUT_SECONDS = 120

# Exit codes, shared by every command.
EXIT_OK = 0
EXIT_FINDINGS = 1  # ran fine, and at least one threshold was crossed
EXIT_USAGE = 2
EXIT_ATLAS = 3
EXIT_NO_DATA = 4


class StrValueEnum(str, Enum):
    """A string enum whose str() is its value (StrEnum needs 3.11; macOS ships 3.9)."""

    def __str__(self) -> str:
        return self.value


class Granularity(StrValueEnum):
    TEN_SECONDS = "PT10S"
    ONE_MINUTE = "PT1M"
    FIVE_MINUTES = "PT5M"
    ONE_HOUR = "PT1H"
    ONE_DAY = "P1D"


class NodeSelector(StrValueEnum):
    PRIMARY = "primary"
    SECONDARIES = "secondaries"
    ALL = "all"


class ClusterView(StrValueEnum):
    PRIMARY = "PRIMARY"
    SECONDARY = "SECONDARY"
    INDIVIDUAL_PROCESS = "INDIVIDUAL_PROCESS"


class OutputFormat(StrValueEnum):
    TABLE = "table"
    MARKDOWN = "markdown"
    JSON = "json"


class Direction(StrValueEnum):
    ABOVE = "above"
    BELOW = "below"


class Severity(StrValueEnum):
    OK = "ok"
    WARN = "warn"
    CRIT = "crit"
    NO_DATA = "no-data"


class Source(StrValueEnum):
    """Which Atlas endpoint family a profile reads from."""

    PROCESS = "process"
    DISK = "disk"
    DATABASE = "database"
    COLLECTION = "collection"
    SEARCH_INDEX = "search-index"
    SEARCH_HARDWARE = "search-hardware"


class ProcessRole(StrValueEnum):
    PRIMARY = "REPLICA_PRIMARY"
    SECONDARY = "REPLICA_SECONDARY"
    SHARD_PRIMARY = "SHARD_PRIMARY"
    SHARD_SECONDARY = "SHARD_SECONDARY"
    MONGOS = "SHARD_MONGOS"
    CONFIG = "SHARD_CONFIG"


PRIMARY_ROLES = frozenset({ProcessRole.PRIMARY.value, ProcessRole.SHARD_PRIMARY.value})
SECONDARY_ROLES = frozenset({ProcessRole.SECONDARY.value, ProcessRole.SHARD_SECONDARY.value})


class Command:
    """Argv prefixes for every CLI command the engine runs. All are reads."""

    PROCESSES_LIST = ("processes", "list")
    CLUSTERS_DESCRIBE = ("clusters", "describe")
    METRICS_PROCESSES = ("metrics", "processes")
    METRICS_DISKS_LIST = ("metrics", "disks", "list")
    METRICS_DISKS_DESCRIBE = ("metrics", "disks", "describe")
    METRICS_DATABASES_LIST = ("metrics", "databases", "list")
    METRICS_DATABASES_DESCRIBE = ("metrics", "databases", "describe")
    COLL_NAMESPACES = ("api", "collectionLevelMetrics", "getClusterNamespaces")
    COLL_MEASUREMENTS = ("api", "collectionLevelMetrics", "listCollStatMeasurements")
    COLL_PINNED = ("api", "collectionLevelMetrics", "listPinnedNamespaces")
    SHAPE_SUMMARIES = ("api", "queryShapeInsights", "listQueryShapeSummaries")
    SHAPE_DETAILS = ("api", "queryShapeInsights", "getQueryShapeDetails")
    FTS_METRIC_TYPES = ("api", "monitoringAndLogs", "listHostFtsMetrics")
    FTS_HARDWARE = ("api", "monitoringAndLogs", "listMeasurements")
    FTS_INDEXES = ("api", "monitoringAndLogs", "listIndexMeasurements")
    FTS_ONE_INDEX = ("api", "monitoringAndLogs", "getIndexMeasurements")
    AUTH_WHOAMI = ("auth", "whoami")
    ADVISOR_NAMESPACES = ("api", "performanceAdvisor", "listPerformanceAdvisorNamespaces")
    ADVISOR_SLOW_LOGS = ("api", "performanceAdvisor", "listSlowQueryLogs")
    ADVISOR_SUGGESTED = ("api", "performanceAdvisor", "listClusterSuggestedIndexes")
    ADVISOR_DROP = ("api", "performanceAdvisor", "listDropIndexSuggestions")
    ADVISOR_SCHEMA = ("api", "performanceAdvisor", "listSchemaAdvice")
    ALERTS = ("api", "alerts", "listAlerts")
    EVENTS = ("api", "events", "listGroupEvents")


READ_ONLY_COMMANDS = frozenset(
    value for key, value in vars(Command).items() if not key.startswith("_")
)

# Commands that exist on the CLI and change state. Named so a test can prove the
# allowlist above never grows to include one of them.
KNOWN_MUTATING_OPERATIONS = frozenset(
    {
        "pinNamespaces",
        "unpinNamespaces",
        "updatePinnedNamespaces",
        "enableManagedSlowMs",
        "disableManagedSlowMs",
        "updateClusterQueryShape",
        "slowOperationThreshold",
        "acknowledgeAlert",
    }
)

# Flag names, by command family. The CLI is not consistent between the curated
# commands and `atlas api`, so each family carries its own spelling.
CURATED_PROJECT_FLAG = "--projectId"
API_PROJECT_FLAG = "--groupId"
PROFILE_FLAG = "--profile"

# Variables through which the atlas CLI takes credentials or a default target.
# They outrank saved profiles, so they are removed when a profile is named.
CREDENTIAL_ENV_VARS = frozenset({
    "MONGODB_ATLAS_CLIENT_ID",
    "MONGODB_ATLAS_CLIENT_SECRET",
    "MONGODB_ATLAS_PUBLIC_API_KEY",
    "MONGODB_ATLAS_PRIVATE_API_KEY",
    "MONGODB_ATLAS_ORG_ID",
    "MONGODB_ATLAS_PROJECT_ID",
})
CURATED_OUTPUT_ARGS = ("--output", "json")

# Granularity is chosen from the window so Atlas never rejects the pair.
# (upper bound of window in seconds, granularity), checked in order.
GRANULARITY_RULES = (
    (60 * 60, Granularity.ONE_MINUTE),
    (24 * 60 * 60, Granularity.FIVE_MINUTES),
    (7 * 24 * 60 * 60, Granularity.ONE_HOUR),
)
GRANULARITY_FALLBACK = Granularity.ONE_DAY

# The identity these skills are meant to run as. Printed whenever Atlas refuses
# the credentials, because the fix is almost always this setup.
SERVICE_ACCOUNT_NAME = "atlas-metrics-readonly"
SERVICE_ACCOUNT_ROLES = ("Project Read Only", "Project Observability Viewer")
METRICS_CLI_PROFILE = "metrics"
AUTH_FAILURE_MARKERS = ("unauthorized", "not logged in", "forbidden")
SETUP_HINT = (
    "Setup: in the Atlas project that holds the cluster, create a service account "
    f"'{SERVICE_ACCOUNT_NAME}' (Project Identity & Access > Applications > Create service "
    f"account) with the roles {' + '.join(SERVICE_ACCOUNT_ROLES)}; then run "
    "`env -u MONGODB_ATLAS_CLIENT_ID -u MONGODB_ATLAS_CLIENT_SECRET atlas auth login "
    f"--profile {METRICS_CLI_PROFILE}` (choose ServiceAccount) and pass "
    f"--atlas-profile {METRICS_CLI_PROFILE}, or set defaults.atlas_profile in the config."
)

# Organizations can require every API call to come from an access-listed IP.
# The account then authenticates fine and every read fails with one of these
# codes. Atlas puts the caller's IP in "Params: [<ip>]".
ACCESS_LIST_ERROR_CODES = ("ORG_REQUIRES_ACCESS_LIST", "IP_ADDRESS_NOT_ON_ACCESS_LIST")
ACCESS_LIST_HINT = (
    "Access list: this organization only accepts API calls from listed IP addresses, and "
    "Atlas saw this request come from {ip}. Add it in the project: Project Identity & Access "
    f"> Applications > '{SERVICE_ACCOUNT_NAME}' > API Access List > Add Access List Entry, "
    "or run as a Project Owner (your own login, never the read-only profile): "
    "echo '[{{\"ipAddress\": \"{ip}\"}}]' | atlas api serviceAccounts createAccessList "
    "--groupId <project-id> --clientId <service-account-client-id> --version 2024-08-05 "
    "-P <your-owner-profile>. "
    "These skills never run that command themselves. A laptop's address changes with the "
    "network; a VPN with a fixed exit IP needs one entry."
)

DEFAULT_SNAPSHOT_WINDOW = "PT15M"
DEFAULT_HISTORY_WINDOW = "PT6H"
DEFAULT_TOP_N = 10
DEFAULT_SLOW_LOG_LINES = 50
INCIDENT_PADDING_SECONDS = 15 * 60
