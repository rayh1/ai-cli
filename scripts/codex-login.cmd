@echo off
setlocal EnableExtensions

REM Repo root = parent of this scripts\ folder
set "REPO_ROOT=%~dp0.."
set "COMPOSE_FILE=%REPO_ROOT%\docker-compose.yml"

REM Mount the caller's current directory into /workspace
set "HOST_PWD=%CD%"

REM Use ai-cli service with bash entrypoint to run socat bridge + codex login
docker compose --project-directory "%REPO_ROOT%" -f "%COMPOSE_FILE%" run --rm ^
  --entrypoint bash ^
  --publish 127.0.0.1:1455:1456 ^
  ai-cli -lc "socat -T15 TCP-LISTEN:1456,bind=0.0.0.0,reuseaddr,fork TCP:127.0.0.1:1455 & exec codex login"

set HOST_PWD=
endlocal
