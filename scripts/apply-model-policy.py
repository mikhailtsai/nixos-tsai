#!/usr/bin/env python3
"""Apply a model policy to agent markdown files.

Usage: apply-model-policy.py <agents_dir> <policy.json>

Rewrites the top-level `model:` field of each `*.md` agent whose name appears in
the policy's `agents` map. Used by install.sh to produce the normal/cheap variants.
"""
import json
import re
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: apply-model-policy.py <agents_dir> <policy.json>", file=sys.stderr)
        return 2

    agents_dir = Path(sys.argv[1])
    policy_path = Path(sys.argv[2])
    if not agents_dir.is_dir():
        print(f"error: agents dir not found: {agents_dir}", file=sys.stderr)
        return 2
    try:
        policy = json.loads(policy_path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        print(f"error: cannot read policy {policy_path}: {exc}", file=sys.stderr)
        return 2

    mapping = policy.get("agents", {})
    if not isinstance(mapping, dict):
        print("error: policy 'agents' must be an object", file=sys.stderr)
        return 2

    changed = 0
    missing = []
    for path in sorted(agents_dir.glob("*.md")):
        model = mapping.get(path.stem)
        if not model:
            missing.append(path.stem)
            continue
        text = path.read_text(encoding="utf-8")
        updated, count = re.subn(r"(?m)^model: .*$", f"model: {model}", text, count=1)
        if count == 0:
            print(f"warning: {path} has no model field", file=sys.stderr)
            continue
        if updated != text:
            path.write_text(updated, encoding="utf-8")
            changed += 1

    if missing:
        print(f"warning: no model in policy for: {', '.join(sorted(missing))}", file=sys.stderr)
    print(f"Applied '{policy.get('variant', '?')}' model policy to {changed} agent file(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
