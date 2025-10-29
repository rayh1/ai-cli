@echo off
REM Resolve repo root: scripts\ is one level below the repo root
set "REPO_ROOT=%~dp0.."
set "COMPOSE_FILE=%REPO_ROOT%\docker-compose.yml"

docker compose --project-directory "%REPO_ROOT%" -f "%COMPOSE_FILE%" run --rm claude %*
