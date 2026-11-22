"""Entry point: `python3 <path>/atlas_metrics <command> ...` or the atlas-metrics.sh launcher."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from atlas_metrics.cli import main  # noqa: E402 - path must be set first

if __name__ == "__main__":
    sys.exit(main())
