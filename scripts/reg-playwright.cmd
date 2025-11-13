@echo off
REM -------------------------------
REM Register Playwright MCP for all CLIs
REM (Claude, Codex, Github Copilot)
REM
REM This is a simple wrapper that calls reg-mcp.py
REM with the Playwright-specific settings.
REM -------------------------------

python "%~dp0reg-mcp.py" --name playwright --command python3 /opt/mcp/playwright-mcp.py
exit /b %errorlevel%
