@echo off
setlocal EnableExtensions

REM Repo root = parent of this scripts\ folder
set "REPO_ROOT=%~dp0.."
set "COMPOSE_FILE=%REPO_ROOT%\docker-compose.yml"

REM Mount the caller's current directory into /workspace
set "HOST_PWD=%CD%"

docker compose --project-directory "%REPO_ROOT%" -f "%COMPOSE_FILE%" run --rm copilot %*

set HOST_PWD=
endlocal
