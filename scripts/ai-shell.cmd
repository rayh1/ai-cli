@echo off
setlocal EnableExtensions

if /I "%~1"=="--help" goto show_help
if /I "%~1"=="-h" goto show_help
if /I "%~1"=="/?" goto show_help

REM Wrapper for interactive shell in ai-cli container
call "%~dp0ai-cli.cmd" bash %*
exit /b %ERRORLEVEL%

:show_help
echo Usage: ai-shell [--root^|-r] [bash args...]
echo.
echo Examples:
echo   ai-shell
echo   ai-shell --root
echo   ai-shell -lc "whoami"
echo   ai-shell --root -lc "whoami ^&^& id"
echo.
echo Notes:
echo   --root/-r is handled by ai-cli and runs container as root.
echo   Use -- to pass a literal --root to bash: ai-shell -- --root
exit /b 0