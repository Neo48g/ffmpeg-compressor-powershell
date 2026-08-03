#Requires -Version 5.1
<#
.SYNOPSIS
    FFmpeg Tools Hub - Центр управления скриптами обработки медиа.
.DESCRIPTION
    Консольный интерфейс (хаб) для запуска скриптов:
    - compress_video.ps1 (Сжатие)
    - convert-media.ps1 (Конвертация)
    - trim-video.ps1 (Обрезка)
#>

Clear-Host
$Host.UI.RawUI.WindowTitle = "FFmpeg Tools Hub"

# Определение пути к скриптам (предполагается, что они лежат в той же папке)
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $ScriptDir) { $ScriptDir = Get-Location }

$Scripts = @{
    Compress = Join-Path $ScriptDir "compress_video.ps1"
    Convert  = Join-Path $ScriptDir "convert-media.ps1"
    Trim     = Join-Path $ScriptDir "trim-video.ps1"
}

function Test-FFmpegGlobal {
    try {
        $null = Get-Command ffmpeg -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Show-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  +==========================================================+" -ForegroundColor Cyan
    Write-Host "  |               FFmpeg Tools Hub / Хаб                     |" -ForegroundColor Cyan
    Write-Host "  +==========================================================+" -ForegroundColor Cyan
    Write-Host "  |  Unified interface for video processing scripts.         |" -ForegroundColor DarkCyan
    Write-Host "  |  Единый интерфейс для скриптов обработки видео.          |" -ForegroundColor DarkCyan
    Write-Host "  +==========================================================+" -ForegroundColor Cyan
    Write-Host ""
    
    $ffmpegStatus = if (Test-FFmpegGlobal) { "[OK] FFmpeg найден в системе (System PATH)" } else { "[X] FFmpeg НЕ найден (Добавьте в PATH)" }
    $ffmpegColor = if (Test-FFmpegGlobal) { "Green" } else { "Red" }
    Write-Host "  Статус: " -NoNewline -ForegroundColor Gray
    Write-Host "$ffmpegStatus" -ForegroundColor $ffmpegColor
    Write-Host ""
}

function Show-Menu {
    Show-Banner
    
    Write-Host "  Выберите инструмент / Choose a tool:" -ForegroundColor Yellow
    Write-Host "  -----------------------------------------------------------" -ForegroundColor DarkGray
    
    # 1. Compress
    $status1 = if (Test-Path $Scripts.Compress) { "[OK]" } else { "[NOT FOUND]" }
    $color1 = if (Test-Path $Scripts.Compress) { "Green" } else { "Red" }
    Write-Host "  [1] Сжатие видео (Video Compression)       " -NoNewline -ForegroundColor White
    Write-Host "$status1" -ForegroundColor $color1
    
    # 2. Convert
    $status2 = if (Test-Path $Scripts.Convert) { "[OK]" } else { "[NOT FOUND]" }
    $color2 = if (Test-Path $Scripts.Convert) { "Green" } else { "Red" }
    Write-Host "  [2] Конвертация медиа (Media Conversion)   " -NoNewline -ForegroundColor White
    Write-Host "$status2" -ForegroundColor $color2
    
    # 3. Trim
    $status3 = if (Test-Path $Scripts.Trim) { "[OK]" } else { "[NOT FOUND]" }
    $color3 = if (Test-Path $Scripts.Trim) { "Green" } else { "Red" }
    Write-Host "  [3] Обрезка видео (Video Trimming)         " -NoNewline -ForegroundColor White
    Write-Host "$status3" -ForegroundColor $color3

    Write-Host "  -----------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  [4] Выход (Exit)" -ForegroundColor Red
    Write-Host ""
}

function Run-Script {
    param([string]$Path, [string]$Name)
    
    if (-not (Test-Path $Path)) {
        Write-Host "`n  [!] Ошибка: Скрипт '$Name' не найден в папке:" -ForegroundColor Red
        Write-Host "      $Path" -ForegroundColor DarkRed
        Write-Host "      Убедитесь, что все файлы лежат в одной директории.`n" -ForegroundColor Yellow
        Read-Host "  Нажмите Enter для возврата в меню"
        return
    }
    
    Write-Host "`n  [i] Запуск: $Name ..." -ForegroundColor Cyan
    Write-Host "  (Для возврата в хаб закройте окно инструмента)`n" -ForegroundColor DarkGray
    
    # Запускаем в новом окне PowerShell, чтобы избежать конфликтов Clear-Host и потоков ввода
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoExit -ExecutionPolicy Bypass -File `"$Path`""
    $psi.UseShellExecute = $false
    
    $process = [System.Diagnostics.Process]::Start($psi)
    $process.WaitForExit()
}

# Основной цикл
do {
    Show-Menu
    $choice = Read-Host "  Введите номер (1-4)"
    
    switch ($choice) {
        "1" { Run-Script -Path $Scripts.Compress -Name "compress_video.ps1" }
        "2" { Run-Script -Path $Scripts.Convert -Name "convert-media.ps1" }
        "3" { Run-Script -Path $Scripts.Trim -Name "trim-video.ps1" }
        "4" { 
            Write-Host "`n  До свидания! / Goodbye!`n" -ForegroundColor Cyan
            exit 
        }
        default {
            Write-Host "`n  [!] Неверный выбор. / Invalid choice." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
} while ($true)