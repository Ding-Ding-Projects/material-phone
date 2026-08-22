@echo off
setlocal EnableExtensions
set "SCRIPT_DIR=%~dp0"
set "SILENT_ARG="
if /I "%~1"=="/s" set "SILENT_ARG=-Silent"
if /I "%~1"=="--silent" set "SILENT_ARG=-Silent"
if "%SILENT%"=="1" set "SILENT_ARG=-Silent"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%scripts\download-dependencies.ps1" %SILENT_ARG%
set "EXIT_CODE=%ERRORLEVEL%"
if not "%EXIT_CODE%"=="0" echo [dependencies] Failed with exit code %EXIT_CODE%.
exit /b %EXIT_CODE%
