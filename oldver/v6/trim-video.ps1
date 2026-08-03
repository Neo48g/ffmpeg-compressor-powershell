# Очистка экрана при запуске
Clear-Host
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Обрезка видео с помощью FFmpeg" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Функция для получения пути к файлу с проверкой
function Get-ValidFilePath {
    param(
        [string]$Prompt,
        [bool]$MustExist = $true,
        [bool]$IsOutput = $false
    )
    do {
        $path = Read-Host $Prompt
        if ($path) { $path = $path.Trim('"') }
        
        if ([string]::IsNullOrWhiteSpace($path)) {
            Write-Host "Путь не может быть пустым. Попробуйте снова." -ForegroundColor Red
            continue
        }
        if ($IsOutput) {
            $ext = [System.IO.Path]::GetExtension($path)
            if ([string]::IsNullOrWhiteSpace($ext)) {
                $path = $path + ".mp4"
                Write-Host "Расширение не указано. Автоматически добавлено .mp4" -ForegroundColor Yellow
            }
            if ($path.EndsWith('\') -or $path.EndsWith('/')) {
                $path = Join-Path -Path $path -ChildPath $script:originalFileName
                Write-Host "Указана папка. Автоматически добавлено имя файла: $path" -ForegroundColor Yellow
            }
        }
        if ($MustExist -and -not (Test-Path -Path $path)) {
            Write-Host "Файл не найден: $path" -ForegroundColor Red
            continue
        }
        return $path
    } while ($true)
}

# Функция для получения таймкода
function Get-ValidTimeCode {
    param([string]$Prompt)
    do {
        $time = Read-Host $Prompt
        if ([string]::IsNullOrWhiteSpace($time)) {
            Write-Host "Таймкод не может быть пустым." -ForegroundColor Red
            continue
        }
        if ($time -match '^\d+\s\d+\s\d+$') {
            $parts = $time.Split(' ')
            $time = "{0:D2}:{1:D2}:{2:D2}" -f [int]$parts[0], [int]$parts[1], [int]$parts[2]
            Write-Host "Преобразовано в формат: $time" -ForegroundColor Yellow
        }
        if ($time -match '^\d{2}:\d{2}:\d{2}$') {
            return $time
        } else {
            Write-Host "Неверный формат таймкода. Используйте HH:MM:SS или HH MM SS (например, 00:00:25 или 00 00 25)." -ForegroundColor Red
            continue
        }
    } while ($true)
}

# Основной цикл программы
do {
    Write-Host ""
    Write-Host "Настройка обрезки видео" -ForegroundColor Green
    Write-Host "------------------------------------------------" -ForegroundColor DarkGray
    
    # Шаг 1: Ввод пути (ИСПРАВЛЕНО: добавлен текст подсказки вместо пустой строки)
    Write-Host "Перетащите исходное видео в окно консоли и нажмите Enter:" -ForegroundColor White
    $inputPath = Read-Host "Введите путь к файлу"
    
    if ([string]::IsNullOrWhiteSpace($inputPath)) {
        Write-Host "Путь не может быть пустым. Попробуйте снова." -ForegroundColor Red
        continue
    }
    
    $inputPath = $inputPath.Trim('"')
    
    if (-not (Test-Path -Path $inputPath)) {
        Write-Host "Файл не найден: $inputPath" -ForegroundColor Red
        continue
    }
    
    $directory = [System.IO.Path]::GetDirectoryName($inputPath)
    $fileNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($inputPath)
    $extension = [System.IO.Path]::GetExtension($inputPath)
    $script:originalFileName = Join-Path $directory "$($fileNameWithoutExt)_trimmed$extension"
    
    Write-Host ""
    Write-Host "Укажите путь для сохранения результата:" -ForegroundColor Cyan
    Write-Host "   1. Введите имя нового файла (без расширения или с расширением)" -ForegroundColor White
    Write-Host "   2. Нажмите Enter, чтобы использовать оригинальное имя с суффиксом '_trimmed'" -ForegroundColor White
    $outputPathInput = Read-Host "Выбор (оставьте пустым для варианта 2)"
    
    if ([string]::IsNullOrWhiteSpace($outputPathInput)) {
        $outputPath = $script:originalFileName
    } else {
        $ext = [System.IO.Path]::GetExtension($outputPathInput)
        if ([string]::IsNullOrWhiteSpace($ext)) {
            $outputPathInput = $outputPathInput + ".mp4"
            Write-Host "Расширение не указано. Автоматически добавлено .mp4" -ForegroundColor Yellow
        }
        if ($outputPathInput.EndsWith('\') -or $outputPathInput.EndsWith('/')) {
            $outputPathInput = Join-Path -Path $outputPathInput -ChildPath $script:originalFileName
            Write-Host "Указана папка. Автоматически добавлено имя файла: $outputPathInput" -ForegroundColor Yellow
        }
        $outputPath = $outputPathInput
    }
    
    Write-Host ""
    Write-Host "Укажите таймкоды (формат: HH:MM:SS или HH MM SS)" -ForegroundColor Cyan
    $startTime = Get-ValidTimeCode -Prompt "Время начала"
    $endTime = Get-ValidTimeCode -Prompt "Время окончания"
    
    Write-Host ""
    Write-Host "Режим обработки:" -ForegroundColor Cyan
    Write-Host "   [1] Быстрая обрезка (копирование потоков, мгновенно)" -ForegroundColor White
    Write-Host "   [2] Точная обрезка (перекодирование, медленнее, но точно до кадра)" -ForegroundColor White
    
    do {
        $modeChoice = Read-Host "Выберите режим (1 или 2)"
        switch ($modeChoice) {
            "1" { $reencode = $false; break }
            "2" { $reencode = $true; break }
            default { Write-Host "Неверный выбор." -ForegroundColor Red }
        }
    } until ($modeChoice -eq "1" -or $modeChoice -eq "2")
    
    Write-Host ""
    Write-Host "Запуск обработки..." -ForegroundColor Green
    Write-Host "Параметры:" -ForegroundColor Yellow
    Write-Host "   Файл: $inputPath -> $outputPath" -ForegroundColor White
    Write-Host "   Кадры: $startTime - $endTime | Режим: $(if ($reencode) { 'Перекодирование' } else { 'Копирование' })" -ForegroundColor White
    Write-Host "------------------------------------------------" -ForegroundColor DarkGray
    
    $arguments = @(
        '-hide_banner',
        '-loglevel', 'error',
        '-y',
        '-i', $inputPath,
        '-ss', $startTime,
        '-to', $endTime
    )
    
    if (-not $reencode) {
        $arguments += @('-c', 'copy')
    } else {
        $arguments += @('-c:v', 'libx264', '-c:a', 'aac')
    }
    $arguments += $outputPath
    
    $logFile = Join-Path $env:TEMP "ffmpeg_trim_$([System.Guid]::NewGuid().ToString()).txt"
    
    # ИСПРАВЛЕНО: Используем оператор вызова '&' вместо Start-Process.
    # Это гарантирует корректное заполнение системной переменной $LASTEXITCODE.
    Write-Host "Идет обработка... Пожалуйста, подождите." -ForegroundColor Cyan
    & ffmpeg $arguments 2> $logFile
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Видео успешно обрезано!" -ForegroundColor Green
        Write-Host "   Сохранено в: $outputPath" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "Ошибка при выполнении FFmpeg (код: $LASTEXITCODE)" -ForegroundColor Red
        Write-Host "Детали ошибки:" -ForegroundColor Yellow
        if (Test-Path $logFile) {
            $errorLog = Get-Content $logFile -Raw
            if (-not [string]::IsNullOrWhiteSpace($errorLog)) {
                Write-Host $errorLog -ForegroundColor DarkRed
            } else {
                Write-Host "   (Лог ошибок пуст)" -ForegroundColor DarkGray
            }
            Remove-Item $logFile -Force
        }
    }
    
    Write-Host ""
    $repeat = Read-Host "Обрезать еще одно видео? (Y/N)"
    
} while ($repeat -match '^[Yy]$')

Write-Host ""
Write-Host "Спасибо за использование! Нажмите любую клавишу для выхода..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")