@echo off
setlocal
title Prepare Windows IT Operations Toolkit
cd /d "%~dp0"

echo ================================================================
echo  PREPARE WINDOWS IT OPERATIONS TOOLKIT
echo ================================================================
echo.
echo This utility removes the Windows "downloaded from the Internet"
echo zone marker from this toolkit's PowerShell, CMD, BAT, and module files.
echo.
echo ONLY continue if you trust the source of this toolkit.
echo Recommended trusted source:
echo https://github.com/AmjadAzward/windows-it-operations-toolkit
echo.
echo This does NOT disable Smart App Control, Microsoft Defender,
echo Windows Firewall, or any Windows security feature.
echo.

choice /C YN /N /M "Do you trust these files and want to unblock them? [Y/N]: "
if errorlevel 2 (
    echo.
    echo No files were changed.
    pause
    exit /b 1
)

echo.
echo Removing downloaded-file zone markers...

powershell.exe -NoLogo -NoProfile -Command ^
  "$root = [IO.Path]::GetFullPath('%~dp0');" ^
  "$files = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in '.ps1','.psm1','.psd1','.bat','.cmd','.md','.html' };" ^
  "$count = 0;" ^
  "foreach ($f in $files) { try { Unblock-File -LiteralPath $f.FullName -ErrorAction Stop; $count++ } catch {} };" ^
  "Write-Host ('Processed {0} trusted toolkit files.' -f $count)"

if errorlevel 1 (
    echo.
    echo Preparation could not complete.
    echo Try right-clicking the ZIP file ^> Properties ^> Unblock,
    echo then extract it again.
    pause
    exit /b 1
)

echo.
echo Toolkit preparation completed.
echo You can now run Launch-Toolkit.bat
echo.
pause
exit /b 0
