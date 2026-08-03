# yt-dlp Auto-Installer Script
# Автоматическая установка yt-dlp с GitHub и добавление в PATH

# Проверка прав администратора
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[ОШИБКА]: Скрипт требует прав администратора!" -ForegroundColor Red
    Write-Host "Пожалуйста, запустите PowerShell от имени администратора." -ForegroundColor Yellow
    Write-Host "Правый клик по PowerShell -> Запуск от имени администратора" -ForegroundColor Gray
    $null = Read-Host "`nНажмите Enter для выхода"
    exit
}

# Установка кодировки
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Magenta
Write-Host "  yt-dlp Auto-Installer" -ForegroundColor Magenta
Write-Host "========================================`n" -ForegroundColor Magenta

# Путь для установки
$installPath = "C:\yt-dlp"
$exePath = "$installPath\yt-dlp.exe"

# Создание папки
Write-Host "[1/4] Создание папки установки..." -ForegroundColor Cyan
if (-not (Test-Path $installPath)) {
    New-Item -ItemType Directory -Path $installPath -Force | Out-Null
    Write-Host "Папка создана: $installPath" -ForegroundColor Green
} else {
    Write-Host "Папка уже существует: $installPath" -ForegroundColor Yellow
}

# Получение последней версии с GitHub
Write-Host "`n[2/4] Получение информации о последней версии..." -ForegroundColor Cyan
try {
    $releasesUrl = "https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest"
    $release = Invoke-RestMethod -Uri $releasesUrl -Headers @{"User-Agent"="PowerShell"}
    $latestVersion = $release.tag_name
    Write-Host "Последняя версия: $latestVersion" -ForegroundColor Green
    
    # Поиск yt-dlp.exe в assets
    $exeAsset = $release.assets | Where-Object { $_.name -eq "yt-dlp.exe" }
    if (-not $exeAsset) {
        throw "yt-dlp.exe не найден в релизе!"
    }
    $downloadUrl = $exeAsset.browser_download_url
} catch {
    Write-Host "[ОШИБКА]: Не удалось получить информацию о релизе!" -ForegroundColor Red
    Write-Host "Проверьте подключение к интернету." -ForegroundColor Yellow
    $null = Read-Host "`nНажмите Enter для выхода"
    exit
}

# Скачивание файла
Write-Host "`n[3/4] Скачивание yt-dlp.exe..." -ForegroundColor Cyan
Write-Host "URL: $downloadUrl" -ForegroundColor Gray
Write-Host "Размер: $([math]::Round($exeAsset.size / 1MB, 2)) MB" -ForegroundColor Gray

try {
    # Используем WebClient для показа прогресса
    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("User-Agent", "PowerShell")
    
    # Создаем делегат для отслеживания прогресса
    $progress = {
        param($sender, $e)
        $percent = [math]::Round(($e.BytesReceived / $e.TotalBytesToReceive) * 100, 1)
        Write-Progress -Activity "Скачивание yt-dlp.exe" -Status "$percent%" -PercentComplete $percent
    }
    
    Register-ObjectEvent -InputObject $webClient -EventName DownloadProgressChanged -Action $progress | Out-Null
    
    # Скачивание
    $webClient.DownloadFile($downloadUrl, $exePath)
    
    Write-Progress -Activity "Скачивание yt-dlp.exe" -Completed
    Write-Host "Файл успешно скачан!" -ForegroundColor Green
} catch {
    Write-Host "[ОШИБКА]: Не удалось скачать файл!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    $null = Read-Host "`nНажмите Enter для выхода"
    exit
}

# Добавление в PATH
Write-Host "`n[4/4] Добавление в переменную PATH..." -ForegroundColor Cyan

# Получение текущего системного PATH
$currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")

# Проверка, есть ли уже наш путь
if ($currentPath -notlike "*$installPath*") {
    # Добавляем путь в конец
    $newPath = "$currentPath;$installPath"
    
    # Устанавливаем новый PATH
    [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
    
    Write-Host "Путь добавлен в системную переменную PATH!" -ForegroundColor Green
    Write-Host "Путь: $installPath" -ForegroundColor Gray
} else {
    Write-Host "Путь уже присутствует в PATH!" -ForegroundColor Yellow
}

# Обновление PATH для текущей сессии
$env:Path = "$env:Path;$installPath"

# Проверка установки
Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "  Проверка установки" -ForegroundColor Magenta
Write-Host "========================================`n" -ForegroundColor Magenta

try {
    $version = & "$exePath" --version
    Write-Host "[OK] yt-dlp успешно установлен!" -ForegroundColor Green
    Write-Host "Версия: $version" -ForegroundColor Cyan
    Write-Host "Путь: $exePath" -ForegroundColor Gray
} catch {
    Write-Host "[ОШИБКА]: Не удалось проверить версию!" -ForegroundColor Red
    Write-Host "Возможно, файл поврежден при скачивании." -ForegroundColor Yellow
    $null = Read-Host "`nНажмите Enter для выхода"
    exit
}

# Финальное сообщение
Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "  Установка завершена!" -ForegroundColor Magenta
Write-Host "========================================`n" -ForegroundColor Magenta

Write-Host "Что дальше:" -ForegroundColor Yellow
Write-Host "1. Закройте все окна PowerShell" -ForegroundColor White
Write-Host "2. Откройте новое окно PowerShell" -ForegroundColor White
Write-Host "3. Проверьте работу командой: yt-dlp --version" -ForegroundColor White
Write-Host "`nТакже рекомендуется установить FFmpeg для полной функциональности:" -ForegroundColor Yellow
Write-Host "Скачайте с: https://www.gyan.dev/ffmpeg/builds/" -ForegroundColor Gray
Write-Host "И добавьте папку bin в PATH (аналогично этому скрипту)" -ForegroundColor Gray

$null = Read-Host "`nНажмите Enter для выхода"