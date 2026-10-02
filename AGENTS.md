<!-- opencode-agents:begin -->
# Agent workflow

OpenCode is the runtime. This repository adds only a project-local workflow layer.
The model mapping lives in `model-policy.json` and is enforced by `scripts/check-harness.py`. The
normal variant keeps the default agents on `openrouter/deepseek/deepseek-v4.1-flash` with high
reasoning and runs the rare escalation roles (`architect`, `oracle`) on `openrouter/z-ai/glm-5.3-flash`.
The `cheap` install variant swaps in much cheaper OpenRouter models, and the `local` variant routes to
the local llama.cpp server (`llamacpp` provider). Do not escalate by habit.

## Default policy

Economical model first. The primary session may itself use the default model.
Use the default agents for almost all analysis, implementation, testing, and review.

Escalation is exceptional:
- `architect`: consequential architecture decisions, conflicting evidence, or repeated default-model failure.
- `oracle`: only when `architect` still cannot resolve a high-impact blocker.

## Map

- Existing project docs remain authoritative.
- Agent definitions live in `agents/` and install into `.opencode/agents/`.
- Reusable skills live in `.opencode/skills/` (`bootstrap-project`, `debug`, `plan`, `verify`,
  `review-loop`, `improve-harness`, `docs-gardening`, `record-outcome`, `evaluate-harness`).
- `docs/agent/` holds missing agent-facing maps; `docs/exec-plans/` holds durable plans.
- `.opencode-evals/` holds compact non-sensitive outcomes from real tasks; it is evidence for
  improving this workflow, not raw telemetry.
- `scripts/check-harness.py` and `scripts/eval-report.py` are the local validation gate.

Run `bootstrap-project` when architecture, workflows, validation, or product rules are not legible.

## Team

- `orchestrator`: primary agent; routes work to the smallest useful team and owns the outcome.
- `product-analyst`: requirements, business rules, acceptance criteria, edge cases.
- `system-analyst`: end-to-end workflows, state/data flow, integrations and boundaries.
- `researcher`: focused technical/code investigation.
- `implementer`: bounded implementation.
- `worker`: mechanical edits, commands, diagnostics and narrow fixes.
- `test-engineer`: behavioral/regression tests and validation.
- `reviewer`: correctness, regression, contracts and architecture review.
- `requirements-reviewer`: acceptance against the original request.
- `security-reviewer`: security-sensitive changed surfaces only.
- `architect`: rare architecture escalation.
- `oracle`: last-resort reasoning escalation.

## Routing

Use the smallest team that gives high confidence. Never run every role mechanically.

- tiny/mechanical → direct work or `worker`
- bug/failure → `researcher` when the root cause is unknown → `implementer` → `test-engineer`
- ambiguous feature → add `product-analyst`
- unclear cross-system flow → add `system-analyst`
- substantial/risky change → `test-engineer` + selected reviewers
- security-sensitive change → add `security-reviewer`
- acceptance uncertainty → add `requirements-reviewer`
- repeated failure or illegible environment → improve the repository, not the prompt
- complex multi-step work → decompose into bounded slices before implementing

Parallelize independent investigation and reviews.

## Handoffs

A delegation includes the exact goal, scope, known evidence, expected output, and validation.
Pass prior findings forward; do not make agents rediscover context. Distinguish evidence from
inference and escalate ambiguity instead of inventing decisions.

Keep each handoff narrow and ask for a compact summary with paths and validation results.

## Completion

For substantial work:
1. establish only missing requirements/system/code context;
2. implement in bounded slices;
3. run deterministic project checks;
4. run risk-selected independent reviews;
5. correct concrete findings;
6. re-run invalidated checks/reviews;
7. stop when evidence is clean.

Never claim a check ran when it did not. Reviewer PASS does not replace deterministic validation.

Do not spawn agents for tiny mechanical changes or work that cannot benefit from parallelism. Every
extra thread consumes tokens and context; prefer one focused agent over a broad panel.

## Repository improvement

When the same failure recurs, do not grow this file. Improve the repository: tool, test, linter,
structural check, observability, documentation, or discoverability. Prefer enforceable invariants
over prompt rules.

Keep this file a map, not a manual.

## Evaluation

Do not rely on agent self-confidence as evidence. Prefer deterministic checks, independent review,
real user corrections, regressions, and accumulated outcomes. Improve recurring failure classes
rather than reacting to isolated anecdotes. Never store prompts, secrets, source code, personal
data, or raw telemetry in any outcome journal.

The last Codeburn review is tracked in `.opencode-evals/codeburn-state.json`. The orchestrator checks
it after substantial work and suggests `evaluate-harness` when the review is due; `evaluate-harness`
records each run with `python3 scripts/codeburn_state.py mark`.
<!-- opencode-agents:end -->
