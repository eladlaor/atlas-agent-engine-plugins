"""The only place the engine runs the atlas binary.

Two guarantees live here:

1. Read-only. A command whose argv prefix is not in READ_ONLY_COMMANDS is
   refused before anything is executed.
2. Fail fast. A non-zero exit, a timeout or output that is not JSON raises an
   AtlasCliError carrying the exact command and the CLI's own error text. There
   is no retry and no empty-result fallback: an empty table that looks like
   "all quiet" is the failure this engine exists to avoid.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
from typing import Any, Dict, List, Optional, Sequence, Tuple

from atlas_metrics.constants import (
    API_PROJECT_FLAG,
    ATLAS_BINARY_ENV,
    CLI_TIMEOUT_SECONDS,
    CURATED_OUTPUT_ARGS,
    CURATED_PROJECT_FLAG,
    DEFAULT_ATLAS_BINARY,
    CREDENTIAL_ENV_VARS,
    PROFILE_FLAG,
    READ_ONLY_COMMANDS,
    SETUP_HINT,
    AUTH_FAILURE_MARKERS,
    API_VERSIONS,
    API_VERSION_FLAG,
    INVALID_MEASUREMENT_CODE,
    ACCESS_LIST_ERROR_CODES,
    ACCESS_LIST_HINT,
)
from atlas_metrics.errors import AtlasCliError, InvalidMeasurementError, ReadOnlyViolation
from atlas_metrics.logging_setup import get_logger

log = get_logger("atlas_cli")

# Wrapper keys some `atlas api` operations put around the payload.
_ENVELOPE_KEY = "content"


def api_version(argv: Sequence[str]) -> str:
    """The pinned API version for an `atlas api <tag> <operation>` argv."""
    tag, operation = argv[1], argv[2]
    version = API_VERSIONS.get((tag, operation)) or API_VERSIONS.get(tag)
    if not version:
        raise AtlasCliError(f"no pinned API version for atlas api {tag} {operation}; "
                            "add it to constants.API_VERSIONS")
    return version


def _command_prefix(argv: Sequence[str]) -> Optional[Tuple[str, ...]]:
    for allowed in READ_ONLY_COMMANDS:
        if tuple(argv[: len(allowed)]) == allowed:
            return allowed
    return None


def _is_auth_failure(detail: str) -> bool:
    lowered = detail.lower()
    return any(marker in lowered for marker in AUTH_FAILURE_MARKERS)


FINE_GRANULARITY = "--granularity PT10S"
SERVER_ERROR_CODE = "UNEXPECTED_ERROR"
_INVALID_MEASUREMENT = re.compile(r"invalid metric name (\w+)", re.IGNORECASE)
_PARAMS_IP = re.compile(r"Params:\s*\[([0-9a-fA-F.:]+)\]")


def failure_hint(detail: str) -> str:
    """The fix for a refused call: the access list first, then the account setup."""
    if any(code in detail for code in ACCESS_LIST_ERROR_CODES):
        match = _PARAMS_IP.search(detail)
        return ACCESS_LIST_HINT.format(ip=match.group(1) if match else "your current IP")
    if _is_auth_failure(detail):
        return SETUP_HINT
    return ""


def child_environment(profile: str) -> Dict[str, str]:
    """The environment for the atlas child process.

    The CLI lets MONGODB_ATLAS_* credential variables beat any saved profile, so
    an exported key from unrelated work silently replaces the identity the user
    configured. When a profile is named explicitly, those variables are removed
    for the child so the named profile is what authenticates.
    """
    env = dict(os.environ)
    if profile:
        dropped = sorted(k for k in env if k in CREDENTIAL_ENV_VARS)
        for key in dropped:
            del env[key]
        if dropped:
            log.info("named profile wins over exported credentials",
                     extra={"atlas_profile": profile, "ignored_env": dropped})
    return env


class AtlasCli:
    """Runs read-only atlas commands for one project and one CLI profile."""

    def __init__(self, project_id: str = "", profile: str = "", binary: str = "") -> None:
        self.project_id = project_id
        self.profile = profile
        self.binary = binary or os.environ.get(ATLAS_BINARY_ENV) or DEFAULT_ATLAS_BINARY
        self.env = child_environment(profile)
        if shutil.which(self.binary) is None:
            raise AtlasCliError(
                f"atlas binary not found: {self.binary!r}. Install the MongoDB Atlas CLI "
                f"or set {ATLAS_BINARY_ENV} to its path.",
                {"binary": self.binary},
            )

    # ------------------------------------------------------------------ public

    def curated(self, argv: Sequence[str]) -> Any:
        """Run a curated command (`atlas metrics ...`, `atlas processes ...`)."""
        args = list(argv) + list(CURATED_OUTPUT_ARGS) + self._target(CURATED_PROJECT_FLAG)
        return self._run_json(argv, args)

    def api(self, argv: Sequence[str], params: Optional[Dict[str, Any]] = None) -> Any:
        """Run an `atlas api <tag> <operation>` with flag params; unwraps `content`."""
        args = (list(argv) + self._flags(params or {}) + [API_VERSION_FLAG, api_version(argv)]
                + self._target(API_PROJECT_FLAG))
        payload = self._run_json(argv, args)
        if isinstance(payload, dict) and isinstance(payload.get(_ENVELOPE_KEY), dict):
            return payload[_ENVELOPE_KEY]
        return payload

    def help_ok(self, argv: Sequence[str]) -> Tuple[bool, str]:
        """True if `atlas <argv> --help` succeeds. Used by `doctor` only."""
        self._guard(argv)
        try:
            proc = subprocess.run(
                [self.binary, *argv, "--help"],
                capture_output=True,
                text=True,
                timeout=CLI_TIMEOUT_SECONDS,
                check=False, env=self.env,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            log.error("help check failed", extra={"argv": list(argv), "error": str(exc)})
            raise AtlasCliError(f"could not run atlas {' '.join(argv)} --help: {exc}") from exc
        # The CLI prints the parent's help with exit 0 for an unknown leaf, so
        # require the leaf's own usage line rather than trusting the exit code.
        usage_line = f"atlas {' '.join(argv)}"
        return proc.returncode == 0 and usage_line in proc.stdout, proc.stdout + proc.stderr

    def text(self, argv: Sequence[str]) -> str:
        """Run an allowlisted command whose output is plain text (auth whoami).

        Carries the CLI profile but not the project: `auth whoami` must report the
        identity the data commands will use, and it takes no project flag.
        """
        self._guard(argv)
        profile_args = [PROFILE_FLAG, self.profile] if self.profile else []
        try:
            proc = subprocess.run([self.binary, *argv, *profile_args], capture_output=True, text=True,
                                  timeout=CLI_TIMEOUT_SECONDS, check=False, env=self.env)
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise AtlasCliError(f"could not run atlas {' '.join(argv)}: {exc}") from exc
        if proc.returncode != 0:
            detail = (proc.stderr or proc.stdout).strip()
            fix = failure_hint(detail)
            hint = f" {fix}" if fix else ""
            raise AtlasCliError(f"atlas {' '.join(argv)} failed: {detail}{hint}")
        return proc.stdout.strip()

    def version(self) -> str:
        """`atlas --version`. Not allowlist-checked: it is not an Atlas call."""
        try:
            proc = subprocess.run(
                [self.binary, "--version"], capture_output=True, text=True,
                timeout=CLI_TIMEOUT_SECONDS, check=False, env=self.env,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            raise AtlasCliError(f"could not run atlas --version: {exc}") from exc
        for line in proc.stdout.splitlines():
            if "version:" in line and "atlascli" in line:
                return line.split("version:", 1)[1].strip()
        raise AtlasCliError("atlas --version printed no 'atlascli version:' line",
                            {"stdout": proc.stdout[:300]})

    # ----------------------------------------------------------------- private

    def _guard(self, argv: Sequence[str]) -> None:
        if _command_prefix(argv) is None:
            log.error("refused non-allowlisted command", extra={"argv": list(argv)})
            raise ReadOnlyViolation(
                f"refusing to run 'atlas {' '.join(argv)}': it is not on the read-only "
                "allowlist in constants.Command",
                {"argv": list(argv)},
            )

    def _target(self, project_flag: str) -> List[str]:
        out: List[str] = []
        if self.project_id:
            out += [project_flag, self.project_id]
        if self.profile:
            out += [PROFILE_FLAG, self.profile]
        return out

    @staticmethod
    def _flags(params: Dict[str, Any]) -> List[str]:
        out: List[str] = []
        for key, value in params.items():
            if value is None or value == "" or value == [] or value is False:
                continue
            if value is True:  # pflag bools take no separate value
                out.append(f"--{key}=true")
                continue
            values = value if isinstance(value, (list, tuple)) else [value]
            for item in values:
                out += [f"--{key}", str(item)]
        return out

    def _run_json(self, argv: Sequence[str], full_args: Sequence[str]) -> Any:
        self._guard(argv)
        cmd = [self.binary, *full_args]
        shown = " ".join(["atlas", *full_args])
        log.info("atlas call", extra={"command": shown})
        try:
            proc = subprocess.run(
                cmd, capture_output=True, text=True, timeout=CLI_TIMEOUT_SECONDS, check=False, env=self.env
            )
        except subprocess.TimeoutExpired as exc:
            log.error("atlas timed out", extra={"command": shown})
            raise AtlasCliError(f"timed out after {CLI_TIMEOUT_SECONDS}s: {shown}") from exc
        except OSError as exc:
            log.error("atlas could not start", extra={"command": shown, "error": str(exc)})
            raise AtlasCliError(f"could not start atlas: {exc}", {"command": shown}) from exc
        if proc.returncode != 0:
            detail = (proc.stderr or proc.stdout).strip()
            rejected = _INVALID_MEASUREMENT.search(detail)
            if INVALID_MEASUREMENT_CODE in detail and rejected:
                log.info("measurement rejected", extra={"command": shown,
                                                           "measurement": rejected.group(1)})
                raise InvalidMeasurementError(rejected.group(1), f"{shown}\n  {detail}",
                                              {"command": shown})
            log.error("atlas failed", extra={"command": shown, "rc": proc.returncode,
                                             "stderr": detail[:2000]})
            fix = failure_hint(detail)
            if not fix and FINE_GRANULARITY in shown and SERVER_ERROR_CODE in detail:
                # Atlas answers PT10S it doesn't have with a bare 500, not an empty series.
                # Windows older than its 8-hour retention are refused before the call, so
                # this is a cluster without premium monitoring.
                fix = ("Atlas collects 10-second points only with premium monitoring (a project "
                       "with an M40 or larger cluster), and keeps them for 8 hours. Use "
                       "--granularity PT1M or leave it out.")
            hint = f"\n  {fix}" if fix else ""
            raise AtlasCliError(f"{shown}\n  failed (exit {proc.returncode}): {detail}{hint}",
                                {"command": shown, "rc": proc.returncode})
        text = proc.stdout.strip()
        try:
            return json.loads(text) if text else None
        except json.JSONDecodeError as exc:
            log.error("atlas returned non-JSON", extra={"command": shown, "head": text[:300]})
            raise AtlasCliError(f"{shown}\n  returned output that is not JSON: {text[:300]}",
                                {"command": shown}) from exc
