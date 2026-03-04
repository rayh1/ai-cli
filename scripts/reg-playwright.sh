#!/usr/bin/env bash
set -euo pipefail

PLAYWRIGHT_CONFIG_B64="eyJicm93c2VyIjp7ImJyb3dzZXJOYW1lIjoiY2hyb21pdW0iLCJsYXVuY2hPcHRpb25zIjp7ImhlYWRsZXNzIjp0cnVlfX19"

mkdir -p /home/aiuser/.cache/ms-playwright
chown -R aiuser:aiuser /home/aiuser/.cache/ms-playwright /home/aiuser/.claude /workspace/.claude 2>/dev/null || true

export PLAYWRIGHT_CONFIG_B64
su -s /bin/bash aiuser -c '
set -euo pipefail
cd /home/aiuser

playwright-cli install --skills > /tmp/playwright-skills.log 2>&1 &
skill_pid=$!

for i in $(seq 1 30); do
  if [ -f /home/aiuser/.claude/skills/playwright-cli/SKILL.md ] || [ -f /workspace/.claude/skills/playwright-cli/SKILL.md ]; then
    break
  fi

  if ! kill -0 "$skill_pid" 2>/dev/null; then
    break
  fi

  sleep 1
done

if kill -0 "$skill_pid" 2>/dev/null; then
  kill "$skill_pid" 2>/dev/null || true
  wait "$skill_pid" 2>/dev/null || true
fi

if [ ! -f /home/aiuser/.claude/skills/playwright-cli/SKILL.md ] && [ ! -f /workspace/.claude/skills/playwright-cli/SKILL.md ]; then
  cat /tmp/playwright-skills.log >&2
  exit 1
fi

DEBUG=pw:install npx --yes -p @playwright/cli@${PLAYWRIGHT_CLI_VERSION} playwright install chromium
base64 -d <<< "$PLAYWRIGHT_CONFIG_B64" > /home/aiuser/playwright-cli.json
jq -e .browser /home/aiuser/playwright-cli.json >/dev/null
'