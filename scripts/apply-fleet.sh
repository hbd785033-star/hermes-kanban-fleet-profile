#!/usr/bin/env bash
set -euo pipefail

SOURCE_PROFILE="${HERMES_FLEET_SOURCE_PROFILE:-default}"
PROVIDER="${HERMES_FLEET_PROVIDER:-CCSwitch}"
MODEL="${HERMES_FLEET_MODEL:-gpt-5.6-sol}"

create_or_update_profile() {
  local name="$1"
  local description="$2"
  if hermes profile list | awk '{print $1}' | grep -qx "$name"; then
    echo "Profile exists: $name"
  else
    hermes profile create "$name" --clone-from "$SOURCE_PROFILE" --description "$description"
  fi
  hermes profile describe "$name" --text "$description"
  hermes -p "$name" config set model.provider "$PROVIDER"
  hermes -p "$name" config set model.default "$MODEL"
}

ORCHESTRATOR_DESC="Owns complex multi-stage Kanban tasks. Decomposes goals, creates and links tasks, routes work to specialist profiles, monitors dependencies and blockers, reviews completion evidence, and creates follow-up tasks when needed. Does not perform normal implementation work when a suitable specialist exists."
RESEARCHER_DESC="Research specialist for web research, documentation, GitHub repositories, source-code reading, technical comparison, evidence gathering, and architecture analysis. Produces sourced findings and clear handoffs. Does not perform large implementation changes."
CODER_DESC="Software implementation specialist for coding, debugging, refactoring, repository work, tests, linting, builds, and verified code changes. May delegate suitable implementation work to Codex or Claude Code when available, but remains responsible for verification evidence."
REVIEWER_DESC="Independent reviewer for code review, architecture review, security review, Git diffs, tests, acceptance criteria, regressions, and evidence verification. Reports blockers and severity clearly. Defaults to review-only and should not silently fix the implementation it is judging."

create_or_update_profile orchestrator "$ORCHESTRATOR_DESC"
create_or_update_profile researcher "$RESEARCHER_DESC"
create_or_update_profile coder "$CODER_DESC"
create_or_update_profile reviewer "$REVIEWER_DESC"

# Role-oriented CLI toolsets. Kanban worker tools are dispatcher-gated and injected at task runtime.
hermes -p orchestrator tools enable skills todo memory session_search clarify || true
hermes -p orchestrator tools disable web browser terminal file code_execution vision image_gen bfl tts delegation cronjob computer_use || true

hermes -p researcher tools enable web browser terminal file code_execution vision skills todo memory session_search clarify || true
hermes -p researcher tools disable image_gen bfl tts delegation cronjob computer_use || true

hermes -p coder tools enable web browser terminal file code_execution vision skills todo memory session_search clarify || true
hermes -p coder tools disable image_gen bfl tts delegation cronjob computer_use || true

hermes -p reviewer tools enable terminal file code_execution skills todo memory session_search clarify || true
hermes -p reviewer tools disable web browser vision image_gen bfl tts delegation cronjob computer_use || true

hermes config set kanban.dispatch_in_gateway true
hermes config set kanban.orchestrator_profile orchestrator
hermes config set kanban.default_assignee default
hermes config set kanban.auto_decompose true
hermes config set kanban.review_dispatch true
hermes config set auxiliary.kanban_decomposer.provider "$PROVIDER"
hermes config set auxiliary.kanban_decomposer.model "$MODEL"

echo "Hermes Kanban fleet profile configuration applied."
hermes profile list
hermes kanban assignees
