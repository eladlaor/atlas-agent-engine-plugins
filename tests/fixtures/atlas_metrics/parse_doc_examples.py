"""Parse every `$AM <command> ...` example in the metrics skills and guide.

Usage: parse_doc_examples.py <repo root>. Prints `SEEN <n>` and one
`BAD <file>: <command>` line per example the real argument parser rejects.
"""

import contextlib
import io
import re
import shlex
import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "plugins" / "aae" / "scripts"))

from atlas_metrics.cli import build_parser  # noqa: E402 - path set above

files = sorted(root.glob("plugins/aae/skills/atlas-metrics-*/SKILL.md"))
files.append(root / "knowledge/atlas_metrics/ATLAS_METRICS_USER_GUIDE.md")
parser = build_parser()
seen = 0
for path in files:
    text = re.sub(r"\\\n\s*", " ", path.read_text())  # join continued lines
    for line in text.splitlines():
        match = re.match(r"^\s*\$AM\s+(.*)$", line)
        if not match:
            continue
        command = re.sub(r"<[^>]+>", "x", match.group(1).split("#")[0])
        seen += 1
        try:
            with contextlib.redirect_stderr(io.StringIO()):
                parser.parse_args(shlex.split(command))
        except SystemExit:
            print(f"BAD {path.name}: {command.strip()}")
print("SEEN", seen)
