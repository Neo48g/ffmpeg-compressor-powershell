param([string]$VideoFolder = "")

$scriptFolder = $PSScriptRoot; if (-not $scriptFolder) { $scriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Path }; if (-not $scriptFolder) { $scriptFolder = Get-Location }
$settingsFile = Join-Path $scriptFolder "settings.json"; $presetsFile = Join-Path $scriptFolder "presets.json"
$defaultInputFolder = Split-Path $scriptFolder -Parent; if (-not $defaultInputFolder) { $defaultInputFolder = Get-Location }
$currentLanguage = "EN"
function L($en, $ru) { if ($script:currentLanguage -eq 'RU') { return $ru } return $en }

$crfValue = 23; $enableVMAF = $true; $enableAutoCRF = $true; $vmafThreshold = 90; $maxIterations = 3; $minCRF = 18
$enableRecursiveSearch = $false; $excludedFolders = @("compressed", "scripts", "logs")
$hwDevice = "CPU"; $gpuSeries = "none"; $codec = "h264"; $qualityPreset = "balanced"
$detectedCPU = "Unknown"; $detectedCPUCores = 0; $detectedCPUThreads = 0; $detectedGPU = "Unknown"; $detectedGPUList = @(); $detectedRAM = 0
$cancelRequested = $false; $enableLogs = $true; $logsFolder = ""; $presets = @{}

# === FFMPEG CHECK & INFO ===
function Test-FFmpeg {
    try { $null = Get-Command ffmpeg -ErrorAction Stop; return $true } catch { return $false }
}
function Get-FFmpegVersion {
    try {
        $output = & ffmpeg -version 2>$null | Select-Object -First 1
        if ($output -match 'ffmpeg version ([\d\.]+)') { return $matches[1] }
        return "unknown"
    } catch { return "not installed" }
}
function Get-FFmpegVersionDisplay {
    if (Test-FFmpeg) { return "v$(Get-FFmpegVersion)" }
    else { return (L "Not installed" "Не установлен") }
}

