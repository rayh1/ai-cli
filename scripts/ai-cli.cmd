@echo off
setlocal EnableExtensions

REM Generic AI CLI runner - dynamically sets the entrypoint
REM Usage: ai-cli <cli-name> [args...]
REM Example: ai-cli claude -p "explain this code"
REM          ai-cli claude -- --model sonnet

if "%~1"=="" (
  echo [ERROR] Usage: ai-cli ^<cli-name^> [args...] >&2
  echo        Example: ai-cli claude -p "explain this code" >&2
  echo        Use -- to pass the rest through unchanged. >&2
  exit /b 1
)

REM Repo root = parent of this scripts\ folder
set "REPO_ROOT=%~dp0.."
set "COMPOSE_FILE=%REPO_ROOT%\docker-compose.yml"

REM Set HOST_PWD to the *caller's* current directory
set "HOST_PWD=%CD%"

REM Allow an optional leading -- for symmetry with the old interface
if "%~1"=="--" (
  shift
)

REM Next arg is the CLI name (entrypoint)
if "%~1"=="" goto missing_cli_name
set "CLI_NAME=%~1"
shift

REM Build the argument list for the selected CLI
set "ARGS="
set "PARSE_ARGUMENT_SEPARATOR=1"
:parse_args
if "%~1"=="" goto run_docker

if "%PARSE_ARGUMENT_SEPARATOR%"=="1" (
  if "%~1"=="--" (
    set "PARSE_ARGUMENT_SEPARATOR=0"
    shift
    goto parse_args
  )
)

set "ARGS=%ARGS% %1"
shift
goto parse_args

:run_docker
docker compose --project-directory "%REPO_ROOT%" -f "%COMPOSE_FILE%" run --rm --entrypoint %CLI_NAME% ai-cli%ARGS%
goto cleanup

:missing_cli_name
echo [ERROR] Missing CLI name. >&2
echo        Usage: ai-cli ^<cli-name^> [args...] >&2
exit /b 1

REM Clean up
:cleanup
set HOST_PWD=
set CLI_NAME=
set ARGS=
set PARSE_ARGUMENT_SEPARATOR=
endlocal
