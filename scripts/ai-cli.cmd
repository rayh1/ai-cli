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
set "PREFERRED_CONTAINER="
set "PERSISTENT_CONTAINER_MATCH_COUNT=0"

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
if "%~1"=="" goto run_cli

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

:run_cli
if defined AI_CLI_PREFERRED_CONTAINER (
  call :is_container_running "%AI_CLI_PREFERRED_CONTAINER%"
  if not errorlevel 1 set "PREFERRED_CONTAINER=%AI_CLI_PREFERRED_CONTAINER%"
) else (
  call :find_single_running_persistent_container
)

if defined PREFERRED_CONTAINER goto exec_in_container

if defined AI_CLI_PREFERRED_CONTAINER (
  echo [INFO] Preferred container "%AI_CLI_PREFERRED_CONTAINER%" is not running; starting a new one-off container.
) else if not "%PERSISTENT_CONTAINER_MATCH_COUNT%"=="0" (
  echo [INFO] Multiple persistent ai-shell containers are running; starting a new one-off container. Set AI_CLI_PREFERRED_CONTAINER to choose one.
)

docker compose --project-directory "%REPO_ROOT%" -f "%COMPOSE_FILE%" run --rm --entrypoint %CLI_NAME% ai-cli%ARGS%
goto cleanup

:exec_in_container
echo [INFO] Reusing persistent ai-shell container "%PREFERRED_CONTAINER%".
call :resolve_container_exec_user "%PREFERRED_CONTAINER%"
set "EXEC_USER_OPTS="
if defined CONTAINER_EXEC_USER set "EXEC_USER_OPTS=-u %CONTAINER_EXEC_USER%"
docker exec -it %EXEC_USER_OPTS% -e TERM=xterm-256color -e LANG=C.UTF-8 -e LC_ALL=C.UTF-8 -e PATH=/opt/venv/bin:/home/aiuser/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games "%PREFERRED_CONTAINER%" %CLI_NAME%%ARGS%
goto cleanup

:find_single_running_persistent_container
setlocal EnableDelayedExpansion
set "MATCH_COUNT=0"
set "MATCH_NAME="
for /f "delims=" %%A in ('docker ps --no-trunc --filter "label=com.docker.compose.service=ai-cli" --filter "status=running" --format "{{.Names}}" 2^>nul') do (
  set "CONTAINER_ARGS="
  for /f "delims=" %%B in ('docker inspect -f "{{json .Args}}" "%%A" 2^>nul') do set "CONTAINER_ARGS=%%B"
  echo(!CONTAINER_ARGS!| findstr /C:"sleep 3600" >nul
  if not errorlevel 1 (
    set /a MATCH_COUNT+=1
    if "!MATCH_COUNT!"=="1" set "MATCH_NAME=%%A"
  )
)
set "MATCH_NAME_RESULT=!MATCH_NAME!"
set "MATCH_COUNT_RESULT=!MATCH_COUNT!"
endlocal & set "PREFERRED_CONTAINER=%MATCH_NAME_RESULT%" & set "PERSISTENT_CONTAINER_MATCH_COUNT=%MATCH_COUNT_RESULT%"
if "%PERSISTENT_CONTAINER_MATCH_COUNT%"=="1" exit /b 0
set "PREFERRED_CONTAINER="
exit /b 0

:is_container_running
set "IS_RUNNING="
for /f "delims=" %%R in ('docker inspect -f "{{.State.Running}}" "%~1" 2^>nul') do set "IS_RUNNING=%%R"
if /I "%IS_RUNNING%"=="true" exit /b 0
exit /b 1

:resolve_container_exec_user
set "CONTAINER_EXEC_USER="
for /f "tokens=1,* delims==" %%A in ('docker inspect -f "{{range .Config.Env}}{{println .}}{{end}}" "%~1" 2^>nul ^| findstr /B /C:"AI_SHELL_TARGET_USER="') do set "CONTAINER_EXEC_USER=%%B"
if defined CONTAINER_EXEC_USER exit /b 0
for /f "delims=" %%U in ('docker inspect -f "{{.Config.User}}" "%~1" 2^>nul') do set "CONTAINER_EXEC_USER=%%U"
if defined CONTAINER_EXEC_USER exit /b 0
set "CONTAINER_EXEC_USER=aiuser"
exit /b 0

:missing_cli_name
echo [ERROR] Missing CLI name. >&2
echo        Usage: ai-cli ^<cli-name^> [args...] >&2
exit /b 1

REM Clean up
:cleanup
set HOST_PWD=
set CLI_NAME=
set ARGS=
set PREFERRED_CONTAINER=
set PERSISTENT_CONTAINER_MATCH_COUNT=
set CONTAINER_EXEC_USER=
set EXEC_USER_OPTS=
set PARSE_ARGUMENT_SEPARATOR=
endlocal
