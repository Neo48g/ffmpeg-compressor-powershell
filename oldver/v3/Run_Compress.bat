@echo off
:: Заголовок окна
title Video Compressor
:: Переходим в папку, где лежит этот bat-файл
cd /d "%~dp0"

:: Запускаем PowerShell скрипт
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\compress_video.ps1"

:: Запоминаем код возврата PowerShell
set EXITCODE=%ERRORLEVEL%

:: Если PowerShell упал с ошибкой - показываем сообщение
if %EXITCODE% neq 0 (
    echo.
    echo ============================================================
    echo  PowerShell script exited with error code: %EXITCODE%
    echo  Check the script for syntax errors.
    echo ============================================================
    echo.
    pause
)

:: Выходим
exit /b %EXITCODE%