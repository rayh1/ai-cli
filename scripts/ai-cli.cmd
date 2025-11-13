@echo off
setlocal EnableExtensions

REM Generic AI CLI runner - dynamically sets the entrypoint
REM Usage: ai-cli <cli-name> [args...]
REM Example: ai-cli claude -p "explain this code"

if "%~1"=="" (
  echo [ERROR] Usage: ai-cli ^<cli-name^> [args...] >&2
  echo        Example: ai-cli claude -p "explain this code" >&2
  exit /b 1
)

REM Repo root = parent of this scripts\ folder
set "REPO_ROOT=%~dp0.."
set "COMPOSE_FILE=%REPO_ROOT%\docker-compose.yml"

REM Set HOST_PWD to the *caller's* current directory
set "HOST_PWD=%CD%"

REM First arg is the CLI name (entrypoint), rest are passed through
set "CLI_NAME=%~1"
shift

REM Build the argument list for docker compose
set "ARGS="
:parse_args
if "%~1"=="" goto run_docker
set "ARGS=%ARGS% %1"
shift
goto parse_args

:run_docker
docker compose --project-directory "%REPO_ROOT%" -f "%COMPOSE_FILE%" run --rm --entrypoint %CLI_NAME% ai-cli%ARGS%

REM Clean up
set HOST_PWD=
set CLI_NAME=
set ARGS=
endlocal
