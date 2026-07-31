@echo off
:: Заголовок окна
title Video Compressor

:: Переходим в папку, где лежит этот bat-файл
cd /d "%~dp0"

:: Запускаем PowerShell скрипт. 
:: -NoProfile ускоряет запуск, -ExecutionPolicy Bypass обходит запреты на запуск скриптов
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\compress_video.ps1"

:: Делаем паузу, чтобы окно не закрылось сразу и могли прочитать результат
echo.
echo -------------------------------------------------------------------
echo Process finished. Press any key to close this window.
pause >nul