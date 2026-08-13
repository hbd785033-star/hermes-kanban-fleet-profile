# Hermes Kanban Fleet Profile

Minimal Hermes native multi-agent profile fleet for Kanban routing.

This repository is a non-secret template for recreating a small Hermes execution team:

- `default` - unchanged fallback/generalist profile
- `orchestrator` - owns decomposition, routing, dependencies, blockers, and completion judgement
- `researcher` - gathers evidence from docs, web, GitHub, and source code
- `coder` - implements, debugs, tests, lints, builds, and verifies code changes
- `reviewer` - independently reviews diffs, evidence, risk, regressions, and acceptance criteria

## What This Repo Contains

- Profile descriptions used by Hermes Kanban decomposer routing
- Role SOUL append snippets
- A reproducible apply script using supported `hermes` CLI commands
- Non-sensitive Kanban routing settings

## What This Repo Does Not Contain

This repository intentionally does **not** include:

- API keys or OAuth tokens
- `.env`
- `auth.json`
- memories or sessions
- state databases
- Kanban task database
- gateway tokens
- cron jobs
- MCP credentials
- project repositories

## Requirements

- Hermes Agent v0.20.0 or compatible
- A working `default` profile
- A configured provider/model available to Hermes
- Optional: Codex CLI on PATH for coder delegation
- Optional: Claude Code CLI on PATH for coder delegation

## Apply

From a shell with Hermes available:

```bash
bash scripts/apply-fleet.sh
```

The script defaults to:

- provider: `CCSwitch`
- model: `gpt-5.6-sol`
- source profile: `default`

Override if needed:

```bash
HERMES_FLEET_PROVIDER='openai-codex' HERMES_FLEET_MODEL='gpt-5.6-sol' bash scripts/apply-fleet.sh
```

## Verify

```bash
hermes profile list
hermes kanban assignees
hermes config get kanban.auto_decompose
hermes config get kanban.orchestrator_profile
hermes config get kanban.default_assignee
hermes config get kanban.dispatch_in_gateway
hermes config get kanban.review_dispatch

hermes -p orchestrator -z 'Reply exactly: OK_orchestrator'
hermes -p researcher -z 'Reply exactly: OK_researcher'
hermes -p coder -z 'Reply exactly: OK_coder'
hermes -p reviewer -z 'Reply exactly: OK_reviewer'
```

## Notes

`terminal.home_mode` is left as `auto` so host-installed Hermes profiles keep using the real OS user HOME for external CLIs like `git`, `gh`, `ssh`, `npm`, Codex, and Claude Code.

The Kanban toolset is dispatcher-gated in Hermes v0.20.0. Worker/orchestrator Kanban tools are injected when a task is spawned by the Kanban dispatcher; normal sessions do not carry the Kanban schema.
