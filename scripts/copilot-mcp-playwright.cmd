@echo off
setlocal EnableExtensions

REM -------------------------------
REM Playwright MCP setup for Github Copilot CLI
REM Configures: --browser chromium --headless --isolated --no-sandbox
REM -------------------------------

REM Repo root = parent of this scripts\ folder
set "REPO_ROOT=%~dp0.."
set "COMPOSE_FILE=%REPO_ROOT%\docker-compose.yml"
set "HOST_PWD=%CD%"
set "BASH_SCRIPT=%~dp0copilot-mcp-playwright.sh"

REM Check if bash script exists
if not exist "%BASH_SCRIPT%" (
  echo [ERROR] Script not found: %BASH_SCRIPT% >&2
  exit /b 1
)

REM Run the bash script in the copilot container
docker compose --project-directory "%REPO_ROOT%" -f "%COMPOSE_FILE%" run --rm ^
  -v "%BASH_SCRIPT%:/tmp/setup-mcp.sh" ^
  --entrypoint bash ^
  copilot /tmp/setup-mcp.sh

if errorlevel 1 (
  echo [ERROR] Failed to configure Playwright MCP. >&2
  exit /b 1
)

set HOST_PWD=
endlocal
