#!/usr/bin/env python3
"""Track the last Codeburn harness-review run.

Usage:
  python3 scripts/codeburn_state.py check [--interval-days N] [--json]
  python3 scripts/codeburn_state.py mark  [--at ISO8601]

The state file is `.opencode-evals/codeburn-state.json` (relative to the project root / CWD).
`check` exits 0 when a review is due and 2 when it is not due, so callers can branch on the code.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone

DEFAULT_STATE = ".opencode-evals/codeburn-state.json"
DEFAULT_INTERVAL_DAYS = 7


def load_state(path: str) -> dict:
    try:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
            return data if isinstance(data, dict) else {}
    except FileNotFoundError:
        return {}
    except (OSError, ValueError) as exc:
        print(f"warning: could not read {path}: {exc}", file=sys.stderr)
        return {}


def save_state(path: str, data: dict) -> None:
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2, sort_keys=True)
        handle.write("\n")


def parse_ts(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed


def cmd_check(args: argparse.Namespace) -> int:
    state = load_state(args.state)
    interval = args.interval_days if args.interval_days is not None else (state.get("interval_days") or DEFAULT_INTERVAL_DAYS)
    last = parse_ts(state.get("last_run"))
    now = datetime.now(timezone.utc)

    if last is None:
        due, age_days = True, None
    else:
        age_days = (now - last).total_seconds() / 86400.0
        due = age_days >= interval

    result = {
        "due": due,
        "last_run": state.get("last_run"),
        "age_days": None if age_days is None else round(age_days, 1),
        "interval_days": interval,
    }

    if args.json:
        print(json.dumps(result))
    elif due:
        if age_days is None:
            print(f"Codeburn review is DUE: never run (interval {interval}d). Suggest running evaluate-harness.")
        else:
            print(f"Codeburn review is DUE: last run {result['last_run']} ({result['age_days']}d ago, interval {interval}d).")
    else:
        print(f"Codeburn review not due: last run {result['last_run']} ({result['age_days']}d ago, interval {interval}d).")

    return 0 if due else 2


def cmd_mark(args: argparse.Namespace) -> int:
    state = load_state(args.state)
    stamp = args.at or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    state["last_run"] = stamp
    state.setdefault("interval_days", DEFAULT_INTERVAL_DAYS)
    save_state(args.state, state)
    print(f"Codeburn review recorded at {stamp} in {args.state}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Track the last Codeburn harness-review run.")
    parser.add_argument("--state", default=DEFAULT_STATE)
    sub = parser.add_subparsers(dest="command", required=True)

    check = sub.add_parser("check", help="report whether a Codeburn review is due")
    check.add_argument("--interval-days", type=int, default=None)
    check.add_argument("--json", action="store_true")
    check.set_defaults(func=cmd_check)

    mark = sub.add_parser("mark", help="record that a Codeburn review just ran")
    mark.add_argument("--at", default=None)
    mark.set_defaults(func=cmd_mark)

    return parser


def main() -> int:
    args = build_parser().parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
