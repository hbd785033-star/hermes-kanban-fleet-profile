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
4. Coder inspects the task graph before terminating. The default code-review strategy is same-card review: with no pre-created downstream review/QA/release child, the Coder calls native `kanban_request_review` with compact evidence. When such a child exists, the Coder calls `kanban_complete` and does not also request same-card review.
5. Reviewer independently passes/completes or calls `kanban_request_changes`; review never consumes blocker recurrence accounting. Separate review children are reserved for genuinely separate security, QA, release, or architecture deliverables.
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

## Portable Serena MCP setup for Windows

[`scripts/setup-serena-mcp.ps1`](scripts/setup-serena-mcp.ps1) configures Serena as a lifecycle-managed stdio MCP server for the Hermes `default` Profile. It is separate from the disabled historical Fleet installer and does not modify Fleet policy or specialist Profiles.

### Purpose and routing

The token-safe navigation path remains intentionally selective:

```text
Hermes Native Tools
  -> Serena when semantic cross-file navigation is useful
  -> Repomix only when repository scope remains broad or unknown
```

Serena is an optional semantic escalation, not a dependency for every task. Repomix is not an automatic fallback merely because Serena is unavailable.

### Architecture and profile scope

- **Transport:** stdio. Hermes starts and stops Serena with the MCP session.
- **Why not persistent HTTP:** current single-agent usage does not justify a manually maintained server on port 9121. Stdio avoids forgotten background servers and keeps project lifecycles isolated.
- **Project selection:** `--project-from-cwd` activates the nearest Git or Serena project boundary.
- **Profiles:** Serena is enabled only for `default`. It remains absent from `orchestrator`, `researcher`, `coder`, and `reviewer`.

The script discovers the machine-local Serena executable instead of publishing a user-specific path. It checks `PATH`, the current `uv tool` executable directory, and the current user's supported local tool location. It also inspects `uv`, `uvx`, and `uv tool list`, then validates the installed Serena CLI contract before touching Hermes. The validated work-PC distribution identity is `serena-agent` (`uv tool list`: Serena 1.7.0); the executable path remains machine-local.

If Serena is absent, the script exits with `SERENA_NOT_INSTALLED` and does not install anything. Install it explicitly, then rerun the setup:

```powershell
uv tool install serena-agent
```

An HTTP-only Serena entry is the deterministic legacy case: the script backs up the active default Profile config and replaces only that entry with stdio. Any unexpected or conflicting Serena entry reports `SERENA_CONFIG_CONFLICT` and is preserved. A conflicting stdio entry can be replaced only after explicit review:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-serena-mcp.ps1 -ReplaceExisting
```

`-ExecutionPolicy Bypass` applies only to that child PowerShell process; the script does not change machine or user execution-policy settings.

A replacement backs up only the active default Profile's `config.yaml`. Other MCP servers, Profiles, credentials, approval settings, and Fleet configuration are left alone.

### Work or home PC setup

```powershell
# 1. Clone once, or pull an existing checkout.
git clone https://github.com/hbd785033-star/hermes-kanban-fleet-profile.git
cd hermes-kanban-fleet-profile
# Existing checkout: git pull --ff-only

# 2. Confirm compatible local tools.
hermes --version
Get-Command uv -ErrorAction SilentlyContinue
Get-Command uvx -ErrorAction SilentlyContinue
uv tool list
serena --version

# 3. Configure and test the default Profile.
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-serena-mcp.ps1
```

Success ends with `MCP verification: PASS`. A correct rerun reports `ALREADY_CONFIGURED`, performs verification, and does not rewrite the config.

For a local semantic smoke, create a disposable Git repository containing one small source file, start Hermes from that repository, and make exactly one read-only Serena `get_symbols_overview` call. Confirm the expected symbols, an empty tracked/staged diff, and no orphan Serena process. Serena may create untracked `.serena/` project metadata or symbol caches; report those separately from source changes.

Publishing this repository does not repair another PC automatically. Each machine must clone or pull, install compatible local prerequisites explicitly, run the setup script, and perform its own MCP and semantic smoke. Machine-local executable paths are discovered and stored only in that machine's Hermes configuration.

## Secrets and state

This repository contains no API keys, OAuth tokens, `.env`, `auth.json`, memories, sessions, state databases, Kanban task databases, gateway tokens, cron jobs, MCP credentials, or project repositories. `terminal_home_mode: auto` preserves the real OS home for host CLIs.
