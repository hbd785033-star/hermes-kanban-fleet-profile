# Security

Do not commit local Hermes runtime data or credentials.

Never add these files or directories to this repository:

- `.env`
- `auth.json`
- `state.db`
- `kanban.db`
- `sessions/`
- `memory/` or `memories/`
- `logs/`
- `cron/`
- `mcp/`
- gateway token files
- provider API keys or OAuth refresh tokens

This repository is intended to store reproducible non-secret configuration only.
