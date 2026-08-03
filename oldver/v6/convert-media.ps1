#Requires -Version 5.1
<#
.SYNOPSIS
    Простой конвертер файлов (видео и картинки) на базе FFmpeg.
.DESCRIPTION
    Файл перетаскивается в окно PowerShell. 
    Разрешение сохраняется оригинальным. Файлы сохраняются рядом с исходными.
#>

# ======================== НАСТРОЙКИ ========================
$FFmpegPath = "ffmpeg"  # Если ffmpeg не в PATH, укажите полный путь: "C:\path\to\ffmpeg.exe"

# Все поддерживаемые расширения (для автопоиска)
$AllKnownExts = @(
    '.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v', '.ts', 
    '.mpg', '.mpeg', '.3gp', '.3g2', '.vob', '.ogv', '.rm', '.rmvb', '.asf', 
    '.dv', '.mts', '.m2ts', '.f4v', '.divx', '.amv', '.mxf', '.vro', '.gxf',
    '.png', '.jpg', '.jpeg', '.jfif', '.bmp', '.tiff', '.tif', '.webp', '.gif', 
    '.heic', '.heif', '.ico', '.raw', '.cr2', '.nef', '.arw', '.dng', '.orf',
    '.svg', '.psd', '.ai', '.eps', '.jp2', '.jxr', '.pcx', '.tga', '.ppm', 
    '.pgm', '.pbm', '.pnm', '.xpm', '.xbm', '.hdr', '.exr', '.dds', '.pict', 
    '.sgi', '.sun', '.viff', '.xwd'
)

# ======================== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ========================

function Test-FFmpeg {
    try {
        $null = & $FFmpegPath -version 2>&1
        return $true
    } catch {
        return $false
    }
}

function Show-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║       FFmpeg Drag & Drop Converter      ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Get-CleanPath {
    param([string]$RawPath)
    # Убираем кавычки, лишние пробелы и точку в конце (артефакт drag-and-drop)
    $cleaned = $RawPath.Trim().Trim('"').Trim("'").TrimEnd('.')
    return $cleaned
}

function Resolve-InputPath {
    param([string]$Path)
    
    # Если файл существует как есть — возвращаем его
    if (Test-Path -LiteralPath $Path) {
        return $Path
    }
    
    # Если путь заканчивался точкой (обрезанное расширение), пробуем найти файл
    $dir = [System.IO.Path]::GetDirectoryName($Path)
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    
    if (-not $dir -or -not (Test-Path -LiteralPath $dir)) {
        return $null
    }
    
    # Ищем файлы с таким же именем и любым известным расширением
    $candidates = @()
    foreach ($ext in $AllKnownExts) {
        $candidatePath = Join-Path $dir "$baseName$ext"
        if (Test-Path -LiteralPath $candidatePath) {
            $candidates += $candidatePath
        }
    }
    
    if ($candidates.Count -eq 1) {
        Write-Host "  [i] Путь был обрезан. Найден файл: $([System.IO.Path]::GetFileName($candidates[0]))" -ForegroundColor Yellow
        return $candidates[0]
    }
    elseif ($candidates.Count -gt 1) {
        Write-Host "`n  [!] Найдено несколько файлов с именем '$baseName':" -ForegroundColor Yellow
        for ($i = 0; $i -lt $candidates.Count; $i++) {
            Write-Host "    $($i + 1)) $([System.IO.Path]::GetFileName($candidates[$i]))"
        }
        $choice = Read-Host "  Выберите номер"
        if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $candidates.Count) {
            return $candidates[[int]$choice - 1]
        }
        return $null
    }
    
    return $null
}

