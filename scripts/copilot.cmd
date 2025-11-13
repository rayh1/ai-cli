@echo off
REM Wrapper for Copilot CLI - calls ai-cli.cmd with 'copilot' as the entrypoint
call "%~dp0ai-cli.cmd" copilot %*
