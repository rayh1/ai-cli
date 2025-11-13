@echo off
setlocal EnableExtensions

REM -------------------------------
REM Register Playwright MCP for all CLIs
REM (Claude, Codex, Github Copilot)
REM -------------------------------

set "REPO_ROOT=%~dp0.."
set "COMPOSE_FILE=%REPO_ROOT%\docker-compose.yml"
set "HOST_PWD=%CD%"
set "BASH_SCRIPT=%~dp0reg-playwright.sh"

echo ========================================
echo Registering Playwright MCP for all CLIs
echo ========================================
echo.

REM --- 1. Claude ---
echo [1/3] Registering for Claude...
set "CLAUDE_CMD=%~dp0claude.cmd"
if exist "%CLAUDE_CMD%" (
  set "CLAUDE_EXE=%CLAUDE_CMD%"
) else (
  set "CLAUDE_EXE=claude"
)

call "%CLAUDE_EXE%" mcp remove playwright >NUL 2>&1
call "%CLAUDE_EXE%" mcp add playwright -- python3 /opt/mcp/playwright-mcp.py
if errorlevel 1 (
  echo [ERROR] Claude: Playwright MCP registration failed. >&2
) else (
  echo [OK] Claude: Playwright MCP registered
)
echo.

REM --- 2. Codex ---
echo [2/3] Registering for Codex...
set "CODEX_CMD=%~dp0codex.cmd"
if exist "%CODEX_CMD%" (
  set "CODEX_EXE=%CODEX_CMD%"
) else (
  set "CODEX_EXE=codex"
)

call "%CODEX_EXE%" mcp remove playwright >NUL 2>&1
call "%CODEX_EXE%" mcp add playwright -- python3 /opt/mcp/playwright-mcp.py
if errorlevel 1 (
  echo [ERROR] Codex: Playwright MCP registration failed. >&2
) else (
  echo [OK] Codex: Playwright MCP registered
)
echo.

REM --- 3. Github Copilot ---
echo [3/3] Registering for Github Copilot...
if not exist "%BASH_SCRIPT%" (
  echo [ERROR] Script not found: %BASH_SCRIPT% >&2
  exit /b 1
)

docker compose --project-directory "%REPO_ROOT%" -f "%COMPOSE_FILE%" run --rm ^
  -v "%BASH_SCRIPT%:/tmp/setup-mcp.sh" ^
  --entrypoint bash ^
  ai-cli /tmp/setup-mcp.sh

if errorlevel 1 (
  echo [ERROR] Github Copilot: Playwright MCP configuration failed. >&2
) else (
  echo [OK] Github Copilot: Playwright MCP configured
)
echo.

echo ========================================
echo Registration complete for all CLIs
echo ========================================

set HOST_PWD=
endlocal
