# Fleet V2.1 Context Protocol

Optimize wasted context, not useful verification. Preserve independent review, useful parallel research, deterministic tests, repair iterations with new evidence, and real E2E when appropriate.

## Thin task packet

Every child body contains only:

```text
OBJECTIVE
FROZEN INPUTS
SCOPE
ACCEPTANCE
HANDOFF
```

Do not copy root history, the full conversation, unchanged acceptance text, or repeated design narrative.

Engineering targets (not Hermes hard limits):

| Item | Target |
|---|---:|
| Child body | <= 2,500 chars; warn above 4,000 |
| Completion/review summary | <= 1,500 chars |
| Handoff metadata | <= 3 KB |
| Ordinary comment | <= 500 chars |
| Root history copied into child | 0 |
| Raw test logs in handoff | 0 |
| LLM status-polling workers | 0 |

## Structured handoff

`summary` contains only the result or conclusion. `metadata` contains only applicable references:

- candidate SHA
- changed files
- tests
- evidence pointers
- workspace/artifact pointer
- blocker category

Keep raw evidence in Git, test output, workspaces, artifacts, attachments, or Kanban events/runs. Reference it; do not destroy or paste it into operational context.

## Delta-only comments

A comment adds new information only. Do not repeat task history, prior comments, full diffs/logs, unchanged blockers, or narrative heartbeats. Use native heartbeat signals for long work, not LLM prose.

## Review model and lifecycle

Use the native review model encoded by the task graph. The default Fleet code-review strategy is same-card review: inspect `kanban_show()`; when no pre-created downstream review/QA/release child exists and the same task needs review, call `kanban_request_review`, then let the Reviewer call `kanban_complete` or `kanban_request_changes`. When a pre-created downstream review/QA/release child exists, complete the implementation task with its structured handoff and do not also request same-card review. Separate children are for genuinely separate deliverables such as security audit, QA, release validation, or architecture review.

Dependencies use links and `todo` -> `ready` promotion; do not block or poll. Engineering failures are repaired autonomously when new evidence exists. Native provider cooldown/requeue handling comes first. If Fleet-level handling is still required, retry the same unchanged external failure at most once, then record compact evidence and stop/requeue without helper fan-out.

## Human input

Workers are headless: if `HERMES_KANBAN_TASK` is set, never call `clarify`.

Use `DEPENDENCY_WAIT` for linked dependencies, `ENGINEERING_PROBLEM` for defects/tests/reviewer findings, `EXTERNAL_BLOCKER` for temporary provider/API/CI failures, and `ACCESS_OR_AUTH_REQUIRED` for missing access or authorization. Never store secret values.

Only a true owner preference, product choice, risk acceptance, human-only fact, or authorization uses this exact payload and `kanban_block(kind="needs_input")`:

```text
HUMAN_DECISION_REQUIRED

Question:
<exactly one explicit question>

Why I need you:
<one concise explanation>

Options:
A. ...
B. ...
C. ... only if needed

Recommended:
<A/B/C/none>

Consequences:
A → ...
B → ...

Reply:
A / B / C / <specific free-form value>

What happens next:
<exact next action>
```

For missing access/authorization, state what is missing, why it is needed, and the safe operator action; never include credentials.