function Show-FFmpegInfo {
    Clear-Host
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "              $(L 'FFMPEG DETAILED INFO' 'ДЕТАЛЬНАЯ ИНФОРМАЦИЯ О FFMPEG')                    " -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "$(L 'VERSION INFORMATION' 'ИНФОРМАЦИЯ О ВЕРСИИ')" -ForegroundColor Yellow
    Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
    try { Write-Host "  $(& ffmpeg -version 2>$null | Select-Object -First 1)" -ForegroundColor Green } catch {}
    Write-Host ""
    
    Write-Host "$(L 'LIBRARY VERSIONS' 'ВЕРСИИ БИБЛИОТЕК')" -ForegroundColor Yellow
    Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
    try {
        $versionFull = & ffmpeg -version 2>$null
        $libraries = @(
            @{ Name = "libavcodec"; Desc = L "Video/Audio codecs" "Видео/Аудио кодеки" }
            @{ Name = "libavformat"; Desc = L "Container formats" "Форматы контейнеров" }
            @{ Name = "libavutil"; Desc = L "Utility functions" "Вспомогательные функции" }
            @{ Name = "libswscale"; Desc = L "Image scaling" "Масштабирование изображения" }
            @{ Name = "libswresample"; Desc = L "Audio resampling" "Ресэмплинг аудио" }
            @{ Name = "libavfilter"; Desc = L "Audio/Video filters" "Аудио/Видео фильтры" }
            @{ Name = "libx264"; Desc = L "H.264 encoder" "Кодировщик H.264" }
            @{ Name = "libx265"; Desc = L "H.265/HEVC encoder" "Кодировщик H.265/HEVC" }
            @{ Name = "libsvtav1"; Desc = L "AV1 encoder (SVT)" "Кодировщик AV1 (SVT)" }
            @{ Name = "libvmaf"; Desc = L "VMAF quality metric" "Метрика качества VMAF" }
        )
        foreach ($lib in $libraries) {
            $foundLine = $versionFull | Where-Object { $_ -match $lib.Name }
            if ($foundLine) {
                if ($foundLine -match "$($lib.Name)\s+([\d\.]+)") { Write-Host "  $($lib.Name) v$($matches[1])" -NoNewline -ForegroundColor White }
                else { Write-Host "  $($lib.Name)" -NoNewline -ForegroundColor White }
                Write-Host " - $($lib.Desc)" -ForegroundColor Green
            } else {
                Write-Host "  $($lib.Name)" -NoNewline -ForegroundColor DarkGray
                Write-Host " - $($lib.Desc)" -NoNewline -ForegroundColor DarkGray
                Write-Host " $(L '(not found)' '(не найдено)')" -ForegroundColor Red
            }
            $matches.Clear()
        }
    } catch {}
    Write-Host ""
    
    Write-Host "$(L 'SUPPORTED CODECS' 'ПОДДЕРЖИВАЕМЫЕ КОДЕКИ')" -ForegroundColor Yellow
    Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
    try {
        $codecsOutput = & ffmpeg -codecs 2>$null
        $importantCodecs = @(
            @{ Name = "h264"; Desc = L "H.264 decoder/encoder" "Декодер/Кодировщик H.264" }
            @{ Name = "hevc"; Desc = L "H.265/HEVC decoder/encoder" "Декодер/Кодировщик H.265/HEVC" }
            @{ Name = "av1"; Desc = L "AV1 decoder/encoder" "Декодер/Кодировщик AV1" }
            @{ Name = "h264_nvenc"; Desc = L "NVIDIA H.264 hardware encoder" "Аппаратный кодировщик NVIDIA H.264" }
            @{ Name = "hevc_nvenc"; Desc = L "NVIDIA H.265 hardware encoder" "Аппаратный кодировщик NVIDIA H.265" }
            @{ Name = "av1_nvenc"; Desc = L "NVIDIA AV1 hardware encoder" "Аппаратный кодировщик NVIDIA AV1" }
            @{ Name = "h264_amf"; Desc = L "AMD H.264 hardware encoder" "Аппаратный кодировщик AMD H.264" }
            @{ Name = "hevc_amf"; Desc = L "AMD H.265 hardware encoder" "Аппаратный кодировщик AMD H.265" }
            @{ Name = "av1_amf"; Desc = L "AMD AV1 hardware encoder" "Аппаратный кодировщик AMD AV1" }
            @{ Name = "h264_qsv"; Desc = L "Intel H.264 hardware encoder" "Аппаратный кодировщик Intel H.264" }
            @{ Name = "hevc_qsv"; Desc = L "Intel H.265 hardware encoder" "Аппаратный кодировщик Intel H.265" }
            @{ Name = "av1_qsv"; Desc = L "Intel AV1 hardware encoder" "Аппаратный кодировщик Intel AV1" }
        )
        foreach ($codec in $importantCodecs) {
            $codecLines = $codecsOutput | Where-Object { $_ -match "\b$($codec.Name)\b" }
            if ($codecLines -and $codecLines.Count -gt 0) {
                $line = $codecLines[0]
                $canDecode = $line -match "^\s*D"; $canEncode = $line -match "E"
                $status = if ($canDecode -and $canEncode) { L "Decode+Encode" "Декодирование+Кодирование" } elseif ($canDecode) { L "Decode only" "Только декодирование" } elseif ($canEncode) { L "Encode only" "Только кодирование" } else { L "Supported" "Поддерживается" }
                Write-Host "  $($codec.Name)" -NoNewline -ForegroundColor White
                Write-Host " - $($codec.Desc)" -NoNewline -ForegroundColor Gray
                Write-Host " [$status]" -ForegroundColor Green
            } else {
                Write-Host "  $($codec.Name)" -NoNewline -ForegroundColor DarkGray
                Write-Host " - $($codec.Desc)" -NoNewline -ForegroundColor DarkGray
                Write-Host " $(L '(not supported)' '(не поддерживается)')" -ForegroundColor Red
            }
        }
    } catch {}
    Write-Host ""
    
    Write-Host "$(L 'BUILD CONFIGURATION' 'КОНФИГУРАЦИЯ СБОРКИ')" -ForegroundColor Yellow
    Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
    try {
        $buildConf = & ffmpeg -buildconf 2>$null
        $enableFlags = @()
        foreach ($line in $buildConf) { if ($line -match "--enable-(\S+)") { $enableFlags += $matches[1] } }
        $importantFlags = @(
            @{ Name = "libx264"; Desc = L "H.264 support" "Поддержка H.264" }
            @{ Name = "libx265"; Desc = L "H.265 support" "Поддержка H.265" }
            @{ Name = "libsvtav1"; Desc = L "AV1 support" "Поддержка AV1" }
            @{ Name = "libvmaf"; Desc = L "VMAF support" "Поддержка VMAF" }
            @{ Name = "nvenc"; Desc = L "NVIDIA hardware encoding" "Аппаратное кодирование NVIDIA" }
            @{ Name = "amf"; Desc = L "AMD hardware encoding" "Аппаратное кодирование AMD" }
            @{ Name = "qsv"; Desc = L "Intel hardware encoding" "Аппаратное кодирование Intel" }
        )
        foreach ($flag in $importantFlags) {
            if ($enableFlags -contains $flag.Name) {
                Write-Host "  --enable-$($flag.Name)" -NoNewline -ForegroundColor White
                Write-Host " - $($flag.Desc)" -ForegroundColor Green
            } else {
                Write-Host "  --enable-$($flag.Name)" -NoNewline -ForegroundColor DarkGray
                Write-Host " - $($flag.Desc)" -ForegroundColor Red
            }
        }
        Write-Host ""; Write-Host "$(L 'Total enabled features:' 'Всего включено функций:') $($enableFlags.Count)" -ForegroundColor Gray
    } catch {}
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "$(L 'Press any key to continue...' 'Нажмите любую клавишу для продолжения...')" -ForegroundColor Cyan
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Show-FFmpegInstallMenu {
    Clear-Host
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "              $(L 'INSTALLING FFMPEG' 'УСТАНОВКА FFMPEG')                                " -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "$(L 'FFmpeg is required for video compression.' 'FFmpeg необходим для сжатия видео.')" -ForegroundColor Yellow
    Write-Host "$(L 'Please choose an installation method:' 'Выберите способ установки:')" -ForegroundColor White
    Write-Host ""
    Write-Host "  1. $(L 'Automatic installation via script (recommended)' 'Автоматическая установка через скрипт (рекомендуется)')" -ForegroundColor Green
    Write-Host "  2. $(L 'Install via winget' 'Установить через winget')" -ForegroundColor Cyan
    Write-Host "  3. $(L 'Install via Chocolatey' 'Установить через Chocolatey')" -ForegroundColor White
    Write-Host "  4. $(L 'Open official download page' 'Открыть официальную страницу загрузки')" -ForegroundColor White
    Write-Host "  5. $(L 'Return to main menu' 'Вернуться в главное меню')" -ForegroundColor Red
    Write-Host ""
    
    $choice = Read-Host (L "Enter your choice (1-5)" "Введите ваш выбор (1-5)")
    
    switch ($choice) {
        '1' { 
            $installScript = Join-Path $scriptFolder "install_ffmpeg.ps1"
            if (-not (Test-Path $installScript)) {
                Write-Host "`n$(L 'ERROR: install_ffmpeg.ps1 not found!' 'ОШИБКА: install_ffmpeg.ps1 не найден!')" -ForegroundColor Red
            } else {
                Write-Host "`n$(L 'Launching installation script...' 'Запуск скрипта установки...')" -ForegroundColor Cyan
                $process = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$installScript`"" -Wait -PassThru
                if ($process.ExitCode -eq 0) {
                    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
                    if (Test-FFmpeg) { Write-Host "`n$(L 'FFmpeg installed successfully!' 'FFmpeg успешно установлен!')" -ForegroundColor Green }
                    else { Write-Host "`n$(L 'Please restart the program.' 'Перезапустите программу.')" -ForegroundColor Yellow }
                } else {
                    Write-Host "`n$(L 'Installation failed or was cancelled.' 'Установка не удалась или была отменена.')" -ForegroundColor Red
                }
            }
            Write-Host "`n$(L 'Press any key to continue...' 'Нажмите любую клавишу для продолжения...')"
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        '2' {
            try {
                $null = Get-Command winget -ErrorAction Stop
                Write-Host "`n$(L 'Installing via winget...' 'Установка через winget...')" -ForegroundColor Cyan
                winget install --id Gyan.FFmpeg -e --accept-source-agreements --accept-package-agreements
                if ($LASTEXITCODE -eq 0) { Write-Host "`n$(L 'Success! Please restart the program.' 'Успех! Перезапустите программу.')" -ForegroundColor Green }
                else { Write-Host "`n$(L 'Installation failed.' 'Установка не удалась.')" -ForegroundColor Red }
            } catch { Write-Host "`n$(L 'winget is not available.' 'winget недоступен.')" -ForegroundColor Red }
            Write-Host "`n$(L 'Press any key to continue...' 'Нажмите любую клавишу для продолжения...')"
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        '3' {
            try {
                $null = Get-Command choco -ErrorAction Stop
                Write-Host "`n$(L 'Installing via Chocolatey...' 'Установка через Chocolatey...')" -ForegroundColor Cyan
                choco install ffmpeg -y
                if ($LASTEXITCODE -eq 0) { Write-Host "`n$(L 'Success! Please restart the program.' 'Успех! Перезапустите программу.')" -ForegroundColor Green }
                else { Write-Host "`n$(L 'Installation failed.' 'Установка не удалась.')" -ForegroundColor Red }
            } catch { Write-Host "`n$(L 'Chocolatey is not installed.' 'Chocolatey не установлен.')" -ForegroundColor Red }
            Write-Host "`n$(L 'Press any key to continue...' 'Нажмите любую клавишу для продолжения...')"
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        '4' {
            Start-Process "https://www.gyan.dev/ffmpeg/builds/"
            Write-Host "`n$(L 'Download ffmpeg-release-essentials.zip, extract, and add bin to PATH.' 'Скачайте ffmpeg-release-essentials.zip, распакуйте и добавьте bin в PATH.')" -ForegroundColor Yellow
            Write-Host "`n$(L 'Press any key to continue...' 'Нажмите любую клавишу для продолжения...')"
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        '5' { return }
        default {
            Write-Host "`n$(L 'Invalid choice.' 'Неверный выбор.')" -ForegroundColor Red
            Write-Host "`n$(L 'Press any key to continue...' 'Нажмите любую клавишу для продолжения...')"
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
    }
}

# === НОВАЯ ОБЪЕДИНЕННАЯ ФУНКЦИЯ ===
function Show-FFmpegMenu {
    Clear-Host
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "              $(L 'FFMPEG STATUS & MANAGEMENT' 'СТАТУС И УПРАВЛЕНИЕ FFMPEG')             " -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Test-FFmpeg)) {
        Write-Host "$(L 'FFmpeg is NOT installed or not found in PATH.' 'FFmpeg НЕ установлен или не найден в PATH.')" -ForegroundColor Red
        Write-Host ""
        Write-Host "$(L 'Would you like to install it now?' 'Хотите установить его сейчас?')" -ForegroundColor Yellow
        Write-Host "  1. $(L 'Yes, show installation options' 'Да, показать варианты установки')" -ForegroundColor Green
        Write-Host "  2. $(L 'No, return to main menu' 'Нет, вернуться в главное меню')" -ForegroundColor Gray
        Write-Host ""
        $choice = Read-Host (L "Enter your choice (1-2)" "Введите ваш выбор (1-2)")
        if ($choice -eq '1') { Show-FFmpegInstallMenu }
    } else {
        $version = Get-FFmpegVersion
        Write-Host "$(L 'FFmpeg is installed:' 'FFmpeg установлен:') v$version" -ForegroundColor Green
        Write-Host ""
        Write-Host "$(L 'Choose an action:' 'Выберите действие:')" -ForegroundColor Yellow
        Write-Host "  1. $(L 'View detailed info (libraries, codecs, filters)' 'Посмотреть детальную информацию (библиотеки, кодеки, фильтры)')" -ForegroundColor Cyan
        Write-Host "  2. $(L 'Reinstall / Update FFmpeg' 'Переустановить / Обновить FFmpeg')" -ForegroundColor White
        Write-Host "  3. $(L 'Return to main menu' 'Вернуться в главное меню')" -ForegroundColor Gray
        Write-Host ""
        $choice = Read-Host (L "Enter your choice (1-3)" "Введите ваш выбор (1-3)")

        switch ($choice) {
            '1' { Show-FFmpegInfo }
            '2' { Show-FFmpegInstallMenu }
            '3' { return }
            default {
                Write-Host "`n$(L 'Invalid choice.' 'Неверный выбор.')" -ForegroundColor Red
                Write-Host "`n$(L 'Press any key to continue...' 'Нажмите любую клавишу для продолжения...')"
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
        }
    }
}

# === SETTINGS & PRESETS ===
function Load-Settings {
    if (Test-Path $settingsFile) {
        try {
            $saved = Get-Content $settingsFile -Raw | ConvertFrom-Json
            Write-Host (L "Loading settings from:" "Загрузка настроек из:") $settingsFile -ForegroundColor Gray
            if ($saved.InputFolder) { $script:inputFolder = $saved.InputFolder } else { $script:inputFolder = $defaultInputFolder }
            if ($null -ne $saved.CRFValue) { $script:crfValue = [int]$saved.CRFValue }
            if ($null -ne $saved.EnableVMAF) { $script:enableVMAF = [bool]$saved.EnableVMAF }
            if ($null -ne $saved.EnableAutoCRF) { $script:enableAutoCRF = [bool]$saved.EnableAutoCRF }
            if ($null -ne $saved.VMAFThreshold) { $script:vmafThreshold = [int]$saved.VMAFThreshold }
            if ($null -ne $saved.MaxIterations) { $script:maxIterations = [int]$saved.MaxIterations }
            if ($null -ne $saved.MinCRF) { $script:minCRF = [int]$saved.MinCRF }
            if ($null -ne $saved.EnableRecursiveSearch) { $script:enableRecursiveSearch = [bool]$saved.EnableRecursiveSearch }
            if ($saved.HwDevice) { $script:hwDevice = $saved.HwDevice }
            if ($saved.GpuSeries) { $script:gpuSeries = $saved.GpuSeries }
            if ($saved.Codec) { $script:codec = $saved.Codec }
            if ($saved.QualityPreset) { $script:qualityPreset = $saved.QualityPreset }
            if ($null -ne $saved.EnableLogs) { $script:enableLogs = [bool]$saved.EnableLogs }
            if ($saved.Language) { $script:currentLanguage = $saved.Language }
            Write-Host (L "Settings loaded successfully!" "Настройки успешно загружены!") -ForegroundColor Green
        } catch {
            Write-Host (L "Failed to load settings:" "Ошибка загрузки:") $_.Exception.Message -ForegroundColor Red
            $script:inputFolder = $defaultInputFolder
        }
    } else {
        Write-Host (L "No saved settings found. Using defaults." "Настройки не найдены. Используются значения по умолчанию.") -ForegroundColor Yellow
        $script:inputFolder = $defaultInputFolder
    }
}

function Save-Settings {
    try {
        $settings = @{
            InputFolder = $inputFolder; CRFValue = $crfValue; EnableVMAF = $enableVMAF; EnableAutoCRF = $enableAutoCRF
            VMAFThreshold = $vmafThreshold; MaxIterations = $maxIterations; MinCRF = $minCRF; EnableRecursiveSearch = $enableRecursiveSearch
            HwDevice = $hwDevice; GpuSeries = $gpuSeries; Codec = $codec; QualityPreset = $qualityPreset; EnableLogs = $enableLogs; Language = $currentLanguage
        }
        $settings | ConvertTo-Json | Out-File -FilePath $settingsFile -Encoding UTF8 -Force
        Write-Host (L "Settings saved to:" "Настройки сохранены в:") $settingsFile -ForegroundColor Green
    } catch { Write-Host (L "Failed to save settings" "Ошибка сохранения") -ForegroundColor Red }
}

function Change-Language {
    if ($currentLanguage -eq "EN") { $script:currentLanguage = "RU" } else { $script:currentLanguage = "EN" }
    Write-Host (L "Language changed to English" "Язык изменен на Русский") -ForegroundColor Green
    Write-Host "`n$(L 'Press any key to continue...' 'Нажмите любую клавишу...')"
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Load-Presets {
    if (Test-Path $presetsFile) {
        try {
            $jsonData = Get-Content $presetsFile -Raw | ConvertFrom-Json
            $script:presets = @{}
            foreach ($property in $jsonData.PSObject.Properties) { $script:presets[$property.Name] = $property.Value }
            Write-Host (L "Loaded presets:" "Загружено пресетов:") $presets.Count -ForegroundColor Gray
        } catch { Write-Host (L "Failed to load presets" "Ошибка загрузки пресетов") -ForegroundColor Red; $script:presets = @{} }
    } else { Write-Host (L "No saved presets found." "Сохраненные пресеты не найдены.") -ForegroundColor Yellow; $script:presets = @{} }
}

function Save-Presets {
    try { $script:presets | ConvertTo-Json -Depth 10 | Out-File -FilePath $presetsFile -Encoding UTF8 -Force }
    catch { Write-Host (L "Failed to save presets" "Ошибка сохранения пресетов") -ForegroundColor Red }
}

function Save-CurrentPreset {
    Clear-Host; Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "              $(L 'SAVE CURRENT SETTINGS AS PRESET' 'СОХРАНИТЬ ТЕКУЩИЕ НАСТРОЙКИ КАК ПРЕСЕТ')               " -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan; Write-Host ""
    Write-Host (L "Enter preset name (or 'b' to cancel): " "Введите имя пресета (или 'b' для отмены): ") -NoNewline -ForegroundColor Cyan
    $presetName = Read-Host
    if ($presetName -eq 'b' -or $presetName -eq 'B' -or [string]::IsNullOrWhiteSpace($presetName)) { return }
    if ($presets.ContainsKey($presetName)) {
        Write-Host (L "Preset exists. Overwrite? (Y/N): " "Пресет существует. Перезаписать? (Y/N): ") -NoNewline -ForegroundColor Yellow
        if ((Read-Host) -ne 'Y') { return }
    }
    $script:presets[$presetName] = @{ HwDevice=$hwDevice; GpuSeries=$gpuSeries; Codec=$codec; QualityPreset=$qualityPreset; CRFValue=$crfValue; EnableVMAF=$enableVMAF; EnableAutoCRF=$enableAutoCRF; VMAFThreshold=$vmafThreshold; MaxIterations=$maxIterations; MinCRF=$minCRF; CreatedAt=(Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
    Save-Presets; Write-Host (L "Preset saved!" "Пресет сохранен!") -ForegroundColor Green
    Write-Host "`n$(L 'Press any key...' 'Нажмите любую клавишу...')"; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Load-Preset {
    Clear-Host; Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "              $(L 'LOAD PRESET' 'ЗАГРУЗИТЬ ПРЕСЕТ')                                       " -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan; Write-Host ""
    if ($presets.Count -eq 0) { Write-Host (L "No presets saved yet." "Пресеты не сохранены.") -ForegroundColor Yellow; Write-Host "`n$(L 'Press any key...' 'Нажмите любую клавишу...')"; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown"); return }
    Write-Host (L "Available presets:" "Доступные пресеты:") -ForegroundColor Yellow; $i = 1; $presetNames = @()
    foreach ($pn in $presets.Keys | Sort-Object) { $presetNames += $pn; $p = $presets[$pn]; Write-Host "  $i. $pn ($($p.HwDevice) | $($p.Codec) | Q:$($p.CRFValue))" -ForegroundColor White; $i++ }
    Write-Host (L "Enter preset number: " "Введите номер пресета: ") -NoNewline -ForegroundColor Cyan; $choice = Read-Host
    if ($choice -match '^\d+$') {
        $idx = [int]$choice - 1
        if ($idx -ge 0 -and $idx -lt $presetNames.Count) {
            $sp = $presetNames[$idx]; $p = $presets[$sp]
            $script:hwDevice=$p.HwDevice; $script:gpuSeries=$p.GpuSeries; $script:codec=$p.Codec; $script:qualityPreset=$p.QualityPreset
            $script:crfValue=[int]$p.CRFValue; $script:enableVMAF=[bool]$p.EnableVMAF; $script:enableAutoCRF=[bool]$p.EnableAutoCRF; $script:vmafThreshold=[int]$p.VMAFThreshold; $script:maxIterations=[int]$p.MaxIterations; $script:minCRF=[int]$p.MinCRF
            Write-Host (L "Preset loaded!" "Пресет загружен!") -ForegroundColor Green
        }
    }
    Write-Host "`n$(L 'Press any key...' 'Нажмите любую клавишу...')"; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Delete-Preset {
    Clear-Host; Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "              $(L 'DELETE PRESET' 'УДАЛИТЬ ПРЕСЕТ')                                     " -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan; Write-Host ""
    if ($presets.Count -eq 0) { Write-Host (L "No presets to delete." "Нет пресетов для удаления.") -ForegroundColor Yellow; Write-Host "`n$(L 'Press any key...' 'Нажмите любую клавишу...')"; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown"); return }
    Write-Host (L "Available presets:" "Доступные пресеты:") -ForegroundColor Yellow; $i = 1; $presetNames = @()
    foreach ($pn in $presets.Keys | Sort-Object) { $presetNames += $pn; Write-Host "  $i. $pn" -ForegroundColor White; $i++ }
    Write-Host (L "Enter number to delete: " "Введите номер для удаления: ") -NoNewline -ForegroundColor Cyan; $choice = Read-Host
    if ($choice -match '^\d+$') {
        $idx = [int]$choice - 1
        if ($idx -ge 0 -and $idx -lt $presetNames.Count) {
            $sp = $presetNames[$idx]; Write-Host (L "Delete? (Y/N): " "Удалить? (Y/N): ") -NoNewline -ForegroundColor Yellow
            if ((Read-Host) -eq 'Y') { $script:presets.Remove($sp); Save-Presets; Write-Host (L "Deleted." "Удалено.") -ForegroundColor Green }
        }
    }
    Write-Host "`n$(L 'Press any key...' 'Нажмите любую клавишу...')"; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Show-PresetsMenu {
    do { Clear-Host; Write-Host "================================================================" -ForegroundColor Cyan
        Write-Host "              $(L 'PRESETS MANAGEMENT' 'УПРАВЛЕНИЕ ПРЕСЕТАМИ')                              " -ForegroundColor Cyan
        Write-Host "================================================================" -ForegroundColor Cyan; Write-Host ""
        Write-Host "  1. $(L 'Save current as preset' 'Сохранить текущие как пресет')" -ForegroundColor Green
        Write-Host "  2. $(L 'Load preset' 'Загрузить пресет')" -ForegroundColor Cyan
        Write-Host "  3. $(L 'Delete preset' 'Удалить пресет')" -ForegroundColor Red
        Write-Host "  4. $(L 'Back to main menu' 'Вернуться в главное меню')" -ForegroundColor Yellow; Write-Host ""
        $choice = Read-Host (L "Enter choice (1-4)" "Введите выбор (1-4)")
        switch ($choice) { '1' { Save-CurrentPreset } '2' { Load-Preset } '3' { Delete-Preset } '4' { return } default { Write-Host "`n$(L 'Invalid choice.' 'Неверный выбор.')" -ForegroundColor Red; Write-Host (L 'Press any key...' 'Нажмите любую клавишу...'); $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } }
    } while ($true)
}

# === HELP ===
function Show-Help {
    Clear-Host; Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "              $(L 'HELP & GUIDE' 'СПРАВКА И РУКОВОДСТВО')                              " -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan; Write-Host ""
    Write-Host "$(L 'BASIC SETTINGS' 'ОСНОВНЫЕ НАСТРОЙКИ')" -ForegroundColor Yellow; Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "$(L 'Quality (CRF/CQ):' 'Качество (CRF/CQ):')" -ForegroundColor White
    Write-Host "  $(L 'Controls the balance between file size and video quality.' 'Управляет балансом между размером файла и качеством видео.')" -ForegroundColor Gray
    Write-Host "  $(L 'Lower values = better quality, larger files.' 'Меньшие значения = лучшее качество, большие файлы.')" -ForegroundColor Gray
    Write-Host "  $(L 'Recommended: 18-20 for lossless, 23 for balanced, 28-30 for smaller files.' 'Рекомендуется: 18-20 для без потерь, 23 для баланса, 28-30 для меньших файлов.')" -ForegroundColor Gray
    Write-Host ""
    Write-Host "$(L 'HARDWARE ACCELERATION' 'АППАРАТНОЕ УСКОРЕНИЕ')" -ForegroundColor Yellow; Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "$(L 'CPU (Software Encoding):' 'CPU (программное кодирование):')" -ForegroundColor White
    Write-Host "  $(L 'Uses your processor. Slowest but best quality and compatibility.' 'Использует процессор. Медленнее всего, но лучшее качество и совместимость.')" -ForegroundColor Gray
    Write-Host "$(L 'GPU (Hardware Encoding):' 'GPU (аппаратное кодирование):')" -ForegroundColor White
    Write-Host "  $(L 'Uses your graphics card. 5-20x faster than CPU with good quality.' 'Использует видеокарту. В 5-20 раз быстрее CPU с хорошим качеством.')" -ForegroundColor Gray
    Write-Host ""
    Write-Host "$(L 'CODECS' 'КОДЕКИ')" -ForegroundColor Yellow; Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "  $(L 'H.264: Most compatible. Works everywhere.' 'H.264: Самый совместимый. Работает везде.')" -ForegroundColor Gray
    Write-Host "  $(L 'H.265: 30-50% smaller files than H.264 at same quality.' 'H.265: На 30-50% меньшие файлы, чем H.264 при том же качестве.')" -ForegroundColor Gray
    Write-Host "  $(L 'AV1: Newest codec. 50% smaller than H.264. Best compression!' 'AV1: Новейший кодек. На 50% меньше, чем H.264. Лучшее сжатие!')" -ForegroundColor Gray
    Write-Host ""
    Write-Host "$(L 'VMAF & AUTO CRF' 'VMAF И АВТО CRF')" -ForegroundColor Yellow; Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "  $(L 'VMAF measures perceived video quality (0-100 scale). 90+ is excellent.' 'VMAF измеряет воспринимаемое качество видео (шкала 0-100). 90+ это отлично.')" -ForegroundColor Gray
    Write-Host "  $(L 'Auto CRF automatically improves quality if VMAF score is below threshold.' 'Авто CRF автоматически улучшает качество, если оценка VMAF ниже порога.')" -ForegroundColor Gray
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "$(L 'Press any key to return to main menu...' 'Нажмите любую клавишу для возврата в главное меню...')" -ForegroundColor Cyan
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# === UTILS ===
function Format-FileSize {
    param ([long]$size)
    if ($size -ge 1GB) { return (L ("{0:N2} GB" -f ($size / 1GB)) ("{0:N2} ГБ" -f ($size / 1GB))) }
    if ($size -ge 1MB) { return (L ("{0:N2} MB" -f ($size / 1MB)) ("{0:N2} МБ" -f ($size / 1MB))) }
    if ($size -ge 1KB) { return (L ("{0:N2} KB" -f ($size / 1KB)) ("{0:N2} КБ" -f ($size / 1KB))) }
    return (L "$size Bytes" "$size байт")
}

function Save-Log { param([string]$SourceLog,[string]$VideoBaseName,[string]$LogType,[int]$Iteration)
    if (-not $enableLogs -or -not (Test-Path $SourceLog)) { return }
    try {
        if (-not (Test-Path $logsFolder)) { New-Item -ItemType Directory -Path $logsFolder | Out-Null }
        $destPath = Join-Path $logsFolder "${VideoBaseName}_${LogType}_iter${Iteration}.log"
        Copy-Item -Path $SourceLog -Destination $destPath -Force
        Write-Host (L "  -> Log saved:" "  -> Лог сохранен:") (Split-Path $destPath -Leaf) -ForegroundColor DarkGray
    } catch { Write-Host (L "  -> Failed to save log" "  -> Ошибка сохранения лога") -ForegroundColor Red }
}

function Clear-Logs {
    Clear-Host; Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "              $(L 'CLEAR LOGS' 'ОЧИСТКА ЛОГОВ')                                        " -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan; Write-Host ""
    if (-not (Test-Path $logsFolder)) { Write-Host (L "Logs folder does not exist." "Папка логов не существует.") -ForegroundColor Yellow; Write-Host "`n$(L 'Press any key...' 'Нажмите любую клавишу...')"; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown"); return }
    $logFiles = Get-ChildItem -Path $logsFolder -File -ErrorAction SilentlyContinue; $totalSize = ($logFiles | Measure-Object -Property Length -Sum).Sum
    Write-Host (L "Total size:" "Общий размер:") (Format-FileSize $totalSize) -ForegroundColor White
    if ($logFiles.Count -eq 0) { Write-Host (L "No logs to delete." "Нет логов для удаления.") -ForegroundColor Yellow }
    else {
        Write-Host (L "Delete ALL logs? Type 'YES':" "Удалить ВСЕ логи? Введите 'YES':") -ForegroundColor Yellow
        if ((Read-Host) -eq 'YES') { Remove-Item -Path "$logsFolder\*" -Force -Recurse; Write-Host (L "Logs deleted!" "Логи удалены!") -ForegroundColor Green }
        else { Write-Host (L "Cancelled." "Отменено.") -ForegroundColor Yellow }
    }
    Write-Host "`n$(L 'Press any key...' 'Нажмите любую клавишу...')"; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Open-LogsFolder {
    if (-not (Test-Path $logsFolder)) { New-Item -ItemType Directory -Path $logsFolder | Out-Null }
    Start-Process "explorer.exe" -ArgumentList $logsFolder
    Write-Host (L "Opened logs folder." "Папка логов открыта.") -ForegroundColor Green
    Write-Host "`n$(L 'Press any key...' 'Нажмите любую клавишу...')"; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Toggle-Logs {
    $script:enableLogs = -not $script:enableLogs
    Write-Host (L "Log saving:" "Сохранение логов:") $(if ($enableLogs) { L "ENABLED" "ВКЛЮЧЕНО" } else { L "DISABLED" "ВЫКЛЮЧЕНО" }) -ForegroundColor $(if ($enableLogs) { "Green" } else { "Yellow" })
    Write-Host "`n$(L 'Press any key...' 'Нажмите любую клавишу...')"; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Show-LogsMenu {
    do { Clear-Host; Write-Host "================================================================" -ForegroundColor Cyan
        Write-Host "              $(L 'LOGS MANAGEMENT' 'УПРАВЛЕНИЕ ЛОГАМИ')                                " -ForegroundColor Cyan
        Write-Host "================================================================" -ForegroundColor Cyan; Write-Host ""
        Write-Host "  1. $(L 'Open logs folder' 'Открыть папку логов')" -ForegroundColor White
        Write-Host "  2. $(L 'Clear all logs' 'Очистить все логи')" -ForegroundColor Red
        Write-Host "  3. $(L 'Toggle log saving' 'Переключить сохранение логов')" -ForegroundColor White
        Write-Host "  4. $(L 'Back to main menu' 'Вернуться в главное меню')" -ForegroundColor Yellow; Write-Host ""
        $choice = Read-Host (L "Enter choice (1-4)" "Введите выбор (1-4)")
        switch ($choice) { '1' { Open-LogsFolder } '2' { Clear-Logs } '3' { Toggle-Logs } '4' { return } default { Write-Host "`n$(L 'Invalid choice.' 'Неверный выбор.')" -ForegroundColor Red; Write-Host (L 'Press any key...' 'Нажмите любую клавишу...'); $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } }
    } while ($true)
}

# === HARDWARE ===
function Detect-Hardware {
    Write-Host (L "Detecting hardware..." "Определение оборудования...") -ForegroundColor Cyan
    try { $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1; $script:detectedCPU = $cpu.Name.Trim(); $script:detectedCPUCores = $cpu.NumberOfCores; $script:detectedCPUThreads = $cpu.NumberOfLogicalProcessors; Write-Host "  CPU: $detectedCPU ($detectedCPUCores $(L 'cores' 'ядер') / $detectedCPUThreads $(L 'threads' 'потоков'))" -ForegroundColor Green } catch { Write-Host "  CPU: $(L 'Failed' 'Ошибка')" -ForegroundColor Red }
    try { $ram = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop).TotalPhysicalMemory; $script:detectedRAM = [math]::Round($ram / 1GB, 1); Write-Host "  RAM: $detectedRAM $(L 'GB' 'ГБ')" -ForegroundColor Green } catch { Write-Host "  RAM: $(L 'Failed' 'Ошибка')" -ForegroundColor Red }
    try {
        $allGPUs = Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop; $script:detectedGPUList = @($allGPUs | ForEach-Object { $_.Name.Trim() })
        Write-Host "  $(L 'Found' 'Найдено') $($detectedGPUList.Count) GPU(s):" -ForegroundColor Green; $i=1; foreach ($g in $detectedGPUList) { Write-Host "    $i. $g" -ForegroundColor White; $i++ }
        $script:detectedGPU = Select-BestGPU; Write-Host "  $(L 'Selected GPU:' 'Выбранное GPU:') $detectedGPU" -ForegroundColor Cyan
    } catch { Write-Host "  GPU: $(L 'Failed' 'Ошибка')" -ForegroundColor Red }
}

function Select-BestGPU {
    if ($detectedGPUList.Count -eq 0) { return "Unknown" }; if ($detectedGPUList.Count -eq 1) { return $detectedGPUList[0] }
    $gpuScores = @(); foreach ($gpu in $detectedGPUList) {
        $gl = $gpu.ToLower(); $score = 0
        if ($gl -match "nvidia|geforce|rtx|gtx") { if ($gl -match "rtx 50|rtx 40") { $score = 100 } elseif ($gl -match "rtx 30") { $score = 90 } elseif ($gl -match "rtx 20|gtx 16") { $score = 80 } elseif ($gl -match "gtx 10") { $score = 70 } else { $score = 60 } }
        elseif ($gl -match "amd|radeon") { if ($gl -match "rx 7|rx 9") { $score = 95 } elseif ($gl -match "rx 6") { $score = 85 } elseif ($gl -match "rx 5") { $score = 75 } else { $score = 65 } }
        elseif ($gl -match "intel") { if ($gl -match "arc") { $score = 88 } elseif ($gl -match "iris xe|uhd 7|uhd 6") { $score = 40 } else { $score = 30 } }
        else { $score = 50 }
        $gpuScores += @{ Name = $gpu; Score = $score }
    }; return ($gpuScores | Sort-Object { $_.Score } -Descending | Select-Object -First 1).Name
}

function Analyze-GPU {
    $gl = $detectedGPU.ToLower()
    if ($gl -match "nvidia|geforce|rtx|gtx|quadro") { if ($gl -match "rtx 50|rtx 40") { return @{ Device="NVIDIA"; Series="nvidia_ada"; HasAV1=$true } } elseif ($gl -match "rtx 30") { return @{ Device="NVIDIA"; Series="nvidia_ampere"; HasAV1=$false } } elseif ($gl -match "rtx 20|gtx 16") { return @{ Device="NVIDIA"; Series="nvidia_turing"; HasAV1=$false } } elseif ($gl -match "gtx 10|gtx 9") { return @{ Device="NVIDIA"; Series="nvidia_pascal"; HasAV1=$false } } else { return @{ Device="NVIDIA"; Series="nvidia_old"; HasAV1=$false } } }
    if ($gl -match "amd|radeon") { if ($gl -match "rx 7|rx 9") { return @{ Device="AMD"; Series="amd_rdna3"; HasAV1=$true } } elseif ($gl -match "rx 6") { return @{ Device="AMD"; Series="amd_rdna2"; HasAV1=$false } } elseif ($gl -match "rx 5") { return @{ Device="AMD"; Series="amd_rdna1"; HasAV1=$false } } else { return @{ Device="AMD"; Series="amd_old"; HasAV1=$false } } }
    if ($gl -match "intel") { if ($gl -match "arc") { return @{ Device="Intel"; Series="intel_arc"; HasAV1=$true } } elseif ($gl -match "iris xe|uhd 7|uhd 6") { return @{ Device="Intel"; Series="intel_11gen"; HasAV1=$false } } else { return @{ Device="Intel"; Series="intel_old"; HasAV1=$false } } }
    return @{ Device="Unknown"; Series="unknown"; HasAV1=$false }
}

function Apply-OptimalSettings {
    Clear-Host; Write-Host "================================================================" -ForegroundColor Cyan; Write-Host "              $(L 'AUTO-DETECTING HARDWARE' 'АВТООПРЕДЕЛЕНИЕ ОБОРУДОВАНИЯ')           " -ForegroundColor Cyan; Write-Host "================================================================" -ForegroundColor Cyan; Write-Host ""
    Detect-Hardware; Write-Host ""; $gpuInfo = Analyze-GPU; Write-Host (L "Analyzing optimal settings..." "Анализ оптимальных настроек...") -ForegroundColor Yellow; Write-Host ""
    $useGPU = $false; $reason = ""
    if ($gpuInfo.Device -ne "Unknown" -and $gpuInfo.Series -notmatch "old|pascal") {
        $useGPU = $true
        if ($detectedCPUCores -ge 8 -and $gpuInfo.Series -match "turing|rdna1|intel_11gen") { $useGPU = $false; $reason = L "Powerful CPU detected. CPU encoding gives better quality." "Обнаружен мощный CPU. Кодирование на CPU даст лучшее качество." }
        else { $reason = L "Modern GPU detected. GPU encoding is 5-20x faster." "Обнаружено современное GPU. Кодирование на GPU в 5-20 раз быстрее." }
    } else { $reason = L "No modern GPU. Using CPU." "Нет современного GPU. Используется CPU." }
    
    $recDevice=""; $recSeries=""; $recCodec=""; $recCRF=0; $recPreset=""
    if ($useGPU) {
        $recDevice=$gpuInfo.Device; $recSeries=$gpuInfo.Series
        if ($gpuInfo.HasAV1) { $recCodec="av1"; $recCRF=28; Write-Host (L "Recommended: GPU + AV1" "Рекомендуется: GPU + AV1") -ForegroundColor Green }
        else { $recCodec="h265"; $recCRF=24; Write-Host (L "Recommended: GPU + H.265" "Рекомендуется: GPU + H.265") -ForegroundColor Green }
        $recPreset="balanced"
    } else {
        $recDevice="CPU"; $recSeries="none"
        if ($detectedCPUCores -ge 8 -and $detectedRAM -ge 16) { $recCodec="av1"; $recCRF=28; $recPreset="quality"; Write-Host (L "Recommended: CPU + AV1" "Рекомендуется: CPU + AV1") -ForegroundColor Green }
        else { $recCodec="h265"; $recCRF=23; $recPreset="balanced"; Write-Host (L "Recommended: CPU + H.265" "Рекомендуется: CPU + H.265") -ForegroundColor Green }
    }
    Write-Host "`n$(L 'Reason:' 'Причина:') $reason" -ForegroundColor Gray
    Write-Host "`n$(L 'Apply recommended settings? (Y/N)' 'Применить рекомендуемые настройки? (Y/N)'): " -NoNewline -ForegroundColor Cyan
    if ((Read-Host) -eq 'Y') {
        $script:hwDevice=$recDevice; $script:gpuSeries=$recSeries; $script:codec=$recCodec; $script:crfValue=$recCRF; $script:qualityPreset=$recPreset
        Write-Host (L "Settings applied!" "Настройки применены!") -ForegroundColor Green
    } else { Write-Host (L "Settings not changed." "Настройки не изменены.") -ForegroundColor Yellow }
    Write-Host "`n$(L 'Press any key...' 'Нажмите любую клавишу...')"; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Get-SupportedCodecs { switch ($gpuSeries) { "nvidia_turing" { return @("h264","h265") } "nvidia_ampere" { return @("h264","h265") } "nvidia_ada" { return @("h264","h265","av1") } "amd_rdna1" { return @("h264","h265") } "amd_rdna2" { return @("h264","h265") } "amd_rdna3" { return @("h264","h265","av1") } "intel_11gen" { return @("h264","h265") } "intel_arc" { return @("h264","h265","av1") } default { return @("h264","h265","av1") } } }

function Get-HardwareDescription {
    $dd = switch ($hwDevice) { "CPU" { L "CPU (Software)" "CPU (программное)" } "NVIDIA" { L "NVIDIA GPU" "GPU NVIDIA" } "AMD" { L "AMD GPU" "GPU AMD" } "Intel" { L "Intel GPU" "GPU Intel" } }
    $sd = switch ($gpuSeries) { "none" { "" } "nvidia_turing" { "Turing" } "nvidia_ampere" { "Ampere" } "nvidia_ada" { "Ada/Blackwell" } "amd_rdna1" { "RDNA 1" } "amd_rdna2" { "RDNA 2" } "amd_rdna3" { "RDNA 3" } "intel_11gen" { "11th Gen+" } "intel_arc" { "Arc" } }
    $cd = switch ($codec) { "h264" { "H.264" } "h265" { "H.265" } "av1" { "AV1" } }
    $pd = switch ($qualityPreset) { "fast" { L "Fast" "Быстро" } "balanced" { L "Balanced" "Баланс" } "quality" { L "Quality" "Качество" } "max" { L "Max" "Макс" } }
    if ($hwDevice -eq "CPU") { return "$dd | $cd | $pd" } else { return "$dd ($sd) | $cd | $pd" }
}

function Build-VideoArgs { param([int]$quality)
    if ($hwDevice -eq "CPU") { $e = switch ($codec) { "h264" { "libx264" } "h265" { "libx265" } "av1" { "libsvtav1" } }; $p = switch ($qualityPreset) { "fast" { if ($codec -eq "av1") { "8" } else { "veryfast" } } "balanced" { if ($codec -eq "av1") { "6" } else { "medium" } } "quality" { if ($codec -eq "av1") { "4" } else { "slow" } } "max" { if ($codec -eq "av1") { "2" } else { "veryslow" } } }; return "-c:v $e -crf $quality -preset $p" }
    if ($hwDevice -eq "NVIDIA") { $e = switch ($codec) { "h264" { "h264_nvenc" } "h265" { "hevc_nvenc" } "av1" { "av1_nvenc" } }; $p = switch ($qualityPreset) { "fast" { "p1" } "balanced" { "p4" } "quality" { "p6" } "max" { "p7" } }; $t = ""; if ($gpuSeries -eq "nvidia_ada" -and $codec -eq "av1") { if ($qualityPreset -eq "max") { $t = "-tune uhq" } else { $t = "-tune hq" } } elseif ($codec -eq "h265") { $t = "-tune hq" }; return "-c:v $e -preset $p -rc vbr -cq $quality $t".Trim() }
    if ($hwDevice -eq "AMD") { $e = switch ($codec) { "h264" { "h264_amf" } "h265" { "hevc_amf" } "av1" { "av1_amf" } }; $p = switch ($qualityPreset) { "fast" { "speed" } "balanced" { "balanced" } "quality" { "quality" } "max" { "quality" } }; return "-c:v $e -quality $p -rc cqp -qp-i $quality -qp-p $quality -qp-b $quality" }
    if ($hwDevice -eq "Intel") { $e = switch ($codec) { "h264" { "h264_qsv" } "h265" { "hevc_qsv" } "av1" { "av1_qsv" } }; $p = switch ($qualityPreset) { "fast" { "veryfast" } "balanced" { "balanced" } "quality" { "slow" } "max" { "veryslow" } }; return "-c:v $e -preset $p -global_quality $quality" }
    return "-c:v libx264 -crf $quality -preset medium"
}

function Get-VideoFiles {
    $allFiles = Get-ChildItem -Path $inputFolder -File -Recurse:$enableRecursiveSearch -ErrorAction SilentlyContinue
    return @($allFiles | Where-Object {
        $isVideo = $extensions -contains $_.Extension.ToLower(); $isAllowed = $true
        if ($isVideo) { $pathParts = $_.DirectoryName.Split('\'); foreach ($part in $pathParts) { if ($excludedFolders -contains $part.ToLower()) { $isAllowed = $false; break } } }
        return ($isVideo -and $isAllowed)
    })
}
function Get-VideoFilesCount { return (Get-VideoFiles).Count }

function Select-InputFolder {
    Add-Type -AssemblyName System.Windows.Forms; $dialog = New-Object System.Windows.Forms.FolderBrowserDialog; $dialog.Description = L "Select folder with video files" "Выберите папку с видеофайлами"; $dialog.ShowNewFolderButton = $false; $dialog.SelectedPath = $inputFolder
    if ($dialog.ShowDialog() -eq 'OK') { $script:inputFolder = $dialog.SelectedPath; $script:outputFolder = Join-Path $script:inputFolder "compressed"; $script:logsFolder = Join-Path $script:inputFolder "logs"; Write-Host (L "Input folder changed to:" "Папка ввода изменена на:") $script:inputFolder -ForegroundColor Green }
    Write-Host "`n$(L 'Press any key...' 'Нажмите любую клавишу...')"; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Toggle-RecursiveSearch { $script:enableRecursiveSearch = -not $script:enableRecursiveSearch; Write-Host (L "Recursive search:" "Рекурсивный поиск:") $(if ($enableRecursiveSearch) { L "ENABLED" "ВКЛЮЧЕН" } else { L "DISABLED" "ВЫКЛЮЧЕН" }) -ForegroundColor $(if ($enableRecursiveSearch) { "Green" } else { "Yellow" }); Write-Host "`n$(L 'Press any key...' 'Нажмите любую клавишу...')"; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }

function Show-HardwareMenu {
    do { Clear-Host; Write-Host "================================================================" -ForegroundColor Cyan; Write-Host "              $(L 'HARDWARE ACCELERATION SETTINGS' 'НАСТРОЙКИ АППАРАТНОГО УСКОРЕНИЯ')           " -ForegroundColor Cyan; Write-Host "================================================================" -ForegroundColor Cyan; Write-Host ""; Write-Host "  $(L 'Current:' 'Текущее:') $(Get-HardwareDescription)" -ForegroundColor White; Write-Host ""; Write-Host "  1. $(L 'Change device' 'Изменить устройство') ($hwDevice)"; Write-Host "  2. $(L 'Change GPU series' 'Изменить серию GPU') ($gpuSeries)"; Write-Host "  3. $(L 'Change codec' 'Изменить кодек') ($codec)"; Write-Host "  4. $(L 'Change quality preset' 'Изменить пресет качества') ($qualityPreset)"; Write-Host "  5. $(L 'Back' 'Назад')"; Write-Host ""
        $choice = Read-Host (L "Enter choice (1-5)" "Введите выбор (1-5)")
        switch ($choice) {
            '1' { Clear-Host; Write-Host "  1. CPU`n  2. NVIDIA`n  3. AMD`n  4. Intel`n  5. $(L 'Back' 'Назад')"; $c = Read-Host (L "Choice" "Выбор"); switch($c) { '1'{$script:hwDevice="CPU";$script:gpuSeries="none"} '2'{$script:hwDevice="NVIDIA"} '3'{$script:hwDevice="AMD"} '4'{$script:hwDevice="Intel"} }; Write-Host "`n$(L 'Press any key...' 'Нажмите любую клавишу...')"; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }
            '2' { Clear-Host; if ($hwDevice -eq "NVIDIA") { Write-Host "  1. Turing`n  2. Ampere`n  3. Ada/Blackwell (AV1)`n  4. $(L 'Back' 'Назад')"; $c=Read-Host (L "Choice" "Выбор"); switch($c){'1'{$script:gpuSeries="nvidia_turing"}'2'{$script:gpuSeries="nvidia_ampere"}'3'{$script:gpuSeries="nvidia_ada"}} } elseif ($hwDevice -eq "AMD") { Write-Host "  1. RDNA 1`n  2. RDNA 2`n  3. RDNA 3 (AV1)`n  4. $(L 'Back' 'Назад')"; $c=Read-Host (L "Choice" "Выбор"); switch($c){'1'{$script:gpuSeries="amd_rdna1"}'2'{$script:gpuSeries="amd_rdna2"}'3'{$script:gpuSeries="amd_rdna3"}} } elseif ($hwDevice -eq "Intel") { Write-Host "  1. 11th Gen+`n  2. Arc (AV1)`n  3. $(L 'Back' 'Назад')"; $c=Read-Host (L "Choice" "Выбор"); switch($c){'1'{$script:gpuSeries="intel_11gen"}'2'{$script:gpuSeries="intel_arc"}} } else { Write-Host (L "CPU selected" "Выбран CPU") }; Write-Host "`n$(L 'Press any key...' 'Нажмите любую клавишу...')"; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }
            '3' { Clear-Host; $sup = Get-SupportedCodecs; Write-Host (L "Supported codecs:" "Поддерживаемые кодеки:"); $i=1; foreach($c in $sup){Write-Host "  $i. $c"; $i++}; Write-Host "  $($sup.Count+1). $(L 'Back' 'Назад')"; $c=Read-Host (L "Choice" "Выбор"); if($c -match '^\d+$'){$idx=[int]$c-1; if($idx -ge 0 -and $idx -lt $sup.Count){$script:codec=$sup[$idx]}}; Write-Host "`n$(L 'Press any key...' 'Нажмите любую клавишу...')"; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }
            '4' { Clear-Host; Write-Host "  1. $(L 'Fast' 'Быстро')`n  2. $(L 'Balanced' 'Баланс')`n  3. $(L 'Quality' 'Качество')`n  4. $(L 'Max' 'Макс')`n  5. $(L 'Back' 'Назад')"; $c=Read-Host (L "Choice" "Выбор"); switch($c){'1'{$script:qualityPreset="fast"}'2'{$script:qualityPreset="balanced"}'3'{$script:qualityPreset="quality"}'4'{$script:qualityPreset="max"}}; Write-Host "`n$(L 'Press any key...' 'Нажмите любую клавишу...')"; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }
            '5' { return }
        }
    } while ($true)
}

function Show-Menu {
    Clear-Host
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "              $(L 'VIDEO COMPRESSION UTILITY' 'УТИЛИТА СЖАТИЯ ВИДЕО')                          " -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    $fc = Get-VideoFilesCount
    Write-Host "$(L 'Input folder' 'Папка ввода'): $inputFolder" -ForegroundColor Gray
    Write-Host "$(L 'Video files found' 'Найдено видеофайлов'): " -NoNewline -ForegroundColor Gray
    if ($fc -gt 0) { Write-Host "$fc" -ForegroundColor Green } else { Write-Host "$fc" -ForegroundColor Red }
    Write-Host "$(L 'Hardware' 'Оборудование'): $(Get-HardwareDescription) | $(L 'Quality' 'Качество'): $crfValue" -ForegroundColor Yellow
    Write-Host "$(L 'Recursive' 'Рекурсия'): $(if ($enableRecursiveSearch) { L 'ON' 'ВКЛ'  } else { L 'OFF' 'ВЫКЛ' }) | $(L 'VMAF' 'VMAF'): $(if ($enableVMAF) { L 'ON' 'ВКЛ' } else { L 'OFF' 'ВЫКЛ' }) | $(L 'AutoCRF' 'АвтоCRF'): $(if ($enableAutoCRF) { L 'ON' 'ВКЛ' } else { L 'OFF' 'ВЫКЛ' }) | $(L 'Logs' 'Логи'): $(if ($enableLogs) { L 'ON' 'ВКЛ' } else { L 'OFF' 'ВЫКЛ' }) | $(L 'Presets' 'Пресеты'): $($presets.Count) | $(L 'Lang' 'Язык'): $currentLanguage" -ForegroundColor Gray
    Write-Host ""
    Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "$(L ' FILES & FOLDERS' ' ФАЙЛЫ И ПАПКИ')" -ForegroundColor Cyan
    Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "  1. $(L 'Change input folder' 'Изменить папку ввода')" -ForegroundColor White
    Write-Host "  2. $(L 'Toggle recursive search' 'Переключить рекурсивный поиск')" -ForegroundColor White
    Write-Host ""
    Write-Host "----------------------------------------------------------------" -ForegroundColor Yellow
    Write-Host "$(L ' HARDWARE & ENCODING' '️ ОБОРУДОВАНИЕ И КОДИРОВАНИЕ')" -ForegroundColor Yellow
    Write-Host "----------------------------------------------------------------" -ForegroundColor Yellow
    Write-Host "  D. $(L 'Auto-detect hardware' 'Автоопределение оборудования')" -ForegroundColor White
    Write-Host "  H. $(L 'Hardware Acceleration Parameters' 'Параметры аппаратного ускорения')" -ForegroundColor White
	Write-Host "  Q. $(L 'Change quality value' 'Изменить значение качества') ($crfValue)" -ForegroundColor White
    Write-Host ""
    Write-Host "----------------------------------------------------------------" -ForegroundColor Green
    Write-Host "$(L ' QUALITY & VMAF' ' КАЧЕСТВО И VMAF')" -ForegroundColor Green
    Write-Host "----------------------------------------------------------------" -ForegroundColor Green
    Write-Host "  V. $(L 'Toggle VMAF' 'Переключить VMAF')" -ForegroundColor White
    Write-Host "  T. $(L 'Change VMAF threshold' 'Изменить порог VMAF') ($vmafThreshold)" -ForegroundColor White
	Write-Host "  A. $(L 'Toggle Auto CRF' 'Переключить Авто CRF')" -ForegroundColor White
    Write-Host "  M. $(L 'Change minimum CRF' 'Изменить мин. CRF') ($minCRF)" -ForegroundColor White
    Write-Host "  I. $(L 'Change max iterations' 'Изменить макс. итераций') ($maxIterations)" -ForegroundColor White
    Write-Host ""
    Write-Host "----------------------------------------------------------------" -ForegroundColor Magenta
    Write-Host "$(L ' SYSTEM & MANAGEMENT' ' СИСТЕМА И УПРАВЛЕНИЕ')" -ForegroundColor Magenta
    Write-Host "----------------------------------------------------------------" -ForegroundColor Magenta
    Write-Host "  G. $(L 'Change language' 'Изменить язык')" -ForegroundColor White
    Write-Host "  L. $(L 'Logs management' 'Управление логами')" -ForegroundColor White
    Write-Host "  P. $(L 'Presets management' 'Управление пресетами')" -ForegroundColor White
    Write-Host "  S. $(L 'Save settings now' 'Сохранить настройки сейчас')" -ForegroundColor White
	Write-Host "  F. $(L 'FFmpeg' 'FFmpeg')" -ForegroundColor White 
    Write-Host "  W. $(L 'Help & Guide' 'Справка и руководство')" -ForegroundColor White
    Write-Host ""
    Write-Host "----------------------------------------------------------------" -ForegroundColor Red
    Write-Host "$(L ' ACTIONS' '️ ДЕЙСТВИЯ')" -ForegroundColor Red
    Write-Host "----------------------------------------------------------------" -ForegroundColor Red
    Write-Host "  0. $(L 'Start compression (ESC to cancel)' 'Начать сжатие (ESC для отмены)')" -ForegroundColor Green
    Write-Host "  X. $(L 'Exit (settings will be saved)' 'Выход (настройки сохранятся)')" -ForegroundColor Red
    Write-Host "----------------------------------------------------------------" -ForegroundColor Red
    Write-Host ""
}

function Set-CRF { Clear-Host; Write-Host "================================================================" -ForegroundColor Cyan; Write-Host "              $(L 'CHANGE QUALITY VALUE' 'ИЗМЕНИТЬ ЗНАЧЕНИЕ КАЧЕСТВА')                        " -ForegroundColor Cyan; Write-Host "================================================================" -ForegroundColor Cyan; Write-Host ""; Write-Host "$(L 'Current' 'Текущее'): $crfValue`n$(L 'Scale' 'Шкала'): 18-20=$(L 'Lossless' 'Без потерь'), 23=$(L 'Default' 'По умолч.'), 28-30=$(L 'Good' 'Хорошо'), 35+=$(L 'Low' 'Низкое')"; Write-Host "`n$(L 'Enter new value (0-51, b=back)' 'Введите новое значение (0-51, b=назад)'): " -NoNewline -ForegroundColor Cyan; $iv = Read-Host; if ($iv -ne 'b' -and $iv -ne 'B') { if ($iv -match '^\d+$') { $nv = [int]$iv; if ($nv -ge 0 -and $nv -le 51) { $script:crfValue = $nv; Write-Host (L "Changed to" "Изменено на") $nv -ForegroundColor Green } else { Write-Host (L "Invalid value" "Неверное значение") -ForegroundColor Red } } else { Write-Host (L "Invalid input" "Неверный ввод") -ForegroundColor Red } }; Write-Host "`n$(L 'Press any key...' 'Нажмите любую клавишу...')"; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }
function Toggle-VMAF { $script:enableVMAF = -not $script:enableVMAF; Write-Host "VMAF: $(if ($enableVMAF) { L 'Enabled' 'Включен' } else { L 'Disabled' 'Отключен' })" -ForegroundColor $(if ($enableVMAF) { "Green" } else { "Red" }); Write-Host "`n$(L 'Press any key...' 'Нажмите любую клавишу...')"; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }
function Toggle-AutoCRF { $script:enableAutoCRF = -not $script:enableAutoCRF; Write-Host "Auto CRF: $(if ($enableAutoCRF) { L 'Enabled' 'Включен' } else { L 'Disabled' 'Отключен' })" -ForegroundColor $(if ($enableAutoCRF) { "Green" } else { "Red" }); Write-Host "`n$(L 'Press any key...' 'Нажмите любую клавишу...')"; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }
function Set-VMAFThreshold { Clear-Host; Write-Host "$(L 'Current VMAF threshold' 'Текущий порог VMAF'): $vmafThreshold`n$(L 'Enter new (0-100, b=back)' 'Введите новый (0-100, b=назад)'): " -NoNewline -ForegroundColor Cyan; $iv = Read-Host; if ($iv -ne 'b' -and $iv -ne 'B') { if ($iv -match '^\d+$') { $nv = [int]$iv; if ($nv -ge 0 -and $nv -le 100) { $script:vmafThreshold = $nv } } }; Write-Host "`n$(L 'Press any key...' 'Нажмите любую клавишу...')"; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }
function Set-MaxIterations { Clear-Host; Write-Host "$(L 'Current max iterations' 'Текущие макс. итерации'): $maxIterations`n$(L 'Enter new (1-10, b=back)' 'Введите новые (1-10, b=назад)'): " -NoNewline -ForegroundColor Cyan; $iv = Read-Host; if ($iv -ne 'b' -and $iv -ne 'B') { if ($iv -match '^\d+$') { $nv = [int]$iv; if ($nv -ge 1 -and $nv -le 10) { $script:maxIterations = $nv } } }; Write-Host "`n$(L 'Press any key...' 'Нажмите любую клавишу...')"; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }
function Set-MinCRF { Clear-Host; Write-Host "$(L 'Current min CRF' 'Текущий мин. CRF'): $minCRF`n$(L 'Enter new (0-51, b=back)' 'Введите новый (0-51, b=назад)'): " -NoNewline -ForegroundColor Cyan; $iv = Read-Host; if ($iv -ne 'b' -and $iv -ne 'B') { if ($iv -match '^\d+$') { $nv = [int]$iv; if ($nv -ge 0 -and $nv -le 51) { $script:minCRF = $nv } } }; Write-Host "`n$(L 'Press any key...' 'Нажмите любую клавишу...')"; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }

function Start-Compression {
    Clear-Host; Write-Host "================================================================" -ForegroundColor Cyan; Write-Host "              $(L 'STARTING COMPRESSION' 'НАЧАЛО СЖАТИЯ')                                " -ForegroundColor Cyan; Write-Host "================================================================" -ForegroundColor Cyan; Write-Host ""; Write-Host "$(L 'Hardware' 'Оборудование'): $(Get-HardwareDescription)`n$(L 'Recursive' 'Рекурсия'): $(if ($enableRecursiveSearch) { L 'ON' 'ВКЛ' } else { L 'OFF' 'ВЫКЛ' })`n$(L 'VMAF' 'VMAF'): $(if ($enableVMAF) { L 'ON' 'ВКЛ' } else { L 'OFF' 'ВЫКЛ' })`n$(L 'Logs' 'Логи'): $(if ($enableLogs) { L 'ON' 'ВКЛ' } else { L 'OFF' 'ВЫКЛ' })"; Write-Host "`n$(L 'Press any key to start, b=back, ESC=cancel' 'Нажмите любую клавишу для начала, b=назад, ESC=отмена')..." -ForegroundColor Cyan
    $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown"); if ($key.Character -eq 'b' -or $key.Character -eq 'B') { return }
    $originalProgressColor = $Host.PrivateData.ProgressForegroundColor; $script:cancelRequested = $false
    if (-not (Test-Path $outputFolder)) { New-Item -ItemType Directory -Path $outputFolder | Out-Null }
    if ($enableLogs -and -not (Test-Path $logsFolder)) { New-Item -ItemType Directory -Path $logsFolder | Out-Null }
    $files = Get-VideoFiles; if ($files.Count -eq 0) { Write-Host (L "Error: No video files found" "Ошибка: Видеофайлы не найдены") -ForegroundColor Red; Write-Host "`n$(L 'Press any key...' 'Нажмите любую клавишу...')"; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown"); return }
    Write-Host "$(L 'Files found' 'Найдено файлов'): $($files.Count). $(L 'Starting compression...' 'Начало сжатия...')`n$(L 'Press ESC to cancel...' 'Нажмите ESC для отмены...')" -ForegroundColor Cyan; Write-Host "---------------------------------------------------"
    $counter = 1; foreach ($file in $files) {
        if ($script:cancelRequested) { Write-Host "`n!!! $(L 'CANCELLATION REQUESTED' 'ОТМЕНА ЗАПРОШЕНА') !!!" -ForegroundColor Red; break }
        $inputFile = $file.FullName
        if ($enableRecursiveSearch) {
            $rp = $inputFile.Substring($inputFolder.Length).TrimStart('\'); $rd = Split-Path $rp -Parent
            if ($rd) { $osd = Join-Path $outputFolder $rd; if (-not (Test-Path $osd)) { New-Item -ItemType Directory -Path $osd -Force | Out-Null }; $outputFile = Join-Path $osd "$($file.BaseName)_compressed.mp4" }
            else { $outputFile = Join-Path $outputFolder "$($file.BaseName)_compressed.mp4" }
        } else { $outputFile = Join-Path $outputFolder "$($file.BaseName)_compressed.mp4" }
        $sizeBefore = $file.Length; $sizeBeforeFormatted = Format-FileSize $sizeBefore
        if ($enableRecursiveSearch) { Write-Host "`n[$counter/$($files.Count)] $(L 'Processing' 'Обработка'): $rp" -ForegroundColor Yellow } else { Write-Host "`n[$counter/$($files.Count)] $(L 'Processing' 'Обработка'): $($file.Name)" -ForegroundColor Yellow }
        Write-Host "  $(L 'Initial size' 'Начальный размер'): $sizeBeforeFormatted" -ForegroundColor Gray
        $totalDuration = 0; try { $po = & ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$inputFile" 2>$null; if ($po) { $totalDuration = [double]$po } } catch {}
        $currentCRF = $crfValue; $iteration = 0; $needsRecompression = $true
        while ($needsRecompression) {
            $iteration++; if ($iteration -gt 1) { Write-Host "  -> $(L 'Iteration' 'Итерация') $iteration ($(L 'Quality' 'Качество'): $currentCRF)" -ForegroundColor Magenta }
            $logFile = Join-Path $env:TEMP "ffmpeg_log_$($file.BaseName)_iter$iteration.txt"; if (Test-Path $logFile) { Remove-Item $logFile -Force }
            $videoArgs = Build-VideoArgs -quality $currentCRF; $ffmpegArgs = "-i `"$inputFile`" $videoArgs -c:a aac -b:a 128k -y `"$outputFile`""; $Host.PrivateData.ProgressForegroundColor = "Yellow"
            $process = Start-Process -FilePath "ffmpeg" -ArgumentList $ffmpegArgs -RedirectStandardError $logFile -PassThru -NoNewWindow; $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            while (!$process.HasExited) {
                if ([System.Console]::KeyAvailable) {
                    $k = [System.Console]::ReadKey($true)
                    if ($k.Key -eq [System.ConsoleKey]::Escape) {
                        $script:cancelRequested = $true; Write-Host "`n  !!! $(L 'CANCELLATION REQUESTED' 'ОТМЕНА ЗАПРОШЕНА') !!!" -ForegroundColor Red
                        try { if (!$process.HasExited) { $process.Kill(); $process.WaitForExit(5000) } } catch {}
                        Save-Log -SourceLog $logFile -VideoBaseName $file.BaseName -LogType "compress" -Iteration $iteration
                        if (Test-Path $outputFile) { try { Remove-Item $outputFile -Force -ErrorAction SilentlyContinue } catch {} }
                        if (Test-Path $logFile) { try { Remove-Item $logFile -Force -ErrorAction SilentlyContinue } catch {} }
                        Write-Host "  $(L 'File processing cancelled.' 'Обработка файла отменена.')" -ForegroundColor Red; break
                    }
                }
                $elapsed = $stopwatch.Elapsed; $currentTime = 0
                if (Test-Path $logFile) { try { $ll = Get-Content $logFile -Tail 1 -ErrorAction Stop; if ($ll -match 'time=(\d+):(\d+):(\d+(?:\.\d+)?)') { $currentTime = [int]$matches[1]*3600 + [int]$matches[2]*60 + [double]$matches[3] } } catch {} }
                $percent = 0; if ($totalDuration -gt 0) { $percent = [math]::Min(100, ($currentTime / $totalDuration) * 100) }
                $st = "$(L 'Time' 'Время'): $($elapsed.ToString('hh\:mm\:ss'))"; if ($totalDuration -gt 0) { $st += " | $(L 'Progress' 'Прогресс'): $([math]::Round($percent, 1))%" }
                Write-Progress -Activity "$(L 'Compressing' 'Сжатие'): $($file.Name) (Q: $currentCRF)" -Status $st -PercentComplete $percent -Id 1; Start-Sleep -Milliseconds 1000
            }
            if ($script:cancelRequested) { $stopwatch.Stop(); Write-Progress -Activity "$(L 'Compressing' 'Сжатие'): $($file.Name)" -Completed -Id 1; $Host.PrivateData.ProgressForegroundColor = $originalProgressColor; break }
            $stopwatch.Stop(); Write-Progress -Activity "$(L 'Compressing' 'Сжатие'): $($file.Name)" -Completed -Id 1; $Host.PrivateData.ProgressForegroundColor = $originalProgressColor
            Save-Log -SourceLog $logFile -VideoBaseName $file.BaseName -LogType "compress" -Iteration $iteration; if (Test-Path $logFile) { Remove-Item $logFile -Force }
            if ($LASTEXITCODE -eq 0 -and (Test-Path $outputFile)) {
                $sizeAfter = (Get-Item $outputFile).Length; $sizeAfterFormatted = Format-FileSize $sizeAfter; $ratio = [math]::Round(($sizeAfter / [double]$sizeBefore) * 100, 1)
                Write-Host "  -> $(L 'Successfully saved!' 'Успешно сохранено!') $(L 'Final size' 'Итоговый размер'): $sizeAfterFormatted ($ratio%) | $(L 'Time' 'Время'): $($stopwatch.Elapsed.ToString('hh\:mm\:ss'))" -ForegroundColor Green
                if ($enableVMAF) {
                    $vw = & ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$inputFile" 2>$null; $vh = & ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$inputFile" 2>$null; $vfs = & ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of csv=p=0 "$inputFile" 2>$null; $vmafScore = "N/A"
                    if ($vw -and $vh -and $vfs) {
                        if ($vfs -match '(\d+)/(\d+)') { $vmafFps = [math]::Round([double]$matches[1] / [double]$matches[2], 3) } else { $vmafFps = [double]$vfs }
                        $vmafLogFile = Join-Path $env:TEMP "vmaf_log_$($file.BaseName)_iter$iteration.txt"; if (Test-Path $vmafLogFile) { Remove-Item $vmafLogFile -Force }
                        $vmafArgs = "-i `"$inputFile`" -i `"$outputFile`" -lavfi `"[0:v]scale=$vw`:$vh,fps=$vmafFps[ref];[1:v]scale=$vw`:$vh,fps=$vmafFps[dist];[ref][dist]libvmaf`" -f null -"; $Host.PrivateData.ProgressForegroundColor = "Whiite"
                        Write-Progress -Activity "$(L 'Calculating VMAF' 'Расчет VMAF'): $($file.Name)" -Status "$(L 'Initializing' 'Инициализация')..." -PercentComplete -1 -Id 2
                        $vmafProcess = Start-Process -FilePath "ffmpeg" -ArgumentList $vmafArgs -RedirectStandardError $vmafLogFile -PassThru -NoNewWindow; $vmafStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                        while (!$vmafProcess.HasExited) {
                            if ([System.Console]::KeyAvailable) {
                                $k = [System.Console]::ReadKey($true)
                                if ($k.Key -eq [System.ConsoleKey]::Escape) {
                                    $script:cancelRequested = $true; Write-Host "`n  !!! $(L 'CANCELLATION REQUESTED' 'ОТМЕНА ЗАПРОШЕНА') !!!" -ForegroundColor Red
                                    try { if (!$vmafProcess.HasExited) { $vmafProcess.Kill(); $vmafProcess.WaitForExit(5000) } } catch {}
                                    Save-Log -SourceLog $vmafLogFile -VideoBaseName $file.BaseName -LogType "vmaf" -Iteration $iteration
                                    if (Test-Path $vmafLogFile) { try { Remove-Item $vmafLogFile -Force -ErrorAction SilentlyContinue } catch {} }
                                    Write-Host "  $(L 'VMAF calculation cancelled.' 'Расчет VMAF отменен.')" -ForegroundColor Red; break
                                }
                            }
                            $ve = $vmafStopwatch.Elapsed; $vct = 0
                            if (Test-Path $vmafLogFile) { try { $vll = Get-Content $vmafLogFile -Tail 1 -ErrorAction Stop; if ($vll -match 'time=(\d+):(\d+):(\d+(?:\.\d+)?)') { $vct = [int]$matches[1]*3600 + [int]$matches[2]*60 + [double]$matches[3] } } catch {} }
                            $vp = 0; if ($totalDuration -gt 0) { $vp = [math]::Min(100, ($vct / $totalDuration) * 100) }
                            $vst = "$(L 'Time' 'Время'): $($ve.ToString('hh\:mm\:ss'))"; if ($totalDuration -gt 0) { $vst += " | $(L 'Progress' 'Прогресс'): $([math]::Round($vp, 1))%" }
                            Write-Progress -Activity "$(L 'Calculating VMAF' 'Расчет VMAF'): $($file.Name)" -Status $vst -PercentComplete $vp -Id 2; Start-Sleep -Milliseconds 1000
                        }
                        if ($script:cancelRequested) { $vmafStopwatch.Stop(); Write-Progress -Activity "$(L 'Calculating VMAF' 'Расчет VMAF')" -Completed -Id 2; $Host.PrivateData.ProgressForegroundColor = $originalProgressColor; break }
                        $vmafStopwatch.Stop(); Write-Progress -Activity "$(L 'Calculating VMAF' 'Расчет VMAF')" -Completed -Id 2; $Host.PrivateData.ProgressForegroundColor = $originalProgressColor
                        Save-Log -SourceLog $vmafLogFile -VideoBaseName $file.BaseName -LogType "vmaf" -Iteration $iteration
                        if (Test-Path $vmafLogFile) {
                            $lc = Get-Content $vmafLogFile -Raw
                            if ($lc -match 'VMAF score:\s*([\d\.]+)') { $vmafScore = [math]::Round([double]$matches[1], 2) }
                            elseif ($lc -match '"vmaf":\s*([\d\.]+)') { $vmafScore = [math]::Round([double]$matches[1], 2) }
                            Remove-Item $vmafLogFile -Force
                        }
                        Write-Host "  -> $(L 'VMAF time' 'Время VMAF'): $($vmafStopwatch.Elapsed.ToString('hh\:mm\:ss'))" -ForegroundColor DarkYellow
                    }
                    $vc = "Gray"; if ($vmafScore -is [double]) { if ($vmafScore -ge 90) { $vc = "DarkGreen" } elseif ($vmafScore -ge 80) { $vc = "Yellow" } elseif ($vmafScore -ge 70) { $vc = "DarkYellow" } else { $vc = "Red" } }
                    Write-Host "  -> $(L 'VMAF Score' 'Оценка VMAF'): $vmafScore" -ForegroundColor $vc
                    $needsRecompression = $false
                    if ($enableAutoCRF -and $vmafScore -is [double] -and $vmafScore -lt $vmafThreshold) {
                        if ($iteration -lt $maxIterations) {
                            $nCRF = $currentCRF - 2
                            if ($nCRF -ge $minCRF) { Write-Host "  -> $(L 'VMAF below' 'VMAF ниже') $vmafThreshold. $(L 'Increasing quality' 'Увеличение качества') $currentCRF -> $nCRF..." -ForegroundColor Yellow; $currentCRF = $nCRF; $needsRecompression = $true; if (Test-Path $outputFile) { Remove-Item $outputFile -Force } }
                            else { Write-Host "  -> $(L 'Cannot increase below' 'Нельзя увеличить ниже') $minCRF" -ForegroundColor Yellow }
                        } else { Write-Host "  -> $(L 'Max iterations reached' 'Достигнут лимит итераций')" -ForegroundColor Yellow }
                    }
                } else { $needsRecompression = $false }
            } else { Write-Host "  -> $(L 'ERROR processing file' 'ОШИБКА обработки файла'): $($file.Name)" -ForegroundColor Red; $needsRecompression = $false }
        }
        if ($script:cancelRequested) { break }; $counter++
    }
    $Host.PrivateData.ProgressForegroundColor = $originalProgressColor
    if ($script:cancelRequested) { Write-Host "`n---------------------------------------------------`n!!! $(L 'PROCESS CANCELLED' 'ПРОЦЕСС ОТМЕНЕН') !!!" -ForegroundColor Red; Write-Host "$(L 'Completed files preserved.' 'Завершенные файлы сохранены.')" -ForegroundColor Yellow }
    else { Write-Host "`n---------------------------------------------------`n$(L 'All tasks completed!' 'Все задачи выполнены!')" -ForegroundColor Cyan; if ($enableLogs) { Write-Host "$(L 'Logs saved to' 'Логи сохранены в'): $logsFolder" -ForegroundColor DarkGray } }
    Write-Host "`n$(L 'Press any key to return to menu...' 'Нажмите любую клавишу для возврата в меню...')"; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# === MAIN LOOP ===
Load-Settings; Load-Presets
if (-not [string]::IsNullOrEmpty($VideoFolder)) { $inputFolder = $VideoFolder }
$outputFolder = Join-Path $inputFolder "compressed"; $script:logsFolder = Join-Path $inputFolder "logs"
$extensions = @(".mp4", ".mkv", ".avi", ".mov", ".m4v", ".webm", ".ts", ".mts", ".m2ts", ".flv", ".wmv")

try {
    do {
        Show-Menu; $choice = Read-Host (L "Enter your choice" "Введите ваш выбор")
        switch ($choice.ToUpper()) {
            '1' { Select-InputFolder } '2' { Toggle-RecursiveSearch } 'H' { Show-HardwareMenu } 'D' { Apply-OptimalSettings } 'P' { Show-PresetsMenu } 'Q' { Set-CRF } 'V' { Toggle-VMAF } 'A' { Toggle-AutoCRF } 'T' { Set-VMAFThreshold } 'I' { Set-MaxIterations } 'M' { Set-MinCRF } 'L' { Show-LogsMenu } 'W' { Show-Help }
            'G' { Change-Language }
            'F' { Show-FFmpegMenu }
            'S' { Save-Settings; Write-Host "`n$(L 'Press any key...' 'Нажмите любую клавишу...')"; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }
            '0' { Start-Compression }
            'X' { Write-Host (L "Saving settings before exit..." "Сохранение настроек перед выходом...") -ForegroundColor Yellow; Save-Settings; Write-Host "`n$(L 'Exiting... Goodbye!' 'Выход... До свидания!')" -ForegroundColor Cyan; exit }
            default { Write-Host "`n$(L 'Invalid choice.' 'Неверный выбор.')" -ForegroundColor Red; Write-Host (L 'Press any key...' 'Нажмите любую клавишу...'); $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }
        }
    } while ($true)
} catch { Write-Host "`n`n!!! ERROR !!!" -ForegroundColor Red; Write-Host $_.Exception.Message -ForegroundColor Red; Write-Host "`n$(L 'Press any key to exit...' 'Нажмите любую клавишу для выхода...')"; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }