# ==========================================
# 1. АВТОМАТИЧЕСКИЙ ЗАПРОС ПРАВ АДМИНИСТРАТОРА
# ==========================================
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Скрипт запущен без прав администратора. Запрашиваю повышение..." -ForegroundColor Yellow
    
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) { $scriptPath = $MyInvocation.MyCommand.Path }

    if ($scriptPath) {
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
        exit
    } else {
        Write-Host "Не удалось определить путь к файлу скрипта." -ForegroundColor Red
        Write-Host "Пожалуйста, откройте PowerShell от имени Администратора вручную." -ForegroundColor Yellow
        pause
        exit
    }
}

# Включаем TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ==========================================
# 2. ОСНОВНАЯ ЛОГИКА УСТАНОВКИ (FULL ВЕРСИЯ)
# ==========================================

$installDir = "C:\ffmpeg"
$binDir = "$installDir\bin"
$zipPath = "$env:TEMP\ffmpeg_full.zip"
$extractPath = "$env:TEMP\ffmpeg_extract"

# Ссылка на FULL GPL сборку от BtbN (содержит ВСЕ библиотеки: x264, x265, aom, vpx и т.д.)
$downloadUrl = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip" 

Write-Host "=== Начало установки FFmpeg (FULL версия со всеми библиотеками) ===" -ForegroundColor Cyan
Write-Host "Права администратора подтверждены." -ForegroundColor Green

# 1. Скачивание архива
Write-Host "1. Скачивание Full версии FFmpeg (это может занять немного времени)..." -ForegroundColor Yellow
try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing
    Write-Host "   Успешно скачано." -ForegroundColor Green
} catch {
    Write-Host "Ошибка при скачивании: $_" -ForegroundColor Red
    pause
    exit
}

# 2. Распаковка
Write-Host "2. Распаковка архива..." -ForegroundColor Yellow
if (Test-Path $extractPath) { Remove-Item -Path $extractPath -Recurse -Force }
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
Write-Host "   Успешно распаковано." -ForegroundColor Green

# 3. Поиск папки с бинарниками и перемещение
Write-Host "3. Перемещение файлов в $installDir..." -ForegroundColor Yellow

# Умный поиск: проверяем, есть ли папка bin прямо в корне распаковки, или она лежит в подпапке
if (Test-Path "$extractPath\bin") {
    $extractedFolder = $extractPath
} else {
    $extractedFolder = Get-ChildItem -Path $extractPath -Directory | Select-Object -First 1
}

if (Test-Path $installDir) { 
    Remove-Item -Path $installDir -Recurse -Force 
}
Move-Item -Path $extractedFolder.FullName -Destination $installDir -Force
Write-Host "   Файлы перемещены." -ForegroundColor Green

# 4. Добавление в системный PATH
Write-Host "4. Обновление системной переменной Path..." -ForegroundColor Yellow
$currentSystemPath = [Environment]::GetEnvironmentVariable("Path", "Machine")

if ($currentSystemPath -notlike "*$binDir*") {
    $newPath = "$currentSystemPath;$binDir"
    [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
    Write-Host "   Путь $binDir успешно добавлен в системный Path." -ForegroundColor Green
} else {
    Write-Host "   Путь $binDir уже присутствует в системном Path." -ForegroundColor Yellow
}

# 5. Обновление PATH для текущей сессии
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

# 6. Очистка временных файлов
Write-Host "5. Очистка временных файлов..." -ForegroundColor Yellow
Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "   Временные файлы удалены." -ForegroundColor Green

# 7. Проверка и вывод списка библиотек
Write-Host "`n=== Установка завершена! ===" -ForegroundColor Cyan
try {
    Write-Host "Версия FFmpeg:" -ForegroundColor Yellow
    & "$binDir\ffmpeg.exe" -version | Select-Object -First 1
    
    Write-Host "`nСписок подключенных библиотек (конфигурация):" -ForegroundColor Yellow
    # Показываем только строку с конфигурацией, где перечислены все библиотеки
    & "$binDir\ffmpeg.exe" -version | Select-String "configuration:" | ForEach-Object { $_.Line }
    
    Write-Host "`nFFmpeg Full успешно установлен и готов к работе!" -ForegroundColor Green
} catch {
    Write-Host "Не удалось проверить версию. Возможно, потребуется перезапустить терминал." -ForegroundColor Red
}

Write-Host "`nНажмите любую клавишу для выхода..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")