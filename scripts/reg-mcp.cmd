@echo off
REM Wrapper to call Python version of reg-mcp
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
set "PYTHON_SCRIPT=%SCRIPT_DIR%reg-mcp.py"

REM Check if Python script exists
if not exist "%PYTHON_SCRIPT%" (
    echo [ERROR] Python script not found: %PYTHON_SCRIPT% >&2
    exit /b 1
)

REM Call Python script with all arguments
python "%PYTHON_SCRIPT%" %*

endlocal
exit /b %ERRORLEVEL%