function Get-FileType {
    param([string]$FilePath)
    $ext = [System.IO.Path]::GetExtension($FilePath).ToLower()
    
    $videoExts = @(
        '.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v', '.ts', 
        '.mpg', '.mpeg', '.3gp', '.3g2', '.vob', '.ogv', '.rm', '.rmvb', '.asf', 
        '.dv', '.mts', '.m2ts', '.f4v', '.divx', '.amv', '.mxf', '.vro', '.gxf'
    )
    
    $imageExts = @(
        '.png', '.jpg', '.jpeg', '.jfif', '.bmp', '.tiff', '.tif', '.webp', '.gif', 
        '.heic', '.heif', '.ico', '.raw', '.cr2', '.nef', '.arw', '.dng', '.orf',
        '.svg', '.psd', '.ai', '.eps', '.jp2', '.jxr', '.pcx', '.tga', '.ppm', 
        '.pgm', '.pbm', '.pnm', '.xpm', '.xbm', '.hdr', '.exr', '.dds', '.pict', 
        '.sgi', '.sun', '.viff', '.xwd'
    )

    if ($videoExts -contains $ext) { return "Video" }
    if ($imageExts -contains $ext) { return "Image" }
    return "Unknown"
}

# ======================== ФУНКЦИИ КОНВЕРТАЦИИ ========================

function Convert-VideoFile {
    param([string]$InputFile)

    Write-Host "`n  [ ФОРМАТЫ ВИДЕО ]" -ForegroundColor Yellow
    Write-Host "  1)  MP4  (H.264 + AAC)"
    Write-Host "  2)  MKV  (H.264 + AAC)"
    Write-Host "  3)  AVI  (MPEG-4)"
    Write-Host "  4)  MOV  (H.264 + AAC)"
    Write-Host "  5)  WebM (VP9 + Opus)"
    Write-Host "  6)  WMV"
    Write-Host "  7)  GIF  (Анимация из видео)"
    Write-Host "  8)  FLV"
    Write-Host "  9)  MPEG (MPEG-2)"
    Write-Host "  10) 3GP  (для мобильных)"
    Write-Host "  11) OGV  (Theora + Vorbis)"
    Write-Host "  12) TS   (MPEG-TS)"
    Write-Host "  13) ASF"
    Write-Host "  14) DV"
    Write-Host "  15) MXF  (профессиональный)"
    Write-Host "  16) AMV"
    Write-Host ""
    
    $choice = Read-Host "  Выберите формат (1-16)"

    $formats = @{
        "1"  = @{ Ext = "mp4";  Args = @("-c:v","libx264","-crf","23","-preset","medium","-c:a","aac","-b:a","192k","-movflags","+faststart") }
        "2"  = @{ Ext = "mkv";  Args = @("-c:v","libx264","-crf","23","-preset","medium","-c:a","aac","-b:a","192k") }
        "3"  = @{ Ext = "avi";  Args = @("-c:v","mpeg4","-q:v","5","-c:a","mp3","-b:a","192k") }
        "4"  = @{ Ext = "mov";  Args = @("-c:v","libx264","-crf","23","-preset","medium","-c:a","aac","-b:a","192k") }
        "5"  = @{ Ext = "webm"; Args = @("-c:v","libvpx-vp9","-crf","30","-b:v","0","-c:a","libopus","-b:a","128k") }
        "6"  = @{ Ext = "wmv";  Args = @("-c:v","wmv2","-b:v","2M","-c:a","wmav2","-b:a","192k") }
        "7"  = @{ Ext = "gif";  Args = @("-vf","fps=15","-loop","0") }
        "8"  = @{ Ext = "flv";  Args = @("-c:v","flv","-q:v","5","-c:a","mp3","-b:a","128k") }
        "9"  = @{ Ext = "mpg";  Args = @("-c:v","mpeg2video","-b:v","5M","-c:a","mp2","-b:a","192k") }
        "10" = @{ Ext = "3gp";  Args = @("-c:v","h263","-s","qcif","-c:a","amr_nb","-ar","8000","-ac","1","-ab","12k") }
        "11" = @{ Ext = "ogv";  Args = @("-c:v","libtheora","-q:v","6","-c:a","libvorbis","-q:a","4") }
        "12" = @{ Ext = "ts";   Args = @("-c:v","libx264","-crf","23","-preset","medium","-c:a","aac","-b:a","192k","-f","mpegts") }
        "13" = @{ Ext = "asf";  Args = @("-c:v","msmpeg4v3","-b:v","2M","-c:a","wmav2","-b:a","192k") }
        "14" = @{ Ext = "dv";   Args = @("-c:v","dvvideo","-pix_fmt","yuv420p","-c:a","pcm_s16le") }
        "15" = @{ Ext = "mxf";  Args = @("-c:v","mpeg2video","-b:v","50M","-c:a","pcm_s16le","-f","mxf") }
        "16" = @{ Ext = "amv";  Args = @("-c:v","mjpeg","-q:v","5","-c:a","adpcm_ima_amv","-ar","22050") }
    }

    if (-not $formats.ContainsKey($choice)) {
        Write-Host "  Неверный выбор." -ForegroundColor Red
        return
    }

    $target = $formats[$choice]
    $dir = [System.IO.Path]::GetDirectoryName($InputFile)
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
    $outPath = Join-Path $dir "$baseName`_converted.$($target.Ext)"

    Write-Host "`n  Конвертация в .$($target.Ext) (разрешение оригинальное)..." -ForegroundColor Cyan
    
    $ffmpegArgs = @("-i", $InputFile) + $target.Args + @("-y", $outPath)

    $proc = Start-Process -FilePath $FFmpegPath -ArgumentList $ffmpegArgs -NoNewWindow -Wait -PassThru -RedirectStandardError "$env:TEMP\ffmpeg_log.txt"

    if ($proc.ExitCode -eq 0) {
        Write-Host "  Успешно! Сохранено как: $([System.IO.Path]::GetFileName($outPath))" -ForegroundColor Green
    } else {
        Write-Host "  Ошибка конвертации. Проверьте лог: $env:TEMP\ffmpeg_log.txt" -ForegroundColor Red
    }
}

