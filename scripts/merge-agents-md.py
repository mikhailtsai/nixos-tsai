#!/usr/bin/env python3
"""Merge the kit AGENTS.md into a project's AGENTS.md using a managed block.

Usage: merge-agents-md.py <source_agents_md> <target_agents_md>

- If the target does not exist, it is created with the kit content inside markers.
- If the target exists and already contains the markers, that block is replaced.
- Otherwise, the block is appended, preserving the project's own content.

The operation is idempotent and never deletes project-authored content.
"""
import sys
from pathlib import Path

BEGIN = "<!-- opencode-agents:begin -->"
END = "<!-- opencode-agents:end -->"


def build_block(source_text: str) -> str:
    return f"{BEGIN}\n{source_text.rstrip()}\n{END}\n"


def merge(existing: str, block: str) -> str:
    if not existing.strip():
        return block
    if BEGIN in existing and END in existing:
        pre = existing[: existing.index(BEGIN)]
        post = existing[existing.index(END) + len(END) :]
        return pre + block.rstrip() + post

    separator = "" if existing.endswith("\n") else "\n"
    return existing + separator + "\n" + block


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: merge-agents-md.py <source_agents_md> <target_agents_md>", file=sys.stderr)
        return 2

    source = Path(sys.argv[1])
    target = Path(sys.argv[2])
    try:
        block = build_block(source.read_text(encoding="utf-8"))
    except OSError as exc:
        print(f"error: cannot read source {source}: {exc}", file=sys.stderr)
        return 2

    existing = target.read_text(encoding="utf-8") if target.exists() else ""
    if BEGIN in existing and END in existing:
        action = "updated managed block in"
    elif existing:
        action = "appended managed block to"
    else:
        action = "created"

    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(merge(existing, block), encoding="utf-8")
    print(f"{action} {target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
