@echo off
setlocal EnableExtensions

REM Generic AI CLI runner - dynamically sets the entrypoint
REM Usage: ai-cli [--root|-r] <cli-name> [args...]
REM Example: ai-cli --root claude -p "explain this code"
REM          ai-cli claude --root -p "explain this code"
REM          ai-cli claude -- --root

if "%~1"=="" (
  echo [ERROR] Usage: ai-cli [--root^-r] ^<cli-name^> [args...] >&2
  echo        Example: ai-cli --root claude -p "explain this code" >&2
  echo        Use -- to stop ai-cli option parsing and pass the rest through. >&2
  exit /b 1
)

REM Repo root = parent of this scripts\ folder
set "REPO_ROOT=%~dp0.."
set "COMPOSE_FILE=%REPO_ROOT%\docker-compose.yml"

REM Set HOST_PWD to the *caller's* current directory
set "HOST_PWD=%CD%"

set "RUN_AS_ROOT=0"
set "PARSE_AI_CLI_OPTIONS=1"

REM Parse ai-cli options that appear before the CLI name
:parse_leading_options
if "%~1"=="" goto missing_cli_name
if /I "%~1"=="--root" (
  set "RUN_AS_ROOT=1"
  shift
  goto parse_leading_options
)
if /I "%~1"=="-r" (
  set "RUN_AS_ROOT=1"
  shift
  goto parse_leading_options
)
if "%~1"=="--" (
  shift
)

REM Next arg is the CLI name (entrypoint)
if "%~1"=="" goto missing_cli_name
set "CLI_NAME=%~1"
shift

REM Build the argument list for the selected CLI
set "ARGS="
:parse_args
if "%~1"=="" goto run_docker

if "%PARSE_AI_CLI_OPTIONS%"=="1" (
  if "%~1"=="--" (
    set "PARSE_AI_CLI_OPTIONS=0"
    shift
    goto parse_args
  )
  if /I "%~1"=="--root" (
    set "RUN_AS_ROOT=1"
    shift
    goto parse_args
  )
  if /I "%~1"=="-r" (
    set "RUN_AS_ROOT=1"
    shift
    goto parse_args
  )
)

set "ARGS=%ARGS% %1"
shift
goto parse_args

:run_docker
set "DOCKER_USER_FLAG="
if "%RUN_AS_ROOT%"=="1" set "DOCKER_USER_FLAG=--user root"

docker compose --project-directory "%REPO_ROOT%" -f "%COMPOSE_FILE%" run --rm %DOCKER_USER_FLAG% --entrypoint %CLI_NAME% ai-cli%ARGS%
goto cleanup

:missing_cli_name
echo [ERROR] Missing CLI name. >&2
echo        Usage: ai-cli [--root^-r] ^<cli-name^> [args...] >&2
exit /b 1

REM Clean up
:cleanup
set HOST_PWD=
set CLI_NAME=
set ARGS=
set RUN_AS_ROOT=
set PARSE_AI_CLI_OPTIONS=
set DOCKER_USER_FLAG=
endlocal
