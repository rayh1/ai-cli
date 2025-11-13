@echo off
REM Wrapper for Claude CLI - calls ai-cli.cmd with 'claude' as the entrypoint
call "%~dp0ai-cli.cmd" claude %*
