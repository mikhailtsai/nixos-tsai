#!/usr/bin/env python3
"""Structural and policy validation for the OpenCode agent workflow.

Run: python3 scripts/check-harness.py

Validates agent frontmatter, the model-routing policy, skill frontmatter, AGENTS.md
discoverability, required directories/artifacts, and the evaluation journal.
"""
from pathlib import Path
import json
import sys

try:
    import yaml
except ImportError as error:  # pragma: no cover - environment guard
    print("Harness check FAILED")
    print(f"- PyYAML is required to parse agent/skill frontmatter: {error}")
    sys.exit(1)

try:
    from eval_schema import validate_row
except ImportError as error:
    print("Harness check FAILED")
    print(f"- scripts/eval_schema.py: cannot import shared schema: {error}")
    sys.exit(1)

ROOT = Path(__file__).resolve().parents[1]

# Agents live in `agents/` in the source kit and in `.opencode/agents/` once installed.
AGENTS_DIR = ROOT / ".opencode/agents"
if not AGENTS_DIR.is_dir():
    AGENTS_DIR = ROOT / "agents"

errors = []

POLICY_PATH = ROOT / "model-policy.json"
POLICY_AGENTS = {}
if POLICY_PATH.is_file():
    try:
        POLICY_AGENTS = json.loads(POLICY_PATH.read_text(encoding="utf-8")).get("agents", {})
    except (OSError, ValueError, AttributeError) as error:
        errors.append(f"model-policy.json: invalid policy: {error}")
        POLICY_AGENTS = {}

EXPECTED_AGENTS = {
    "product-analyst",
    "system-analyst",
    "researcher",
    "implementer",
    "worker",
    "test-engineer",
    "reviewer",
    "requirements-reviewer",
    "security-reviewer",
    "architect",
    "oracle",
}
PRIMARY_AGENTS = {"orchestrator"}
ALL_AGENTS = EXPECTED_AGENTS | PRIMARY_AGENTS
EXPECTED_SKILLS = {
    "bootstrap-project",
    "debug",
    "plan",
    "verify",
    "review-loop",
    "improve-harness",
    "docs-gardening",
    "record-outcome",
    "evaluate-harness",
}


def fail(msg):
    errors.append(msg)


def read_frontmatter(path):
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---"):
        raise ValueError("missing frontmatter block")
    parts = text.split("---", 2)
    if len(parts) < 3:
        raise ValueError("unterminated frontmatter block")
    data = yaml.safe_load(parts[1])
    if not isinstance(data, dict):
        raise ValueError("frontmatter is not a mapping")
    return data


# --- Agents -----------------------------------------------------------------
agent_paths = sorted(AGENTS_DIR.glob("*.md"))
agents = {p.stem for p in agent_paths}
for name in sorted(ALL_AGENTS - agents):
    fail(f"{AGENTS_DIR.relative_to(ROOT)}/{name}.md: required agent is missing")

for path in agent_paths:
    rel = path.relative_to(ROOT)
    try:
        data = read_frontmatter(path)
    except (OSError, ValueError, yaml.YAMLError) as e:
        fail(f"{rel}: invalid frontmatter: {e}")
        continue

    for field in ("description", "model", "mode"):
        if not data.get(field):
            fail(f"{rel}: missing required field {field!r}")

    mode = data.get("mode")
    if path.stem in PRIMARY_AGENTS and mode != "primary":
        fail(f"{rel}: primary agent must use mode 'primary', got {mode!r}")
    if path.stem in EXPECTED_AGENTS and mode != "subagent":
        fail(f"{rel}: subagent must use mode 'subagent', got {mode!r}")

    model = data.get("model")
    expected = POLICY_AGENTS.get(path.stem)
    if expected is None:
        fail(f"{rel}: no model defined in model-policy.json for '{path.stem}'")
    elif model != expected:
        fail(f"{rel}: expected model {expected!r} from model-policy.json, got {model!r}")

    effort = (data.get("options") or {}).get("reasoning", {})
    effort = effort.get("effort") if isinstance(effort, dict) else None
    if effort not in {"low", "medium", "high"}:
        fail(f"{rel}: options.reasoning.effort must be low|medium|high, got {effort!r}")

