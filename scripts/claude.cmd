@echo off
REM Repo root = parent of this scripts\ folder
set "REPO_ROOT=%~dp0.."
set "COMPOSE_FILE=%REPO_ROOT%\docker-compose.yml"

REM Set HOST_PWD to the *caller’s* current directory
set "HOST_PWD=%CD%"

docker compose --project-directory "%REPO_ROOT%" -f "%COMPOSE_FILE%" run --rm claude %*

REM Clean up
set HOST_PWD=
