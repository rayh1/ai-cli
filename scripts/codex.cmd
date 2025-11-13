@echo off
REM Wrapper for Codex CLI - calls ai-cli.cmd with 'codex' as the entrypoint
call "%~dp0ai-cli.cmd" codex %*
