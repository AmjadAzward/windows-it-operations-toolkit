@echo off
title Windows IT Operations Toolkit v4.0
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0ITOpsToolkit.ps1"
if errorlevel 1 pause
