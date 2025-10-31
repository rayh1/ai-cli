@echo off
setlocal EnableExtensions

REM Repo root = parent of this scripts\ folder
set "REPO_ROOT=%~dp0.."
set "COMPOSE_FILE=%REPO_ROOT%\docker-compose.yml"

REM Mount the caller’s current directory into /workspace
set "HOST_PWD=%CD%"

REM IMPORTANT: do NOT forward args, or Compose will override the service command.
docker compose --project-directory "%REPO_ROOT%" -f "%COMPOSE_FILE%" run --rm --service-ports codex-login

set HOST_PWD=
endlocal
