#!/usr/bin/env bash
set -euo pipefail

cat >&2 <<'EOF'
ERROR: scripts/apply-fleet.sh is a historical Fleet V1 helper and is disabled.
It encoded auto_decompose=true and exposed clarify to headless specialists,
which contradict Fleet V2.1. Do not execute it or use it to modify an active
installation. Apply the reviewed fleet.yaml through a separately authorized,
supported Hermes activation checkpoint.
EOF
exit 2