function Convert-ImageFile {
    param([string]$InputFile)

    Write-Host "`n  [ ФОРМАТЫ ИЗОБРАЖЕНИЙ ]" -ForegroundColor Yellow
    Write-Host "  1)  PNG"
    Write-Host "  2)  JPEG"
    Write-Host "  3)  JFIF (JPEG File Interchange Format)"
    Write-Host "  4)  WebP"
    Write-Host "  5)  BMP"
    Write-Host "  6)  TIFF"
    Write-Host "  7)  GIF"
    Write-Host "  8)  ICO"
    Write-Host "  9)  TGA"
    Write-Host "  10) PCX"
    Write-Host "  11) PPM (Portable Pixmap)"
    Write-Host "  12) PGM (Portable Graymap)"
    Write-Host "  13) PBM (Portable Bitmap)"
    Write-Host "  14) XPM (X PixMap)"
    Write-Host "  15) XBM (X Bitmap)"
    Write-Host "  16) JPEG 2000 (JP2)"
    Write-Host "  17) HDR (Radiance RGBE)"
    Write-Host "  18) EXR (OpenEXR)"
    Write-Host "  19) DDS (DirectDraw Surface)"
    Write-Host "  20) SUN (Sun Raster)"
    Write-Host "  21) SGI (SGI Image)"
    Write-Host "  22) PICT (Mac PICT)"
    Write-Host "  23) VIFF (Khoros Visualization)"
    Write-Host "  24) XWD (X Window Dump)"
    Write-Host ""
    
    $choice = Read-Host "  Выберите формат (1-24)"

    $formats = @{
        "1"  = @{ Ext = "png";  Args = @() }
        "2"  = @{ Ext = "jpg";  Args = @("-q:v","2") }
        "3"  = @{ Ext = "jfif"; Args = @("-q:v","2") }
        "4"  = @{ Ext = "webp"; Args = @("-quality","85") }
        "5"  = @{ Ext = "bmp";  Args = @() }
        "6"  = @{ Ext = "tiff"; Args = @() }
        "7"  = @{ Ext = "gif";  Args = @() }
        "8"  = @{ Ext = "ico";  Args = @() }
        "9"  = @{ Ext = "tga";  Args = @() }
        "10" = @{ Ext = "pcx";  Args = @() }
        "11" = @{ Ext = "ppm";  Args = @() }
        "12" = @{ Ext = "pgm";  Args = @() }
        "13" = @{ Ext = "pbm";  Args = @() }
        "14" = @{ Ext = "xpm";  Args = @() }
        "15" = @{ Ext = "xbm";  Args = @() }
        "16" = @{ Ext = "jp2";  Args = @() }
        "17" = @{ Ext = "hdr";  Args = @() }
        "18" = @{ Ext = "exr";  Args = @() }
        "19" = @{ Ext = "dds";  Args = @() }
        "20" = @{ Ext = "sun";  Args = @() }
        "21" = @{ Ext = "sgi";  Args = @() }
        "22" = @{ Ext = "pct";  Args = @() }
        "23" = @{ Ext = "viff"; Args = @() }
        "24" = @{ Ext = "xwd";  Args = @() }
    }

    if (-not $formats.ContainsKey($choice)) {
        Write-Host "  Неверный выбор." -ForegroundColor Red
        return
    }

    $target = $formats[$choice]
    $dir = [System.IO.Path]::GetDirectoryName($InputFile)
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
    $outPath = Join-Path $dir "$baseName`_converted.$($target.Ext)"

    Write-Host "`n  Конвертация в .$($target.Ext) (разрешение оригинальное)..." -ForegroundColor Cyan
    
    $ffmpegArgs = @("-i", $InputFile) + $target.Args + @("-y", $outPath)

    $proc = Start-Process -FilePath $FFmpegPath -ArgumentList $ffmpegArgs -NoNewWindow -Wait -PassThru -RedirectStandardError "$env:TEMP\ffmpeg_log.txt"

    if ($proc.ExitCode -eq 0) {
        Write-Host "  Успешно! Сохранено как: $([System.IO.Path]::GetFileName($outPath))" -ForegroundColor Green
    } else {
        Write-Host "  Ошибка конвертации. Проверьте лог: $env:TEMP\ffmpeg_log.txt" -ForegroundColor Red
    }
}

