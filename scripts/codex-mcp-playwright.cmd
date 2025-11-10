@echo off
setlocal EnableExtensions

REM -------------------------------
REM Minimal Playwright MCP setup
REM -------------------------------

REM Gebruik lokale codex.cmd als die naast dit script staat; anders 'codex' via PATH
set "CODEX_CMD=%~dp0codex.cmd"
if exist "%CODEX_CMD%" (
  set "CODEX_EXE=%CODEX_CMD%"
) else (
  set "CODEX_EXE=codex"
)

REM Oude registratie negeren als die ontbreekt
call "%CODEX_EXE%" mcp remove playwright >NUL 2>&1

REM >>> Belangrijk: de dubbele streepjes `--` scheiden Codex-args van MCP-args
call "%CODEX_EXE%" mcp add playwright -- python3 /opt/mcp/playwright-mcp.py
if errorlevel 1 (
  echo [ERROR] Registratie van Playwright MCP is mislukt. >&2
  exit /b 1
)

echo [OK] Playwright MCP geregistreerd
echo.
call "%CODEX_EXE%" mcp list

endlocal
