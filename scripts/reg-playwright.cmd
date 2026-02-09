@echo off
REM -------------------------------
REM Install Playwright CLI skills and browser for all CLIs
REM (Claude, Codex, GitHub Copilot)
REM -------------------------------
set "REPO_ROOT=%~dp0.."
docker compose -f "%REPO_ROOT%\docker-compose.yml" --project-directory "%REPO_ROOT%" run --rm --entrypoint bash ai-cli -lc "set -e; cd /home/aiuser; playwright-cli install --skills; npx --yes -p @playwright/cli@${PLAYWRIGHT_CLI_VERSION} playwright install chromium; printf \"%%s\\n\" \"{\\\"browser\\\":{\\\"browserName\\\":\\\"chromium\\\",\\\"launchOptions\\\":{\\\"headless\\\":false}}}\" > /home/aiuser/playwright-cli.json"
exit /b %errorlevel%