# ======================== ГЛАВНЫЙ ЦИКЛ ========================

while ($true) {
    Show-Banner

    if (-not (Test-FFmpeg)) {
        Write-Host "  [!] FFmpeg не найден!" -ForegroundColor Red
        Write-Host "  Скачайте его и добавьте в PATH, или укажите путь в переменной `$FFmpegPath." -ForegroundColor Red
        Write-Host ""
    }

    Write-Host "  Перетащите файл (видео или картинку) в это окно" -ForegroundColor White
    Write-Host "  и нажмите Enter (или введите путь вручную):" -ForegroundColor Gray
    Write-Host ""
    
    $rawInput = Read-Host "  > "
    
    if ([string]::IsNullOrWhiteSpace($rawInput)) {
        continue
    }

    $cleanedPath = Get-CleanPath -RawPath $rawInput
    $inputFile = Resolve-InputPath -Path $cleanedPath

    if (-not $inputFile) {
        Write-Host "`n  [!] Файл не найден: $cleanedPath" -ForegroundColor Red
        Write-Host "  Если вы перетащили файл, попробуйте ввести путь вручную." -ForegroundColor Yellow
        Read-Host "`n  Нажмите Enter для продолжения"
        continue
    }

    $fileType = Get-FileType -FilePath $inputFile

    switch ($fileType) {
        "Video" { 
            Write-Host "`n  Обнаружен видеофайл: $([System.IO.Path]::GetFileName($inputFile))" -ForegroundColor Green
            Convert-VideoFile -InputFile $inputFile 
        }
        "Image" { 
            Write-Host "`n  Обнаружено изображение: $([System.IO.Path]::GetFileName($inputFile))" -ForegroundColor Green
            Convert-ImageFile -InputFile $inputFile 
        }
        default { 
            Write-Host "`n  [!] Неподдерживаемый формат файла: $([System.IO.Path]::GetExtension($inputFile))" -ForegroundColor Red 
        }
    }

    Write-Host ""
    Read-Host "  Нажмите Enter для возврата в главное меню"
}