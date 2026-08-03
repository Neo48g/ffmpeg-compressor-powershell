@echo off
title Video Compressor
cd /d "%~dp0"

:: Родительская папка
for %%I in (..) do set "VIDEO_FOLDER=%%~fI"

:: Запускаем PowerShell скрипт с передачей пути к папке с видео
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\yt-dlp-menu.ps1" -VideoFolder "%VIDEO_FOLDER%"

echo.
echo -------------------------------------------------------------------
echo Process finished. Press any key to close this window.
pause >nul