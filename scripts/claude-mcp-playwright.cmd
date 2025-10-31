@echo off
setlocal EnableExtensions

REM -------------------------------
REM Minimal Playwright MCP setup
REM Registreert exact:
REM   --browser chromium --headless --isolated --no-sandbox
REM -------------------------------

REM Gebruik lokale claude.cmd als die naast dit script staat; anders 'claude' via PATH
set "CLAUDE_CMD=%~dp0claude.cmd"
if exist "%CLAUDE_CMD%" (
  set "CLAUDE_EXE=%CLAUDE_CMD%"
) else (
  set "CLAUDE_EXE=claude"
)

REM Oude registratie negeren als die ontbreekt
call "%CLAUDE_EXE%" mcp remove playwright >NUL 2>&1

REM >>> Belangrijk: de dubbele streepjes `--` scheiden Claude-args van MCP-args
call "%CLAUDE_EXE%" mcp add playwright -- npx @playwright/mcp@latest ^
  --browser chromium --headless --isolated --no-sandbox
if errorlevel 1 (
  echo [ERROR] Registratie van Playwright MCP is mislukt. >&2
  exit /b 1
)

echo [OK] Playwright MCP geregistreerd met:
echo       --browser chromium --headless --isolated --no-sandbox
echo.
call "%CLAUDE_EXE%" mcp list

endlocal
