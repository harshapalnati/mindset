@echo off
setlocal EnableDelayedExpansion

REM Mindset AI - Windows Command Line Interface
REM Usage: mindset [command] [options]

set "MINDSET_VERSION=0.1.0"
set "PROJECT_DIR=%~dp0"

REM Colors (limited in Windows CMD)
set "BLUE=[94m"
set "GREEN=[92m"
set "RED=[91m"
set "YELLOW=[93m"
set "CYAN=[96m"
set "NC=[0m"

REM Functions
goto :main

:print_info
echo %BLUE%[mindset]%NC% %~1
goto :eof

:print_success
echo %GREEN%[mindset]%NC% %~1
goto :eof

:print_error
echo %RED%[mindset]%NC% %~1
goto :eof

:print_warning
echo %YELLOW%[mindset]%NC% %~1
goto :eof

:show_help
echo.
echo ╔═══════════════════════════════════════════════════════════════╗
echo ║                  Mindset AI CLI                               ║
echo ╚═══════════════════════════════════════════════════════════════╝
echo.
echo Usage: mindset ^<command^> [options]
echo.
echo Commands:
echo   setup              Run interactive setup wizard
echo   train              Fine-tune a model with your data
echo   start              Start the Mindset server
echo   console            Start interactive Elixir console
echo   status             Check server and model status
echo   models             List available fine-tuned models
echo   switch ^<model-id^>  Switch to a different model
echo   stop               Stop the running server
echo   test               Run test inference
echo   help               Show this help message
echo.
echo Examples:
echo   mindset setup                    First-time setup
echo   mindset train                    Interactive training wizard
echo   mindset train --data data.csv    Quick train with data
echo   mindset start                    Start server
echo   mindset status                   Check system status
echo.
goto :eof

:check_project
if not exist "%PROJECT_DIR%mix.exs" (
    call :print_error "Not in a Mindset project directory!"
    call :print_info "Please run this command from the Mindset project root."
    exit /b 1
)
goto :eof

:check_elixir
mix --version >nul 2>&1
if errorlevel 1 (
    call :print_error "Elixir/Mix not found!"
    call :print_info "Please install Elixir: https://elixir-lang.org/install.html"
    exit /b 1
)
goto :eof

:cmd_setup
call :print_info "Running Mindset setup wizard..."
cd /d "%PROJECT_DIR%"
mix mindset.setup
goto :eof

:cmd_train
call :print_info "Starting fine-tuning wizard..."
cd /d "%PROJECT_DIR%"
shift
mix mindset.train %*
goto :eof

:cmd_start
call :print_info "Starting Mindset server..."

REM Check if already running
tasklist /FI "WINDOWTITLE eq mix phx.server" 2>nul | find /I "erl.exe" >nul
if not errorlevel 1 (
    call :print_warning "Server is already running!"
    call :print_info "Visit: http://localhost:4000"
    goto :eof
)

cd /d "%PROJECT_DIR%"

REM Check for .env file
if not exist ".env" (
    call :print_warning "No .env file found. Running setup first..."
    call :cmd_setup
)

call :print_success "Starting Phoenix server..."
call :print_info "The server will be available at: http://localhost:4000"
call :print_info "Press Ctrl+C to stop"
echo.

start "Mindset Server" mix phx.server
goto :eof

:cmd_console
call :print_info "Starting Elixir interactive console..."
cd /d "%PROJECT_DIR%"
iex -S mix
goto :eof

:cmd_status
call :print_info "Checking Mindset status..."

REM Check Elixir
elixir --version 2>nul | findstr "Elixir" >nul
if not errorlevel 1 (
    for /f "tokens=2" %%a in ('elixir --version ^| findstr "Elixir"') do (
        call :print_success "Elixir: %%a"
    )
) else (
    call :print_error "Elixir not found"
)

REM Check if server is running
tasklist /FI "WINDOWTITLE eq mix phx.server" 2>nul | find /I "erl.exe" >nul
if not errorlevel 1 (
    call :print_success "Server: Running"
    call :print_info "  URL: http://localhost:4000"
) else (
    call :print_warning "Server: Not running"
)

REM Check for models
if exist "priv\models\registry.json" (
    call :print_success "Fine-tuned models: Available"
) else (
    call :print_warning "No fine-tuned models found"
)

goto :eof

:cmd_models
call :print_info "Listing fine-tuned models..."
cd /d "%PROJECT_DIR%"
mix mindset.train --list
goto :eof

:cmd_switch
if "%~1"=="" (
    call :print_error "Please provide a model ID"
    call :print_info "Usage: mindset switch ^<model-id^>"
    call :print_info "Run 'mindset models' to see available models"
    exit /b 1
)

call :print_info "Switching to model: %~1"
cd /d "%PROJECT_DIR%"
mix mindset.train --switch %1

call :print_success "Model switched. Restart the server to use it:"
call :print_info "  mindset stop ^&^& mindset start"
goto :eof

:cmd_stop
call :print_info "Stopping Mindset server..."
taskkill /F /FI "WINDOWTITLE eq mix phx.server" >nul 2>&1
if not errorlevel 1 (
    call :print_success "Server stopped"
) else (
    call :print_warning "Server was not running"
)
goto :eof

:cmd_test
call :print_info "Running test inference..."
cd /d "%PROJECT_DIR%"
mix run -e "Application.ensure_all_started(:mindset); Process.sleep(3000); IO.puts('Testing AI...'); result = Mindset.Ai.Daemon.predict('Hello, how are you?'); IO.inspect(result);"
goto :eof

:main

call :check_project
if errorlevel 1 exit /b 1

call :check_elixir
if errorlevel 1 exit /b 1

if "%~1"=="" goto :show_help

if "%~1"=="setup" goto :cmd_setup
if "%~1"=="train" goto :cmd_train
if "%~1"=="start" goto :cmd_start
if "%~1"=="console" goto :cmd_console
if "%~1"=="iex" goto :cmd_console
if "%~1"=="status" goto :cmd_status
if "%~1"=="models" goto :cmd_models
if "%~1"=="list" goto :cmd_models
if "%~1"=="switch" goto :cmd_switch
if "%~1"=="stop" goto :cmd_stop
if "%~1"=="test" goto :cmd_test
if "%~1"=="help" goto :show_help
if "%~1"=="--help" goto :show_help
if "%~1"=="-h" goto :show_help

call :print_error "Unknown command: %~1"
call :print_info "Run 'mindset help' for usage"
exit /b 1

:end
endlocal