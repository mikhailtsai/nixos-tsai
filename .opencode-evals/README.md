# Harness evaluation journal

This directory stores lightweight, repository-local evidence about how the agent workflow performs on real work.

## runs.jsonl

Append one JSON object per completed substantial task. Do not log prompts, source code, secrets, personal data, or raw telemetry here.

Schema:

```json
{"ts":"2026-09-30T12:00:00Z","task":"short-label","category":"bugfix","outcome":"PASS","agents":["researcher","implementer","reviewer"],"retries":0,"checks":{"passed":3,"failed":0},"review_findings":0,"architect":false,"oracle":false,"human_correction":false,"notes":[]}
```

Allowed outcomes: `PASS`, `FAIL`, `HUMAN_CORRECTION`, `REGRESSION`.

Keep `task` and `notes` short and non-sensitive. A human correction discovered after the system claimed completion is especially valuable evidence.

`outcome`, `agents`, and `retries` are required. `agents` must be a non-empty list of shipped agent names and `retries` must be a non-negative integer. When present, `architect`, `oracle`, and `human_correction` must be booleans.

Quantitative token/cost/cache telemetry is not stored here; use Codeburn for that. This journal complements, rather than replaces, observability traces.
