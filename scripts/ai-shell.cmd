@echo off
setlocal EnableExtensions

if /I "%~1"=="--help" goto show_help
if /I "%~1"=="-h" goto show_help
if /I "%~1"=="/?" goto show_help

set "SCRIPT_DIR=%~dp0"
if not exist "%SCRIPT_DIR%ai-shell.cmd" set "SCRIPT_DIR=%~dp$PATH:0"
if not exist "%SCRIPT_DIR%ai-shell.cmd" (
  for /f "delims=" %%I in ('where.exe "%~n0.cmd" 2^>nul') do (
    set "SCRIPT_DIR=%%~dpI"
    goto script_dir_found
  )
)

:script_dir_found
if not exist "%SCRIPT_DIR%ai-shell.cmd" (
  echo [ERROR] Could not locate ai-shell.cmd. >&2
  exit /b 1
)

set "REPO_ROOT=%SCRIPT_DIR%.."
set "COMPOSE_FILE=%REPO_ROOT%\docker-compose.yml"
set "HOST_PWD=%CD%"

set "ROOT_OPTS="
set "PARSE_AI_SHELL_OPTIONS=1"
set "CONTAINER_NAME="
set "BASH_ARGS="

REM Parse leading ai-shell options, then optional container name
:parse_leading
if "%~1"=="" goto run_shell

if "%PARSE_AI_SHELL_OPTIONS%"=="1" (
  if "%~1"=="--" (
    set "PARSE_AI_SHELL_OPTIONS=0"
    shift
    goto parse_leading
  )
  if /I "%~1"=="--root" (
    set "ROOT_OPTS=%ROOT_OPTS% --user root"
    shift
    goto parse_leading
  )
  if /I "%~1"=="-r" (
    set "ROOT_OPTS=%ROOT_OPTS% --user root"
    shift
    goto parse_leading
  )
  if /I "%~1"=="--name" (
    if "%~2"=="" goto missing_name
    set "CONTAINER_NAME=%~2"
    shift
    shift
    goto parse_leading
  )

  REM First non-option token is treated as container name
  echo(%~1| findstr /B /C:"-" >nul
  if errorlevel 1 if not defined CONTAINER_NAME (
    set "CONTAINER_NAME=%~1"
    shift
    set "PARSE_AI_SHELL_OPTIONS=0"
    goto parse_leading
  )
)

goto collect_bash_args

:collect_bash_args
if "%~1"=="" goto run_shell
set "BASH_ARGS=%BASH_ARGS% %1"
shift
goto collect_bash_args

:run_shell
if defined CONTAINER_NAME goto run_named_shell

REM Default mode: ephemeral shell, same behavior as before
docker compose --project-directory "%REPO_ROOT%" -f "%COMPOSE_FILE%" run --rm %ROOT_OPTS% --entrypoint bash ai-cli%BASH_ARGS%
goto cleanup

:run_named_shell
set "EXISTING_ID="
for /f "delims=" %%I in ('docker ps -aq -f "name=^/%CONTAINER_NAME%$"') do (
	set "EXISTING_ID=%%I"
	goto have_container_lookup
)

:have_container_lookup
if not defined EXISTING_ID (
	REM Create a persistent container with a keepalive process.
    docker compose --project-directory "%REPO_ROOT%" -f "%COMPOSE_FILE%" run -d --name "%CONTAINER_NAME%" %ROOT_OPTS% --entrypoint bash ai-cli -lc "trap : TERM INT; while :; do sleep 3600; done"
	if errorlevel 1 goto cleanup
) else (
	set "IS_RUNNING="
	for /f "delims=" %%R in ('docker inspect -f "{{.State.Running}}" "%CONTAINER_NAME%" 2^>nul') do set "IS_RUNNING=%%R"
	if /I not "%IS_RUNNING%"=="true" docker start "%CONTAINER_NAME%" >nul
)

docker exec -it %ROOT_OPTS% -e TERM=xterm-256color -e LANG=C.UTF-8 -e LC_ALL=C.UTF-8 -e PATH=/opt/venv/bin:/home/aiuser/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games "%CONTAINER_NAME%" bash%BASH_ARGS%
goto cleanup

:missing_name
echo [ERROR] Missing value for --name. >&2
echo        Usage: ai-shell [--root^-r] [--name ^<container-name^>] [container-name] [bash args...] >&2
exit /b 1

:cleanup
set SCRIPT_DIR=
set REPO_ROOT=
set COMPOSE_FILE=
set HOST_PWD=
set ROOT_OPTS=
set PARSE_AI_SHELL_OPTIONS=
set CONTAINER_NAME=
set BASH_ARGS=
set EXISTING_ID=
set IS_RUNNING=
exit /b %ERRORLEVEL%

:show_help
echo Usage: ai-shell [--root^|-r] [--name ^<container-name^>] [container-name] [bash args...]
echo.
echo Examples:
echo   ai-shell
echo   ai-shell aap
echo   ai-shell --root
echo   ai-shell --name aap
echo   ai-shell aap -lc "tmux attach ^|^| tmux new -s main"
echo   ai-shell -lc "whoami"
echo   ai-shell --root -lc "whoami ^&^& id"
echo.
echo Notes:
echo   Without a name, runs an ephemeral shell and removes the container on exit.
echo   [container-name] is shorthand for --name ^<container-name^>.
echo   With a name, creates/reuses that container and execs bash into it.
echo   This lets tmux sessions survive shell exit and be reattached later.
echo   --root/-r runs the container as root.
echo   Use -- to stop ai-shell option parsing and pass the rest to bash.
echo   Example: ai-shell -- --root
exit /b 0