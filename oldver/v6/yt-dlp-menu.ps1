# yt-dlp Menu Script
# Чистый, структурированный и надежный интерфейс

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Функция для красивого заголовка
function Show-ProcessHeader {
    param([string]$Title)
    Clear-Host
    Write-Host "`n========================================" -ForegroundColor Magenta
    Write-Host "  $Title" -ForegroundColor Magenta
    Write-Host "========================================`n" -ForegroundColor Magenta
}

# Функция для красивого завершения
function Show-ProcessFooter {
    param([string]$Message = "Процесс завершен успешно!")
    Write-Host "`n----------------------------------------" -ForegroundColor Magenta
    Write-Host "  [OK] $Message" -ForegroundColor Green
    Write-Host "----------------------------------------`n" -ForegroundColor Magenta
}

function Test-YtDlp {
    try { $null = Get-Command yt-dlp -ErrorAction Stop; return $true } catch { return $false }
}

function Test-FFmpeg {
    try { $null = Get-Command ffmpeg -ErrorAction Stop; return $true } catch { return $false }
}

# 1. Стандартное скачивание видео (MP4 + AAC)
function Download-Video {
    param([string]$Url, [string]$Quality)
    Show-ProcessHeader -Title "СКАЧИВАНИЕ ВИДЕО"
    Write-Host "Формат: MP4 с аудио AAC (гарантия работы в монтаже)" -ForegroundColor Yellow
    Write-Host "Ссылка: $Url" -ForegroundColor Gray
    
    $commonArgs = "--quiet --no-warnings --merge-output-format mp4 --postprocessor-args `"ffmpeg:-loglevel error -c:v copy -c:a aac -b:a 192k`""
    
    if ($Quality -eq "best") {
        Write-Host "`nКачество: Лучшее доступное" -ForegroundColor Cyan
        Invoke-Expression "yt-dlp -f `"bv+ba`" $commonArgs `"$Url`""
    } else {
        Write-Host "`nКачество: До 1080p" -ForegroundColor Cyan
        Invoke-Expression "yt-dlp -f `"bv[height<=1080]+ba`" $commonArgs `"$Url`""
    }
    Show-ProcessFooter -Message "Видео успешно скачано!"
}

# 2. Скачивание плейлиста
function Download-Playlist {
    param([string]$Url)
    Show-ProcessHeader -Title "СКАЧИВАНИЕ ПЛЕЙЛИСТА"
    Write-Host "Файлы будут сохранены в папки по авторам" -ForegroundColor Yellow
    Write-Host "Ссылка: $Url" -ForegroundColor Gray
    Write-Host "`n[Загрузка...]`n" -ForegroundColor White
    
    yt-dlp --quiet --no-warnings --download-archive downloaded.txt -o "%(uploader)s/%(title)s.%(ext)s" $Url
    Show-ProcessFooter -Message "Плейлист успешно скачан!"
}

# 3. Скачивание аудио (MP3 или M4A)
function Download-Audio {
    param([string]$Url, [string]$Format)
    Show-ProcessHeader -Title "СКАЧИВАНИЕ АУДИО"
    Write-Host "Формат: $Format" -ForegroundColor Yellow
    Write-Host "Ссылка: $Url" -ForegroundColor Gray
    Write-Host "`n[Загрузка...]`n" -ForegroundColor White
    
    yt-dlp --quiet --no-warnings -x --audio-format $Format --embed-thumbnail $Url
    Show-ProcessFooter -Message "Аудио успешно скачано!"
}

# 4. Скачивание фрагмента по таймкоду
function Download-Section {
    param([string]$Url, [string]$StartTime, [string]$EndTime)
    Show-ProcessHeader -Title "СКАЧИВАНИЕ ФРАГМЕНТА"
    Write-Host "Фрагмент: с $StartTime до $EndTime" -ForegroundColor Yellow
    Write-Host "Формат: MP4 с аудио AAC" -ForegroundColor Yellow
    Write-Host "Ссылка: $Url" -ForegroundColor Gray
    Write-Host "`n[Обработка фрагмента...]`n" -ForegroundColor White
    
    $section = "*$StartTime-$EndTime"
    $cmd = "yt-dlp --quiet --no-warnings --download-sections `"$section`" --merge-output-format mp4 --postprocessor-args `"ffmpeg:-loglevel error -c:v copy -c:a aac -b:a 192k`" `"$Url`""
    Invoke-Expression $cmd
    
    Show-ProcessFooter -Message "Фрагмент успешно скачан!"
}

# 5. Скачивание с субтитрами
function Download-WithSubs {
    param([string]$Url, [string]$Lang)
    Show-ProcessHeader -Title "СКАЧИВАНИЕ С СУБТИТРАМИ"
    Write-Host "Языки субтитров: $Lang" -ForegroundColor Yellow
    Write-Host "Ссылка: $Url" -ForegroundColor Gray
    Write-Host "`n[Загрузка...]`n" -ForegroundColor White
    
    yt-dlp --quiet --no-warnings --embed-subs --sub-lang $Lang --embed-thumbnail --embed-metadata $Url
    Show-ProcessFooter -Message "Видео с субтитрами успешно скачано!"
}

# 6. Обновление
function Update-YtDlp {
    Show-ProcessHeader -Title "ОБНОВЛЕНИЕ YT-DLP"
    Write-Host "[Проверка обновлений...]`n" -ForegroundColor White
    yt-dlp -U
    Show-ProcessFooter -Message "Обновление завершено!"
}

