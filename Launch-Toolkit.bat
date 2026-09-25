@echo off
setlocal
title Windows IT Operations Toolkit v5.1.2 - Advanced Technician Console
cd /d "%~dp0"

REM Check whether the main PowerShell script still has a downloaded-file zone marker.
powershell.exe -NoLogo -NoProfile -Command "$z = Get-Item -LiteralPath '%~dp0ITOpsToolkit.ps1' -Stream Zone.Identifier -ErrorAction SilentlyContinue; if ($z) { exit 10 } else { exit 0 }"

if errorlevel 10 (
    echo.
    echo ================================================================
    echo  WINDOWS SECURITY NOTICE
    echo ================================================================
    echo  This toolkit still has a Windows downloaded-file security marker.
    echo.
    echo  If you downloaded this toolkit from your own trusted GitHub
    echo  repository, run:
    echo.
    echo      Prepare-Toolkit.cmd
    echo.
    echo  That utility will ask before removing the downloaded-file marker.
    echo  Do not disable Smart App Control.
    echo ================================================================
    echo.
    pause
    exit /b 10
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0ITOpsToolkit.ps1"
set "EXITCODE=%ERRORLEVEL%"

if not "%EXITCODE%"=="0" (
    echo.
    echo Toolkit exited with code %EXITCODE%.
    pause
)

exit /b %EXITCODE%
