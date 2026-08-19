# Hermes Kanban Fleet Profile — V2.1

Practical, native Hermes multi-agent orchestration: explicit DAGs, bounded concurrency, first-class review, event-driven control, human-actionable blockers, and compact durable context.

The Fleet preserves the `orchestrator`, `researcher`, `coder`, `reviewer`, and `default` fallback; useful parallel research; durable Kanban; Git worktrees; independent review; deterministic testing; and real E2E where appropriate. It removes structurally wasteful work rather than useful verification.

## Runtime baseline

Validated against installed Hermes Agent v0.20.4 (2026.8.18). V2.1 reuses installed native machinery instead of rebuilding it:

- gateway dispatcher and dependency promotion
- `kanban.max_in_progress` (host-level cap)
- memory-aware dispatch guard
- review status, request-review/request-changes, and review-lane reservation
- typed blockers and provider rate-limit cooldown/requeue
- native Kanban terminal notifications
- live comments to running workers when available
- safe worktree cleanup

No Hermes upgrade is performed by this repository.

## Effective Fleet configuration

```yaml
kanban:
  auto_decompose: false
  orchestrator_profile: orchestrator
  default_assignee: default
  dispatch_in_gateway: true
  review_dispatch: true
  max_in_progress: 4
```

`auto_decompose: false` disables the auxiliary triage decomposer only. It does **not** disable dispatch: the Orchestrator creates and links the explicit DAG, and the gateway dispatcher automatically promotes and executes ready work.

`max_in_progress: 4` is an initial stability target, not cheap mode and not a permanent optimum. A later measured canary may compare 4 vs 6 without weakening independent review or useful parallelism.

## Fleet protocol

1. Orchestrator creates one necessary explicit DAG with thin task packets.
2. Dispatcher owns dependency promotion, worker spawning, run lifecycle, and review-lane fairness.
3. Orchestrator stops active polling and re-enters only on meaningful events.
4. Coder implements, verifies, and calls native `kanban_request_review` with compact evidence.
5. Reviewer independently passes/completes or calls `kanban_request_changes`; review never consumes blocker recurrence accounting.
6. Engineering problems are repaired autonomously. Human interruption is reserved for genuine owner input or access/authorization.
7. Comments are delta-only; handoffs reference raw evidence instead of copying it.

See [`CONTEXT_PROTOCOL.md`](CONTEXT_PROTOCOL.md) for the thin packet, handoff budgets, blocker taxonomy, retry rule, and exact `HUMAN_DECISION_REQUIRED` payload.

## Headless-worker clarify rule

Researcher, Coder, and Reviewer profiles do not expose the `clarify` toolset. The Orchestrator retains it for legitimate live interactive use, but must never call it when `HERMES_KANBAN_TASK` is set. A worker needing true human input comments compact context, blocks with the structured payload, and resumes in a fresh run after the answer is recorded durably.

Batch clarify is present in the validated Hermes runtime but is not a V2.1 worker dependency. A future Phase 2 may evaluate a Human Decision Bridge: blocked worker -> structured payload -> live Orchestrator wake -> clarify/batch clarify -> durable answer comment -> human-origin unblock -> worker resumes.

## Repository contents

- `fleet.yaml` — declarative Fleet profiles and Kanban policy
- `profiles/*/SOUL.append.md` — concise role rules
- `CONTEXT_PROTOCOL.md` — practical context and blocker contract
- `scripts/apply-fleet.sh` — **historical V1 helper; unsafe for V2.1 and must not be executed**

The historical script still encodes V1 auto-decomposition and specialist `clarify` exposure. V2.1 intentionally does not execute or treat it as an installer. Apply the reviewed declarative configuration through supported Hermes profile/config commands in a separately authorized activation checkpoint; do not overwrite the active Fleet during repository acceptance.

## Static verification

Validate before activation:

- YAML parses with duplicate-key rejection.
- Every profile referenced by `fleet.yaml` exists in the repository.
- Config keys and review tools exist in the installed Hermes implementation.
- Specialists exclude `clarify`; Orchestrator has the conditional headless rule.
- No role creates polling/wait workers or treats review as a blocker.
- Changed paths stay inside the V2.1 allowlist.

## Secrets and state

This repository contains no API keys, OAuth tokens, `.env`, `auth.json`, memories, sessions, state databases, Kanban task databases, gateway tokens, cron jobs, MCP credentials, or project repositories. `terminal_home_mode: auto` preserves the real OS home for host CLIs.
