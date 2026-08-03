#Requires -Version 5.1
$ScriptDir = $PSScriptRoot; if (-not $ScriptDir) { $ScriptDir = Get-Location }
$ConfigFile = Join-Path $ScriptDir "global_config.json"
$global:Cfg = if (Test-Path $ConfigFile) { Get-Content $ConfigFile -Raw | ConvertFrom-Json } else { @{Language="EN"} }
function L($en, $ru) { if ($global:Cfg.Language -eq 'RU') { return $ru } return $en }
function Show-Banner { param([string]$Title) Clear-Host; Write-Host "`n========================================================" -ForegroundColor Cyan; Write-Host "  $Title" -ForegroundColor Yellow; Write-Host "========================================================`n" -ForegroundColor Cyan }

do {
    Show-Banner (L "YT-DLP DOWNLOADER" "СКАЧИВАНИЕ YT-DLP")
    if (-not (Get-Command yt-dlp -ErrorAction SilentlyContinue)) {
        Write-Host "  [X] yt-dlp $(L 'not found. Install via Hub.' 'не найден. Установите через Хаб.')" -ForegroundColor Red
        Write-Host "`n  $(L 'Press Enter to return...' 'Нажмите Enter для возврата...')" -ForegroundColor Gray
        Read-Host
        break
    }
    
    Write-Host "  [1] $(L 'Video (MP4)' 'Видео (MP4)')" -ForegroundColor White
    Write-Host "  [2] $(L 'Audio (MP3)' 'Аудио (MP3)')" -ForegroundColor White
    Write-Host "  [3] $(L 'Playlist' 'Плейлист')" -ForegroundColor White
    Write-Host "  [4] $(L 'Video Fragment (by timecode)' 'Фрагмент видео (по таймкоду)')" -ForegroundColor White
    Write-Host "  --------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  [0] $(L 'Back to Hub' 'Вернуться в Хаб')" -ForegroundColor Red
    
    $c = Read-Host (L "  Choice" "  Выбор")
    if ($c -eq '0') { break }
    
    Write-Host "`n  $(L 'Enter URL:' 'Введите ссылку:')" -ForegroundColor White
    $url = Read-Host "  > "
    
    $yArgs = @()
    $statusMsg = L "Downloading..." "Скачивание..."
    
    switch ($c) {
        '1' { 
            $yArgs = @("-f", "bv+ba/b", "--merge-output-format", "mp4", $url) 
        }
        '2' { 
            $yArgs = @("-x", "--audio-format", "mp3", $url) 
        }
        '3' { 
            $yArgs = @("--yes-playlist", $url) 
        }
        '4' {
            Write-Host "  $(L 'Start time (e.g., 1:30 or 1 30):' 'Время начала (например, 1:30 или 1 30):')" -ForegroundColor White
            $start = (Read-Host "  > ").Trim().Replace(" ", ":")
            
            Write-Host "  $(L 'End time (e.g., 1:30 or 1 30):' 'Время окончания (например, 1:30 или 1 30):')" -ForegroundColor White
            $end = (Read-Host "  > ").Trim().Replace(" ", ":")
            
            $section = "*$start-$end"
            $yArgs = @(
                "--download-sections", $section, 
                "-f", "bv+ba/b", 
                "--merge-output-format", "mp4", 
                "--force-keyframes-at-cuts", 
                $url
            )
            $statusMsg = L "Downloading fragment..." "Скачивание фрагмента..."
        }
    }
    
    Write-Host "`n  $statusMsg" -ForegroundColor Yellow
    $proc = Start-Process -FilePath "yt-dlp" -ArgumentList $yArgs -NoNewWindow -Wait -PassThru
    if ($proc.ExitCode -eq 0) { Write-Host "`n  [OK] $(L 'Done' 'Готово')" -ForegroundColor Green }
    else { Write-Host "`n  [X] $(L 'Error' 'Ошибка')" -ForegroundColor Red }
    
    Write-Host "`n  $(L 'Press Enter to continue...' 'Нажмите Enter для продолжения...')" -ForegroundColor Gray
    Read-Host
} while ($true)