# Главное меню
function Show-Menu {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host "     yt-dlp - Простой интерфейс" -ForegroundColor Magenta
    Write-Host "========================================`n" -ForegroundColor Magenta
    
    if (-not (Test-YtDlp)) {
        Write-Host "[ОШИБКА]: yt-dlp не найден!" -ForegroundColor Red
        Write-Host "Пожалуйста, установите yt-dlp и добавьте его в PATH." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit
    }
    
    Write-Host "1. Скачать видео (MP4+AAC, стандарт для монтажа)" -ForegroundColor Green
    Write-Host "2. Скачать плейлист/канал" -ForegroundColor White
    Write-Host "3. Скачать только аудио (MP3 / M4A)" -ForegroundColor White
    Write-Host "4. Скачать фрагмент видео (по таймкоду)" -ForegroundColor White
    Write-Host "5. Скачать видео с субтитрами" -ForegroundColor White
    Write-Host "6. Обновить yt-dlp" -ForegroundColor White
    Write-Host "0. Выход" -ForegroundColor White
    Write-Host "`n========================================" -ForegroundColor Magenta
    
    return Read-Host "Выберите действие (0-6)"
}

# Основной цикл
while ($true) {
    $choice = Show-Menu
    
    switch ($choice) {
        "1" {
            if (-not (Test-FFmpeg)) {
                Write-Host "`n[ОШИБКА]: FFmpeg не найден!" -ForegroundColor Red
                Write-Host "Для конвертации аудио в AAC необходим FFmpeg." -ForegroundColor Yellow
                $null = Read-Host "Нажмите Enter для возврата в меню"
                continue
            }
            $url = Read-Host "`nВведите ссылку на видео"
            Write-Host "`nВыберите качество:" -ForegroundColor Yellow
            Write-Host "  1 - Лучшее доступное (4K, если есть)" -ForegroundColor Gray
            Write-Host "  2 - До 1080p (рекомендуется)" -ForegroundColor Gray
            $q = Read-Host "Ваш выбор (1/2)"
            
            if ($q -eq "1") { Download-Video -Url $url -Quality "best" } 
            else { Download-Video -Url $url -Quality "1080" }
            
            $null = Read-Host "`nНажмите Enter для возврата в меню"
        }
        "2" {
            $url = Read-Host "`nВведите ссылку на плейлист/канал"
            Download-Playlist -Url $url
            $null = Read-Host "`nНажмите Enter для возврата в меню"
        }
        "3" {
            $url = Read-Host "`nВведите ссылку на видео"
            Write-Host "`nВыберите формат аудио:" -ForegroundColor Yellow
            Write-Host "  1 - MP3 (универсальный)" -ForegroundColor Gray
            Write-Host "  2 - M4A (оригинальное качество YouTube)" -ForegroundColor Gray
            $fmtChoice = Read-Host "Ваш выбор (1/2)"
            
            $format = if ($fmtChoice -eq "2") { "m4a" } else { "mp3" }
            Download-Audio -Url $url -Format $format
            $null = Read-Host "`nНажмите Enter для возврата в меню"
        }
        "4" {
            if (-not (Test-FFmpeg)) {
                Write-Host "`n[ОШИБКА]: FFmpeg не найден!" -ForegroundColor Red
                Write-Host "Для обработки фрагментов необходим FFmpeg." -ForegroundColor Yellow
                $null = Read-Host "Нажмите Enter для возврата в меню"
                continue
            }
            $url = Read-Host "`nВведите ссылку на видео"
            
            Write-Host "`nПодсказка: Можно использовать пробелы ВМЕСТО двоеточий" -ForegroundColor Yellow
            Write-Host "Примеры: '1 30', '0 20', '1 30 15' или классические '1:30', '0:20'" -ForegroundColor Gray
            
            $startTimeRaw = Read-Host "Время начала"
            $endTimeRaw = Read-Host "Время окончания"
            
            # АВТОМАТИЧЕСКАЯ ЗАМЕНА ПРОБЕЛОВ НА ДВОЕТОЧИЯ
            $startTime = $startTimeRaw.Replace(" ", ":")
            $endTime = $endTimeRaw.Replace(" ", ":")
            
            if ([string]::IsNullOrWhiteSpace($startTime) -or [string]::IsNullOrWhiteSpace($endTime)) {
                Write-Host "`n[ОШИБКА]: Время не может быть пустым!" -ForegroundColor Red
                $null = Read-Host "Нажмите Enter для возврата в меню"
                continue
            }
            
            Download-Section -Url $url -StartTime $startTime -EndTime $endTime
            $null = Read-Host "`nНажмите Enter для возврата в меню"
        }
        "5" {
            $url = Read-Host "`nВведите ссылку на видео"
            $lang = Read-Host "Введите язык субтитров (например: ru, en, ru,en)"
            Download-WithSubs -Url $url -Lang $lang
            $null = Read-Host "`nНажмите Enter для возврата в меню"
        }
        "6" {
            Update-YtDlp
            $null = Read-Host "`nНажмите Enter для возврата в меню"
        }
        "0" {
            Write-Host "`n[OK] До свидания!`n" -ForegroundColor Green
            exit
        }
        default {
            Write-Host "`n[ОШИБКА]: Неверный выбор! Попробуйте снова." -ForegroundColor Red
            Start-Sleep -Seconds 1.5
        }
    }
}