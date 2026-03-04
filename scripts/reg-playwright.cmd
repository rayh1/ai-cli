@echo off
REM -------------------------------
REM Install Playwright CLI skills and browser for all CLIs
REM (Claude, Codex, GitHub Copilot)
REM -------------------------------
set "REPO_ROOT=%~dp0.."
set "HOST_PWD=%REPO_ROOT%"
docker compose ^
	-f "%REPO_ROOT%\docker-compose.yml" ^
	--project-directory "%REPO_ROOT%" ^
	run --rm --user root --entrypoint bash ai-cli ^
	-lc "/workspace/scripts/reg-playwright.sh"
exit /b %errorlevel%