# --- Skills -----------------------------------------------------------------
skill_paths = sorted((ROOT / ".opencode/skills").glob("*/SKILL.md"))
skills = {p.parent.name for p in skill_paths}
for name in sorted(EXPECTED_SKILLS - skills):
    fail(f".opencode/skills/{name}/SKILL.md: required skill is missing")

for path in skill_paths:
    rel = path.relative_to(ROOT)
    try:
        data = read_frontmatter(path)
    except (OSError, ValueError, yaml.YAMLError) as e:
        fail(f"{rel}: invalid frontmatter: {e}")
        continue
    if data.get("name") != path.parent.name:
        fail(f"{rel}: frontmatter name must match directory name {path.parent.name!r}")
    if not data.get("description"):
        fail(f"{rel}: missing description")

# --- AGENTS.md discoverability ---------------------------------------------
try:
    policy = (ROOT / "AGENTS.md").read_text(encoding="utf-8")
except OSError as error:
    fail(f"AGENTS.md: cannot read file: {error}")
    policy = ""

for name in sorted(ALL_AGENTS & agents):
    if f"`{name}`" not in policy:
        fail(f"AGENTS.md: shipped agent '{name}' is not discoverable")
for name in sorted(EXPECTED_SKILLS & skills):
    if f"`{name}`" not in policy:
        fail(f"AGENTS.md: shipped skill '{name}' is not discoverable")

# --- Required artifacts and directories ------------------------------------
required_files = [
    "AGENTS.md",
    "model-policy.json",
    ".opencode-evals/README.md",
    ".opencode-evals/runs.jsonl",
    ".opencode-evals/codeburn-state.json",
    "scripts/check-harness.py",
    "scripts/eval-report.py",
    "scripts/eval_schema.py",
    "scripts/codeburn_state.py",
    "scripts/apply-model-policy.py",
    "scripts/merge-agents-md.py",
    "docs/agent/README.md",
]
for rel in required_files:
    if not (ROOT / rel).is_file():
        fail(f"missing harness artifact: {rel}")

required_dirs = [
    str(AGENTS_DIR.relative_to(ROOT)),
    ".opencode/skills",
    ".opencode-evals",
    "docs/agent",
    "docs/exec-plans/active",
    "docs/exec-plans/completed",
]
for rel in required_dirs:
    if not (ROOT / rel).is_dir():
        fail(f"missing harness directory: {rel}")

# --- Evaluation journal -----------------------------------------------------
journal = ROOT / ".opencode-evals/runs.jsonl"
if journal.is_file():
    for n, line in enumerate(journal.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        try:
            row = json.loads(line)
        except Exception as e:
            fail(f".opencode-evals/runs.jsonl line {n}: invalid JSON: {e}")
            continue
        errors.extend(f".opencode-evals/runs.jsonl {error}" for error in validate_row(row, n, agents))

# --- Codeburn cadence state -------------------------------------------------
state_path = ROOT / ".opencode-evals/codeburn-state.json"
if state_path.is_file():
    try:
        state = json.loads(state_path.read_text(encoding="utf-8"))
    except Exception as e:
        fail(f".opencode-evals/codeburn-state.json: invalid JSON: {e}")
    else:
        if not isinstance(state, dict):
            fail(".opencode-evals/codeburn-state.json: must be a JSON object")
        else:
            last = state.get("last_run")
            if last is not None and not isinstance(last, str):
                fail(".opencode-evals/codeburn-state.json: last_run must be null or an ISO string")
            interval = state.get("interval_days")
            if type(interval) is not int or interval < 1:
                fail(".opencode-evals/codeburn-state.json: interval_days must be a positive integer")

if errors:
    print("Harness check FAILED")
    for e in errors:
        print(f"- {e}")
    sys.exit(1)

print(f"Harness check PASS: {len(agents)} agents, {len(skills)} skills")
