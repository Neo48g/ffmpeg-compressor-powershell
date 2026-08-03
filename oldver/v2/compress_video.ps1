# --- SETTINGS ---
$inputFolder = "C:\Users\v86x\Videos\FFmpegVIDS"
$outputFolder = ".\compressed"
$extensions = @(".mp4", ".mkv", ".avi", ".mov", ".m4v", ".webm", ".ts", ".mts", ".m2ts", ".flv", ".wmv")

# Функция для красивого форматирования размера файлов
function Format-FileSize {
    param ([long]$size)
    if ($size -ge 1GB) { return "{0:N2} GB" -f ($size / 1GB) }
    if ($size -ge 1MB) { return "{0:N2} MB" -f ($size / 1MB) }
    if ($size -ge 1KB) { return "{0:N2} KB" -f ($size / 1KB) }
    return "$size Bytes"
}

# 1. Create output folder
if (-not (Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder | Out-Null
    Write-Host "Created folder: $outputFolder" -ForegroundColor Gray
}

# 2. FOOLPROOF FILE SEARCH
$allFiles = Get-ChildItem -Path $inputFolder -File
$files = @($allFiles | Where-Object { $extensions -contains $_.Extension.ToLower() })
if ($files.Count -eq 0) {
    Write-Host "Error: No video files found in $inputFolder" -ForegroundColor Red
    Write-Host "Debug: Files currently in this folder:" -ForegroundColor Yellow
    $allFiles | Select-Object Name, Extension | Format-Table -AutoSize
    exit
}
Write-Host "Files found: $($files.Count). Starting compression..." -ForegroundColor Cyan
Write-Host "---------------------------------------------------"

# 3. Processing loop
$counter = 1
foreach ($file in $files) {
    $inputFile = $file.FullName
    $outputFile = Join-Path $outputFolder "$($file.BaseName)_compressed.mp4"

    # Получаем размер файла ДО сжатия
    $sizeBefore = $file.Length
    $sizeBeforeFormatted = Format-FileSize $sizeBefore
    
    Write-Host "`n[$counter/$($files.Count)] Processing: $($file.Name)" -ForegroundColor Yellow
    Write-Host "  Initial size: $sizeBeforeFormatted" -ForegroundColor Gray

    # Подготовка к запуску FFmpeg
    $logFile = Join-Path $env:TEMP "ffmpeg_log_$($file.BaseName).txt"
    if (Test-Path $logFile) { Remove-Item $logFile -Force }

    $ffmpegArgs = "-i `"$inputFile`" -c:v libx264 -crf 23 -preset medium -c:a aac -b:a 128k -y `"$outputFile`""

    # Получаем общую длительность видео через ffprobe для точного прогресс-бара
    $totalDuration = 0
    try {
        $probeOutput = & ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$inputFile" 2>$null
        if ($probeOutput) { $totalDuration = [double]$probeOutput }
    } catch {
        # Если ffprobe не найден, прогресс-бар будет показывать только таймер
    }

    # Запускаем FFmpeg в фоне с записью stderr во временный файл
    $process = Start-Process -FilePath "ffmpeg" -ArgumentList $ffmpegArgs -RedirectStandardError $logFile -PassThru -NoNewWindow

    # Запускаем таймер
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # Цикл отслеживания прогресса
    while (!$process.HasExited) {
        $elapsed = $stopwatch.Elapsed
        $currentTime = 0

        # Читаем последнюю строку из лога FFmpeg
        if (Test-Path $logFile) {
            try {
                $lastLine = Get-Content $logFile -Tail 1 -ErrorAction Stop
                # Парсим текущее время из вывода ffmpeg (формат time=00:00:00.00)
                if ($lastLine -match 'time=(\d+):(\d+):(\d+(?:\.\d+)?)') {
                    $h = [int]$matches[1]; $m = [int]$matches[2]; $s = [double]$matches[3]
                    $currentTime = $h * 3600 + $m * 60 + $s
                }
            } catch {
                # Игнорируем ошибки, если файл временно заблокирован
            }
        }

        $percent = 0
        if ($totalDuration -gt 0) {
            $percent = [math]::Min(100, ($currentTime / $totalDuration) * 100)
        }

        $statusText = "Time: $($elapsed.ToString('hh\:mm\:ss'))"
        if ($totalDuration -gt 0) {
            $statusText += " | Progress: $([math]::Round($percent, 1))%"
        }

        # Отображаем стандартный PowerShell Progress Bar
        Write-Progress -Activity "Compressing: $($file.Name)" `
                       -Status $statusText `
                       -PercentComplete $percent `
                       -Id 1
        Start-Sleep -Milliseconds 1000
    }

    $stopwatch.Stop()
    Write-Progress -Activity "Compressing: $($file.Name)" -Completed -Id 1

    # Удаляем временный лог сжатия
    if (Test-Path $logFile) { Remove-Item $logFile -Force }

    # Проверяем результат и получаем размер ПОСЛЕ сжатия
    if ($LASTEXITCODE -eq 0 -and (Test-Path $outputFile)) {
        $sizeAfter = (Get-Item $outputFile).Length
        $sizeAfterFormatted = Format-FileSize $sizeAfter
        $ratio = [math]::Round(($sizeAfter / $sizeBefore) * 100, 1)
        
        Write-Host "  -> Successfully saved!" -ForegroundColor Green
        Write-Host "  -> Final size: $sizeAfterFormatted (Compressed to $ratio%)" -ForegroundColor Green
        Write-Host "  -> Time taken: $($stopwatch.Elapsed.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan

                # ==========================================
        # РАСЧЕТ VMAF С ПРОГРЕСС-БАРОМ
        # ==========================================
        
        # Получаем точные параметры оригинала (VMAF требует идеального совпадения сетки)
        $vmafWidth = & ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$inputFile" 2>$null
        $vmafHeight = & ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$inputFile" 2>$null
        $vmafFpsStr = & ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of csv=p=0 "$inputFile" 2>$null

        $vmafScore = "N/A"
        
        if ($vmafWidth -and $vmafHeight -and $vmafFpsStr) {
            # Преобразуем дробный FPS (например, 30000/1001) в нормальное число
            if ($vmafFpsStr -match '(\d+)/(\d+)') {
                $vmafFps = [math]::Round([double]$matches[1] / [double]$matches[2], 3)
            } else {
                $vmafFps = [double]$vmafFpsStr
            }

            $vmafLogFile = Join-Path $env:TEMP "vmaf_log_$($file.BaseName).txt"
            if (Test-Path $vmafLogFile) { Remove-Item $vmafLogFile -Force }

            # Команда VMAF с принудительным приведением к разрешению и FPS оригинала
            $vmafArgs = "-i `"$inputFile`" -i `"$outputFile`" -lavfi `"[0:v]scale=$vmafWidth`:$vmafHeight,fps=$vmafFps[ref];[1:v]scale=$vmafWidth`:$vmafHeight,fps=$vmafFps[dist];[ref][dist]libvmaf`" -f null -"

            # Показываем начальный статус в прогресс-баре (вместо Write-Host)
            Write-Progress -Activity "Calculating VMAF: $($file.Name)" `
                           -Status "Initializing..." `
                           -PercentComplete -1 `
                           -Id 2

            # Запускаем расчет VMAF в фоне с записью stderr
            $vmafProcess = Start-Process -FilePath "ffmpeg" -ArgumentList $vmafArgs -RedirectStandardError $vmafLogFile -PassThru -NoNewWindow

            # Запускаем отдельный таймер для VMAF
            $vmafStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            # Цикл отслеживания прогресса VMAF
            while (!$vmafProcess.HasExited) {
                $vmafElapsed = $vmafStopwatch.Elapsed
                $vmafCurrentTime = 0

                if (Test-Path $vmafLogFile) {
                    try {
                        $vmafLastLine = Get-Content $vmafLogFile -Tail 1 -ErrorAction Stop
                        if ($vmafLastLine -match 'time=(\d+):(\d+):(\d+(?:\.\d+)?)') {
                            $h = [int]$matches[1]; $m = [int]$matches[2]; $s = [double]$matches[3]
                            $vmafCurrentTime = $h * 3600 + $m * 60 + $s
                        }
                    } catch {
                        # Игнорируем ошибки, если файл временно заблокирован
                    }
                }

                $vmafPercent = 0
                if ($totalDuration -gt 0) {
                    $vmafPercent = [math]::Min(100, ($vmafCurrentTime / $totalDuration) * 100)
                }

                $vmafStatusText = "Time: $($vmafElapsed.ToString('hh\:mm\:ss'))"
                if ($totalDuration -gt 0) {
                    $vmafStatusText += " | Progress: $([math]::Round($vmafPercent, 1))%"
                }

                # Обновляем тот же прогресс-бар (Id 2)
                Write-Progress -Activity "Calculating VMAF: $($file.Name)" `
                               -Status $vmafStatusText `
                               -PercentComplete $vmafPercent `
                               -Id 2
                Start-Sleep -Milliseconds 1000
            }

            $vmafStopwatch.Stop()
            
            # Очищаем прогресс-бар VMAF (теперь надпись полностью исчезнет)
            Write-Progress -Activity "Calculating VMAF: $($file.Name)" -Completed -Id 2

            # Парсим результат из лога
            if (Test-Path $vmafLogFile) {
                $logContent = Get-Content $vmafLogFile -Raw
                if ($logContent -match 'VMAF score:\s*([\d\.]+)') {
                    $vmafScore = [math]::Round([double]$matches[1], 2)
                } elseif ($logContent -match '"vmaf":\s*([\d\.]+)') {
                    $vmafScore = [math]::Round([double]$matches[1], 2)
                } else {
                    $vmafScore = "N/A (Check VMAF support)"
                }
                Remove-Item $vmafLogFile -Force
            }

            Write-Host "  -> VMAF calculation time: $($vmafStopwatch.Elapsed.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
        }

        # Цветовая индикация результата VMAF
        $vmafColor = "Gray"
        if ($vmafScore -is [double]) {
            if ($vmafScore -ge 90) { $vmafColor = "DarkGreen" }
            elseif ($vmafScore -ge 80) { $vmafColor = "Yellow" }
            elseif ($vmafScore -ge 70) { $vmafColor = "DarkYellow" }
            else { $vmafColor = "Red" }
        }
        
        Write-Host "  -> VMAF Quality Score: $vmafScore" -ForegroundColor $vmafColor
        # ==========================================
        # КОНЕЦ РАСЧЕТА VMAF
        # ==========================================

    } else {
        Write-Host "  -> ERROR processing file: $($file.Name)" -ForegroundColor Red
    }

    $counter++
}

Write-Host "`n---------------------------------------------------"
Write-Host "All tasks completed!" -ForegroundColor Cyan