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
set "PORT_OPTS="
set "PARSE_AI_SHELL_OPTIONS=1"
set "CONTAINER_NAME="
set "CRON_ENABLED="
set "SSH_PASSWORD="
set "BASH_ARGS="

goto parse_leading

:parse_port_option
set "PORT_SPEC=%~1"
set "CONTAINER_PORT="
set "HOST_PORT="
set "EXTRA_PORT_PART="
for /f "tokens=1,2,* delims=:;" %%A in ("%~1") do (
  set "CONTAINER_PORT=%%~A"
  set "HOST_PORT=%%~B"
  set "EXTRA_PORT_PART=%%~C"
)
if not defined CONTAINER_PORT goto invalid_port
if not defined HOST_PORT goto invalid_port
if defined EXTRA_PORT_PART goto invalid_port
echo(%CONTAINER_PORT%| findstr /R "^[0-9][0-9]*$" >nul
if errorlevel 1 goto invalid_port
echo(%HOST_PORT%| findstr /R "^[0-9][0-9]*$" >nul
if errorlevel 1 goto invalid_port
set "PORT_OPTS=%PORT_OPTS% --publish %HOST_PORT%:%CONTAINER_PORT%"
set "PORT_SPEC="
set "CONTAINER_PORT="
set "HOST_PORT="
set "EXTRA_PORT_PART="
exit /b 0

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
  if /I "%~1"=="--port" (
    if "%~2"=="" goto missing_port
    call :parse_port_option "%~2"
    if errorlevel 1 goto cleanup
    shift
    shift
    goto parse_leading
  )
  if /I "%~1"=="--cron" (
    set "CRON_ENABLED=1"
    shift
    goto parse_leading
  )
  if /I "%~1"=="--ssh" (
    if "%~2"=="" goto missing_ssh
    set "SSH_PASSWORD=%~2"
    shift
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
call :append_bash_arg "%~1"
shift
goto collect_bash_args

:append_bash_arg
setlocal EnableDelayedExpansion
set "CURRENT_ARG=%~1"

set "CURRENT_ARG=!CURRENT_ARG:^=^^!"
set "CURRENT_ARG=!CURRENT_ARG:|=^|!"
set "CURRENT_ARG=!CURRENT_ARG:&=^&!"
set "CURRENT_ARG=!CURRENT_ARG:<=^<!"
set "CURRENT_ARG=!CURRENT_ARG:>=^>!"
set "CURRENT_ARG=!CURRENT_ARG:(=^(!"
set "CURRENT_ARG=!CURRENT_ARG:)=^)!"
set CURRENT_ARG="!CURRENT_ARG!"

endlocal & set "BASH_ARGS=%BASH_ARGS% %CURRENT_ARG%"
exit /b 0

:run_shell
if defined CONTAINER_NAME goto run_named_shell
if defined CRON_ENABLED goto run_ephemeral_shell_with_services
if defined SSH_PASSWORD goto run_ephemeral_shell_with_services

REM Default mode: ephemeral shell, same behavior as before
docker compose --project-directory "%REPO_ROOT%" -f "%COMPOSE_FILE%" run --rm %ROOT_OPTS% %PORT_OPTS% --entrypoint bash ai-cli%BASH_ARGS%
goto cleanup

:run_ephemeral_shell_with_services
set "TARGET_USER=aiuser"
if defined ROOT_OPTS set "TARGET_USER=root"
if defined CRON_ENABLED (
  if defined SSH_PASSWORD (
    docker compose --project-directory "%REPO_ROOT%" -f "%COMPOSE_FILE%" run --rm --user root %PORT_OPTS% -e "AI_SHELL_ENABLE_CRON=1" -e "AI_SHELL_SSH_PASSWORD=%SSH_PASSWORD%" -e "AI_SHELL_TARGET_USER=%TARGET_USER%" --entrypoint /usr/local/bin/ai-shell-entrypoint ai-cli%BASH_ARGS%
  ) else (
    docker compose --project-directory "%REPO_ROOT%" -f "%COMPOSE_FILE%" run --rm --user root %PORT_OPTS% -e "AI_SHELL_ENABLE_CRON=1" -e "AI_SHELL_TARGET_USER=%TARGET_USER%" --entrypoint /usr/local/bin/ai-shell-entrypoint ai-cli%BASH_ARGS%
  )
) else (
  docker compose --project-directory "%REPO_ROOT%" -f "%COMPOSE_FILE%" run --rm --user root %PORT_OPTS% -e "AI_SHELL_SSH_PASSWORD=%SSH_PASSWORD%" -e "AI_SHELL_TARGET_USER=%TARGET_USER%" --entrypoint /usr/local/bin/ai-shell-entrypoint ai-cli%BASH_ARGS%
)
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
  if defined CRON_ENABLED goto create_named_shell_with_services
  if defined SSH_PASSWORD goto create_named_shell_with_services
        docker compose --project-directory "%REPO_ROOT%" -f "%COMPOSE_FILE%" run -d --name "%CONTAINER_NAME%" %ROOT_OPTS% %PORT_OPTS% --entrypoint bash ai-cli -lc "trap : TERM INT; while :; do sleep 3600; done"
	if errorlevel 1 goto cleanup
) else (
  if defined PORT_OPTS goto existing_container_ports_unsupported
	set "IS_RUNNING="
	for /f "delims=" %%R in ('docker inspect -f "{{.State.Running}}" "%CONTAINER_NAME%" 2^>nul') do set "IS_RUNNING=%%R"
	if /I not "%IS_RUNNING%"=="true" docker start "%CONTAINER_NAME%" >nul
  if defined CRON_ENABLED call :enable_existing_container_cron
  if errorlevel 1 goto cleanup
  if defined SSH_PASSWORD call :enable_existing_container_ssh
  if errorlevel 1 goto cleanup
)

docker exec -it %ROOT_OPTS% -e TERM=xterm-256color -e LANG=C.UTF-8 -e LC_ALL=C.UTF-8 -e PATH=/opt/venv/bin:/home/aiuser/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games "%CONTAINER_NAME%" bash%BASH_ARGS%
goto cleanup

:create_named_shell_with_services
    set "TARGET_USER=aiuser"
    if defined ROOT_OPTS set "TARGET_USER=root"
    if defined CRON_ENABLED (
      if defined SSH_PASSWORD (
        docker compose --project-directory "%REPO_ROOT%" -f "%COMPOSE_FILE%" run -d --name "%CONTAINER_NAME%" --user root %PORT_OPTS% -e "AI_SHELL_ENABLE_CRON=1" -e "AI_SHELL_SSH_PASSWORD=%SSH_PASSWORD%" -e "AI_SHELL_TARGET_USER=%TARGET_USER%" --entrypoint /usr/local/bin/ai-shell-entrypoint ai-cli -lc "trap : TERM INT; while :; do sleep 3600; done"
      ) else (
        docker compose --project-directory "%REPO_ROOT%" -f "%COMPOSE_FILE%" run -d --name "%CONTAINER_NAME%" --user root %PORT_OPTS% -e "AI_SHELL_ENABLE_CRON=1" -e "AI_SHELL_TARGET_USER=%TARGET_USER%" --entrypoint /usr/local/bin/ai-shell-entrypoint ai-cli -lc "trap : TERM INT; while :; do sleep 3600; done"
      )
    ) else (
      docker compose --project-directory "%REPO_ROOT%" -f "%COMPOSE_FILE%" run -d --name "%CONTAINER_NAME%" --user root %PORT_OPTS% -e "AI_SHELL_SSH_PASSWORD=%SSH_PASSWORD%" -e "AI_SHELL_TARGET_USER=%TARGET_USER%" --entrypoint /usr/local/bin/ai-shell-entrypoint ai-cli -lc "trap : TERM INT; while :; do sleep 3600; done"
    )
	if errorlevel 1 goto cleanup
goto after_container_lookup

:after_container_lookup
docker exec -it %ROOT_OPTS% -e TERM=xterm-256color -e LANG=C.UTF-8 -e LC_ALL=C.UTF-8 -e PATH=/opt/venv/bin:/home/aiuser/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games "%CONTAINER_NAME%" bash%BASH_ARGS%
goto cleanup

:enable_existing_container_ssh
docker exec -u root -e "AI_SHELL_SSH_PASSWORD=%SSH_PASSWORD%" "%CONTAINER_NAME%" /usr/local/bin/ai-shell-enable-ssh
exit /b %ERRORLEVEL%

:enable_existing_container_cron
docker exec -u root "%CONTAINER_NAME%" /usr/local/bin/ai-shell-enable-cron
exit /b %ERRORLEVEL%

:invalid_port
echo [ERROR] Invalid --port value "%PORT_SPEC%". Expected containerPort;hostPort or containerPort:hostPort, for example 8080;3000 or 8080:3000. >&2
set "PORT_SPEC="
set "CONTAINER_PORT="
set "HOST_PORT="
set "EXTRA_PORT_PART="
exit /b 1

:existing_container_ports_unsupported
echo [ERROR] Container "%CONTAINER_NAME%" already exists; --port only applies when creating a container. >&2
echo         Remove and recreate it if you need different published ports. >&2
exit /b 1

:missing_name
echo [ERROR] Missing value for --name. >&2
echo        Usage: ai-shell [--root^-r] [--port ^<container-port;host-port^|container-port:host-port^> ...] [--cron] [--ssh ^<password^>] [--name ^<container-name^>] [container-name] [bash args...] >&2
exit /b 1

:missing_port
echo [ERROR] Missing value for --port. >&2
echo        Usage: ai-shell [--root^-r] [--port ^<container-port;host-port^|container-port:host-port^> ...] [--cron] [--ssh ^<password^>] [--name ^<container-name^>] [container-name] [bash args...] >&2
exit /b 1

:missing_ssh
echo [ERROR] Missing value for --ssh. >&2
echo        Usage: ai-shell [--root^-r] [--port ^<container-port;host-port^|container-port:host-port^> ...] [--cron] [--ssh ^<password^>] [--name ^<container-name^>] [container-name] [bash args...] >&2
exit /b 1

:cleanup
set SCRIPT_DIR=
set REPO_ROOT=
set COMPOSE_FILE=
set HOST_PWD=
set ROOT_OPTS=
set PORT_OPTS=
set PARSE_AI_SHELL_OPTIONS=
set CONTAINER_NAME=
set CRON_ENABLED=
set SSH_PASSWORD=
set BASH_ARGS=
set EXISTING_ID=
set IS_RUNNING=
set TARGET_USER=
set PORT_SPEC=
set CONTAINER_PORT=
set HOST_PORT=
set EXTRA_PORT_PART=
exit /b %ERRORLEVEL%

:show_help
echo Usage: ai-shell [--root^|-r] [--port ^<container-port;host-port^|container-port:host-port^> ...] [--cron] [--ssh ^<password^>] [--name ^<container-name^>] [container-name] [bash args...]
echo.
echo Examples:
echo   ai-shell
echo   ai-shell aap
echo   ai-shell --port 8080;3000
echo   ai-shell --port 8080:3000
echo   ai-shell --port 8080;3000 --port 5173;5173
echo   ai-shell --cron
echo   ai-shell --cron aap
echo   ai-shell --ssh pass --port 22:2222
echo   ai-shell --cron --ssh pass --port 22:2222
echo   ai-shell --name aap --ssh pass --port 22:2222
echo   ai-shell --root
echo   ai-shell --name aap
echo   ai-shell aap -lc "tmux attach ^|^| tmux new -s main"
echo   ai-shell -lc "whoami"
echo   ai-shell --root -lc "whoami ^&^& id"
echo.
echo Notes:
echo   Without a name, runs an ephemeral shell and removes the container on exit.
echo   [container-name] is shorthand for --name ^<container-name^>.
echo   After ai-shell [container-name], remaining args go to bash.
echo   After ai-shell --name ^<container-name^>, ai-shell still parses later options such as --root.
echo   With a name, creates/reuses that container and execs bash into it.
echo   --port container;host or container:host publishes the container port to the host as host:container.
echo   Repeat --port to publish multiple ports.
echo   In PowerShell, prefer container:host, or quote container;host.
echo   --cron starts the cron daemon in the container.
echo   Cron uses the container's default crontabs under /var/spool.
echo   --ssh password starts sshd in the container and sets aiuser's password.
echo   Use --port 22:hostPort to connect from the host with ssh aiuser@localhost -p hostPort.
echo   For named containers, --port only applies when the container is first created.
echo   This lets tmux sessions survive shell exit and be reattached later.
echo   --root/-r runs the container as root.
echo   Use -- to stop ai-shell option parsing and pass the rest to bash.
echo   Example: ai-shell -- --root
exit /b 0