"""One report model for every command, rendered as table, markdown or JSON.

JSON is the stable contract for a model consuming the output; table and
markdown are for people. All three carry the same facts, including Atlas's own
warnings, which are never dropped.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from typing import Any, Dict, List

from atlas_metrics.constants import OutputFormat, Severity
from atlas_metrics.summarize import worst

_SEVERITY_MARK = {"ok": "", "warn": "WARN", "crit": "CRIT", "no-data": "no data"}


@dataclass
class Section:
    title: str
    columns: List[str]
    rows: List[List[Any]] = field(default_factory=list)
    data: List[Dict[str, Any]] = field(default_factory=list)  # machine form of the rows
    notes: List[str] = field(default_factory=list)


@dataclass
class Report:
    command: str
    title: str
    context: Dict[str, Any] = field(default_factory=dict)
    sections: List[Section] = field(default_factory=list)
    atlas_warnings: List[str] = field(default_factory=list)
    severities: List[Severity] = field(default_factory=list)

    def add_warning(self, text: str) -> None:
        if text and text not in self.atlas_warnings:
            self.atlas_warnings.append(text)

    @property
    def verdict(self) -> Severity:
        return worst(self.severities)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "command": self.command,
            "title": self.title,
            "verdict": str(self.verdict),
            "context": self.context,
            "atlasWarnings": self.atlas_warnings,
            "sections": [
                {"title": s.title, "rows": s.data or [dict(zip(s.columns, r)) for r in s.rows],
                 "notes": s.notes}
                for s in self.sections
            ],
        }


def severity_mark(value: str) -> str:
    return _SEVERITY_MARK.get(value, value)


def render(report: Report, fmt: OutputFormat) -> str:
    if fmt is OutputFormat.JSON:
        return json.dumps(report.to_dict(), indent=2, default=str)
    if fmt is OutputFormat.MARKDOWN:
        return _markdown(report)
    return _table(report)


def _cell(value: Any) -> str:
    text = "" if value is None else str(value)
    return text.replace("\n", " ")


def _table(report: Report) -> str:
    lines = [report.title, "=" * len(report.title)]
    for key, value in report.context.items():
        lines.append(f"{key}: {value}")
    if report.severities:
        lines.append(f"verdict: {report.verdict}")
    for warning in report.atlas_warnings:
        lines.append(f"ATLAS WARNING: {warning}")
    for section in report.sections:
        lines += ["", section.title, "-" * len(section.title)]
        if section.rows:
            rows = [[_cell(c) for c in row] for row in section.rows]
            widths = [max(len(h), *(len(r[i]) for r in rows)) for i, h in enumerate(section.columns)]
            lines.append("  ".join(h.ljust(widths[i]) for i, h in enumerate(section.columns)).rstrip())
            for row in rows:
                lines.append("  ".join(row[i].ljust(widths[i]) for i in range(len(row))).rstrip())
        else:
            lines.append("(no rows)")
        lines += [f"note: {n}" for n in section.notes]
    return "\n".join(lines)


def _markdown(report: Report) -> str:
    lines = [f"## {report.title}", ""]
    for key, value in report.context.items():
        lines.append(f"- **{key}:** {value}")
    if report.severities:
        lines.append(f"- **verdict:** {report.verdict}")
    for warning in report.atlas_warnings:
        lines.append(f"- **Atlas warning:** {warning}")
    for section in report.sections:
        lines += ["", f"### {section.title}", ""]
        if section.rows:
            lines.append("| " + " | ".join(section.columns) + " |")
            lines.append("|" + "---|" * len(section.columns))
            for row in section.rows:
                lines.append("| " + " | ".join(_cell(c).replace("|", "\\|") for c in row) + " |")
        else:
            lines.append("_(no rows)_")
        lines += ["", *[f"> {n}" for n in section.notes]] if section.notes else []
    return "\n".join(lines)
