param(
    [string]$VideoFolder = ""
)

# === PATHS ===
$scriptFolder = $PSScriptRoot
if (-not $scriptFolder) { $scriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $scriptFolder) { $scriptFolder = Get-Location }

$settingsFile = Join-Path $scriptFolder "settings.json"
$presetsFile = Join-Path $scriptFolder "presets.json"

# === DEFAULT SETTINGS ===
$defaultInputFolder = Split-Path $scriptFolder -Parent
if (-not $defaultInputFolder) { $defaultInputFolder = Get-Location }

# === COMPRESSION SETTINGS ===
$crfValue = 23
$enableVMAF = $true
$enableAutoCRF = $true
$vmafThreshold = 90
$maxIterations = 3
$minCRF = 18

# === SEARCH SETTINGS ===
$enableRecursiveSearch = $false
$excludedFolders = @("compressed", "scripts", "logs")

# === HARDWARE ACCELERATION SETTINGS ===
$hwDevice = "CPU"
$gpuSeries = "none"
$codec = "h264"
$qualityPreset = "balanced"

# === DETECTED HARDWARE INFO ===
$detectedCPU = "Unknown"
$detectedCPUCores = 0
$detectedCPUThreads = 0
$detectedGPU = "Unknown"
$detectedGPUList = @()
$detectedRAM = 0

# === CANCELLATION FLAG ===
$cancelRequested = $false

# === LOGS SETTINGS ===
$enableLogs = $true
$logsFolder = ""

# === PRESETS STORAGE ===
$presets = @{}

# === LOAD SAVED SETTINGS ===
function Load-Settings {
    if (Test-Path $settingsFile) {
        try {
            $saved = Get-Content $settingsFile -Raw | ConvertFrom-Json
            Write-Host "Loading saved settings from: $settingsFile" -ForegroundColor Gray
            
            if ($saved.InputFolder) { $script:inputFolder = $saved.InputFolder }
            else { $script:inputFolder = $defaultInputFolder }
            
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
            
            Write-Host "Settings loaded successfully!" -ForegroundColor Green
        } catch {
            Write-Host "Failed to load settings: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Using default settings." -ForegroundColor Yellow
            $script:inputFolder = $defaultInputFolder
        }
    } else {
        Write-Host "No saved settings found. Using defaults." -ForegroundColor Yellow
        $script:inputFolder = $defaultInputFolder
    }
}

function Save-Settings {
    try {
        $settings = @{
            InputFolder = $inputFolder
            CRFValue = $crfValue
            EnableVMAF = $enableVMAF
            EnableAutoCRF = $enableAutoCRF
            VMAFThreshold = $vmafThreshold
            MaxIterations = $maxIterations
            MinCRF = $minCRF
            EnableRecursiveSearch = $enableRecursiveSearch
            HwDevice = $hwDevice
            GpuSeries = $gpuSeries
            Codec = $codec
            QualityPreset = $qualityPreset
            EnableLogs = $enableLogs
        }
        
        $settings | ConvertTo-Json | Out-File -FilePath $settingsFile -Encoding UTF8 -Force
        Write-Host "Settings saved to: $settingsFile" -ForegroundColor Green
    } catch {
        Write-Host "Failed to save settings: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# === PRESETS MANAGEMENT ===
function Load-Presets {
    if (Test-Path $presetsFile) {
        try {
            $script:presets = Get-Content $presetsFile -Raw | ConvertFrom-Json
            Write-Host "Loaded $($presets.Count) preset(s) from: $presetsFile" -ForegroundColor Gray
        } catch {
            Write-Host "Failed to load presets: $($_.Exception.Message)" -ForegroundColor Red
            $script:presets = @{}
        }
    } else {
        Write-Host "No saved presets found." -ForegroundColor Yellow
        $script:presets = @{}
    }
}

function Save-Presets {
    try {
        $script:presets | ConvertTo-Json -Depth 10 | Out-File -FilePath $presetsFile -Encoding UTF8 -Force
        Write-Host "Presets saved to: $presetsFile" -ForegroundColor Green
    } catch {
        Write-Host "Failed to save presets: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Save-CurrentPreset {
    Clear-Host
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "              SAVE CURRENT SETTINGS AS PRESET                   " -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Current settings will be saved:" -ForegroundColor Yellow
    Write-Host "  Device: $hwDevice" -ForegroundColor White
    Write-Host "  GPU Series: $gpuSeries" -ForegroundColor White
    Write-Host "  Codec: $codec" -ForegroundColor White
    Write-Host "  Quality: $crfValue" -ForegroundColor White
    Write-Host "  Preset: $qualityPreset" -ForegroundColor White
    Write-Host "  VMAF: $(if ($enableVMAF) { 'Enabled' } else { 'Disabled' })" -ForegroundColor White
    Write-Host "  Auto CRF: $(if ($enableAutoCRF) { 'Enabled' } else { 'Disabled' })" -ForegroundColor White
    Write-Host ""
    Write-Host "Enter preset name (or 'b' to cancel): " -NoNewline -ForegroundColor Cyan
    $presetName = Read-Host
    
    if ($presetName -eq 'b' -or $presetName -eq 'B' -or [string]::IsNullOrWhiteSpace($presetName)) {
        Write-Host "Cancelled." -ForegroundColor Yellow
        Write-Host "`nPress any key to continue..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }
    
    if ($presets.ContainsKey($presetName)) {
        Write-Host "Preset '$presetName' already exists. Overwrite? (Y/N): " -NoNewline -ForegroundColor Yellow
        $answer = Read-Host
        if ($answer -ne 'Y' -and $answer -ne 'y') {
            Write-Host "Cancelled." -ForegroundColor Yellow
            Write-Host "`nPress any key to continue..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            return
        }
    }
    
    $presetData = @{
        HwDevice = $hwDevice
        GpuSeries = $gpuSeries
        Codec = $codec
        QualityPreset = $qualityPreset
        CRFValue = $crfValue
        EnableVMAF = $enableVMAF
        EnableAutoCRF = $enableAutoCRF
        VMAFThreshold = $vmafThreshold
        MaxIterations = $maxIterations
        MinCRF = $minCRF
        CreatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $script:presets[$presetName] = $presetData
    Save-Presets
    
    Write-Host ""
    Write-Host "Preset '$presetName' saved successfully!" -ForegroundColor Green
    Write-Host "`nPress any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Load-Preset {
    Clear-Host
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "              LOAD PRESET                                       " -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    if ($presets.Count -eq 0) {
        Write-Host "No presets saved yet." -ForegroundColor Yellow
        Write-Host "`nPress any key to continue..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }
    
    Write-Host "Available presets:" -ForegroundColor Yellow
    $i = 1
    $presetNames = @()
    foreach ($presetName in $presets.Keys | Sort-Object) {
        $presetNames += $presetName
        $p = $presets[$presetName]
        Write-Host "  $i. $presetName" -ForegroundColor White
        Write-Host "     Device: $($p.HwDevice) | Codec: $($p.Codec) | Quality: $($p.CRFValue) | Preset: $($p.QualityPreset)" -ForegroundColor Gray
        $i++
    }
    Write-Host "  $($presetNames.Count + 1). Cancel" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Enter preset number: " -NoNewline -ForegroundColor Cyan
    $choice = Read-Host
    
    if ($choice -match '^\d+$') {
        $idx = [int]$choice - 1
        if ($idx -ge 0 -and $idx -lt $presetNames.Count) {
            $selectedPreset = $presetNames[$idx]
            $p = $presets[$selectedPreset]
            
            $script:hwDevice = $p.HwDevice
            $script:gpuSeries = $p.GpuSeries
            $script:codec = $p.Codec
            $script:qualityPreset = $p.QualityPreset
            $script:crfValue = [int]$p.CRFValue
            $script:enableVMAF = [bool]$p.EnableVMAF
            $script:enableAutoCRF = [bool]$p.EnableAutoCRF
            $script:vmafThreshold = [int]$p.VMAFThreshold
            $script:maxIterations = [int]$p.MaxIterations
            $script:minCRF = [int]$p.MinCRF
            
            Write-Host ""
            Write-Host "Preset '$selectedPreset' loaded successfully!" -ForegroundColor Green
            Write-Host "Current settings updated." -ForegroundColor Gray
        } else {
            Write-Host "Invalid selection." -ForegroundColor Red
        }
    } else {
        Write-Host "Invalid input." -ForegroundColor Red
    }
    
    Write-Host "`nPress any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Delete-Preset {
    Clear-Host
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "              DELETE PRESET                                     " -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    if ($presets.Count -eq 0) {
        Write-Host "No presets to delete." -ForegroundColor Yellow
        Write-Host "`nPress any key to continue..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }
    
    Write-Host "Available presets:" -ForegroundColor Yellow
    $i = 1
    $presetNames = @()
    foreach ($presetName in $presets.Keys | Sort-Object) {
        $presetNames += $presetName
        Write-Host "  $i. $presetName" -ForegroundColor White
        $i++
    }
    Write-Host "  $($presetNames.Count + 1). Cancel" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Enter preset number to delete: " -NoNewline -ForegroundColor Cyan
    $choice = Read-Host
    
    if ($choice -match '^\d+$') {
        $idx = [int]$choice - 1
        if ($idx -ge 0 -and $idx -lt $presetNames.Count) {
            $selectedPreset = $presetNames[$idx]
            Write-Host "Delete preset '$selectedPreset'? (Y/N): " -NoNewline -ForegroundColor Yellow
            $answer = Read-Host
            
            if ($answer -eq 'Y' -or $answer -eq 'y') {
                $script:presets.Remove($selectedPreset)
                Save-Presets
                Write-Host "Preset '$selectedPreset' deleted." -ForegroundColor Green
            } else {
                Write-Host "Cancelled." -ForegroundColor Yellow
            }
        } else {
            Write-Host "Invalid selection." -ForegroundColor Red
        }
    } else {
        Write-Host "Invalid input." -ForegroundColor Red
    }
    
    Write-Host "`nPress any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Show-PresetsMenu {
    do {
        Clear-Host
        Write-Host "================================================================" -ForegroundColor Cyan
        Write-Host "              PRESETS MANAGEMENT                                " -ForegroundColor Cyan
        Write-Host "================================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Presets file: $presetsFile" -ForegroundColor Gray
        Write-Host "Saved presets: $($presets.Count)" -ForegroundColor White
        Write-Host ""
        Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
        Write-Host "  1. Save current settings as preset" -ForegroundColor Green
        Write-Host "  2. Load preset" -ForegroundColor Cyan
        Write-Host "  3. Delete preset" -ForegroundColor Red
        Write-Host "  4. Back to main menu" -ForegroundColor Yellow
        Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
        Write-Host ""
        
        $choice = Read-Host "Enter your choice (1-4)"
        
        switch ($choice) {
            '1' { Save-CurrentPreset }
            '2' { Load-Preset }
            '3' { Delete-Preset }
            '4' { return }
            default {
                Write-Host "`nInvalid choice." -ForegroundColor Red
                Write-Host "Press any key to continue..."
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
        }
    } while ($true)
}

# === INITIALIZE ===
Load-Settings
Load-Presets

if (-not [string]::IsNullOrEmpty($VideoFolder)) {
    $inputFolder = $VideoFolder
}

$outputFolder = Join-Path $inputFolder "compressed"
$script:logsFolder = Join-Path $inputFolder "logs"
$extensions = @(".mp4", ".mkv", ".avi", ".mov", ".m4v", ".webm", ".ts", ".mts", ".m2ts", ".flv", ".wmv")

function Format-FileSize {
    param ([long]$size)
    if ($size -ge 1GB) { return "{0:N2} GB" -f ($size / 1GB) }
    if ($size -ge 1MB) { return "{0:N2} MB" -f ($size / 1MB) }
    if ($size -ge 1KB) { return "{0:N2} KB" -f ($size / 1KB) }
    return "$size Bytes"
}

# === LOG MANAGEMENT FUNCTIONS ===
function Save-Log {
    param (
        [string]$SourceLog,
        [string]$VideoBaseName,
        [string]$LogType,
        [int]$Iteration
    )
    
    if (-not $enableLogs) { return }
    if (-not (Test-Path $SourceLog)) { return }
    
    try {
        if (-not (Test-Path $logsFolder)) {
            New-Item -ItemType Directory -Path $logsFolder | Out-Null
        }
        
        $destName = "${VideoBaseName}_${LogType}_iter${Iteration}.log"
        $destPath = Join-Path $logsFolder $destName
        
        Copy-Item -Path $SourceLog -Destination $destPath -Force
        Write-Host "  -> Log saved: $destName" -ForegroundColor DarkGray
    } catch {
        Write-Host "  -> Failed to save log: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Clear-Logs {
    Clear-Host
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "              CLEAR LOGS                                        " -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    if (-not (Test-Path $logsFolder)) {
        Write-Host "Logs folder does not exist. Nothing to clear." -ForegroundColor Yellow
        Write-Host "`nPress any key to continue..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }
    
    $logFiles = Get-ChildItem -Path $logsFolder -File -ErrorAction SilentlyContinue
    $totalSize = ($logFiles | Measure-Object -Property Length -Sum).Sum
    $totalSizeFormatted = Format-FileSize $totalSize
    
    Write-Host "Logs folder: $logsFolder" -ForegroundColor Gray
    Write-Host "Log files found: $($logFiles.Count)" -ForegroundColor White
    Write-Host "Total size: $totalSizeFormatted" -ForegroundColor White
    Write-Host ""
    
    if ($logFiles.Count -eq 0) {
        Write-Host "No log files to delete." -ForegroundColor Yellow
    } else {
        Write-Host "Are you sure you want to delete ALL log files?" -ForegroundColor Yellow
        $answer = Read-Host "Type 'YES' to confirm or anything else to cancel"
        
        if ($answer -eq 'YES') {
            try {
                Remove-Item -Path "$logsFolder\*" -Force -Recurse
                Write-Host "All logs deleted successfully!" -ForegroundColor Green
            } catch {
                Write-Host "Failed to delete logs: $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
        }
    }
    
    Write-Host "`nPress any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Open-LogsFolder {
    if (-not (Test-Path $logsFolder)) {
        try {
            New-Item -ItemType Directory -Path $logsFolder | Out-Null
            Write-Host "Created logs folder: $logsFolder" -ForegroundColor Green
        } catch {
            Write-Host "Failed to create logs folder: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "`nPress any key to continue..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            return
        }
    }
    
    try {
        Start-Process "explorer.exe" -ArgumentList $logsFolder
        Write-Host "Opened logs folder in Explorer." -ForegroundColor Green
    } catch {
        Write-Host "Failed to open folder: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host "`nPress any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Toggle-Logs {
    $script:enableLogs = -not $script:enableLogs
    if ($script:enableLogs) {
        Write-Host "Log saving ENABLED" -ForegroundColor Green
        Write-Host "Logs will be saved to: $logsFolder" -ForegroundColor Gray
    } else {
        Write-Host "Log saving DISABLED" -ForegroundColor Yellow
    }
    Write-Host "`nPress any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# === HARDWARE DETECTION ===
function Detect-Hardware {
    Write-Host "Detecting hardware..." -ForegroundColor Cyan
    
    try {
        $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1
        $script:detectedCPU = $cpu.Name.Trim()
        $script:detectedCPUCores = $cpu.NumberOfCores
        $script:detectedCPUThreads = $cpu.NumberOfLogicalProcessors
        Write-Host "  CPU: $detectedCPU ($detectedCPUCores cores / $detectedCPUThreads threads)" -ForegroundColor Green
    } catch {
        Write-Host "  CPU: Detection failed" -ForegroundColor Red
    }
    
    try {
        $ram = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop).TotalPhysicalMemory
        $script:detectedRAM = [math]::Round($ram / 1GB, 1)
        Write-Host "  RAM: $detectedRAM GB" -ForegroundColor Green
    } catch {
        Write-Host "  RAM: Detection failed" -ForegroundColor Red
    }
    
    try {
        $allGPUs = Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop
        $script:detectedGPUList = @($allGPUs | ForEach-Object { $_.Name.Trim() })
        
        Write-Host "  Found $($detectedGPUList.Count) GPU(s):" -ForegroundColor Green
        $gpuIndex = 1
        foreach ($gpu in $detectedGPUList) {
            Write-Host "    $gpuIndex. $gpu" -ForegroundColor White
            $gpuIndex++
        }
        
        $script:detectedGPU = Select-BestGPU
        Write-Host ""
        Write-Host "  Selected GPU for encoding: $detectedGPU" -ForegroundColor Cyan
    } catch {
        Write-Host "  GPU: Detection failed" -ForegroundColor Red
    }
}

function Select-BestGPU {
    if ($detectedGPUList.Count -eq 0) { return "Unknown" }
    if ($detectedGPUList.Count -eq 1) { return $detectedGPUList[0] }
    
    $gpuScores = @()
    foreach ($gpu in $detectedGPUList) {
        $gpuLower = $gpu.ToLower()
        $score = 0
        
        if ($gpuLower -match "nvidia|geforce|rtx|gtx") {
            if ($gpuLower -match "rtx 50|rtx 40") { $score = 100 }
            elseif ($gpuLower -match "rtx 30") { $score = 90 }
            elseif ($gpuLower -match "rtx 20|gtx 16") { $score = 80 }
            elseif ($gpuLower -match "gtx 10") { $score = 70 }
            else { $score = 60 }
        }
        elseif ($gpuLower -match "amd|radeon") {
            if ($gpuLower -match "rx 7|rx 9") { $score = 95 }
            elseif ($gpuLower -match "rx 6") { $score = 85 }
            elseif ($gpuLower -match "rx 5") { $score = 75 }
            else { $score = 65 }
        }
        elseif ($gpuLower -match "intel") {
            if ($gpuLower -match "arc") { $score = 88 }
            elseif ($gpuLower -match "iris xe|uhd 7|uhd 6") { $score = 40 }
            else { $score = 30 }
        }
        else {
            $score = 50
        }
        
        $gpuScores += @{ Name = $gpu; Score = $score }
    }
    
    $bestGPU = $gpuScores | Sort-Object { $_.Score } -Descending | Select-Object -First 1
    return $bestGPU.Name
}

function Analyze-GPU {
    $gpuLower = $detectedGPU.ToLower()
    
    if ($gpuLower -match "nvidia|geforce|rtx|gtx|quadro") {
        if ($gpuLower -match "rtx 50|rtx 40") {
            return @{ Device = "NVIDIA"; Series = "nvidia_ada"; HasAV1 = $true }
        } elseif ($gpuLower -match "rtx 30") {
            return @{ Device = "NVIDIA"; Series = "nvidia_ampere"; HasAV1 = $false }
        } elseif ($gpuLower -match "rtx 20|gtx 16") {
            return @{ Device = "NVIDIA"; Series = "nvidia_turing"; HasAV1 = $false }
        } elseif ($gpuLower -match "gtx 10|gtx 9") {
            return @{ Device = "NVIDIA"; Series = "nvidia_pascal"; HasAV1 = $false }
        } else {
            return @{ Device = "NVIDIA"; Series = "nvidia_old"; HasAV1 = $false }
        }
    }
    
    if ($gpuLower -match "amd|radeon") {
        if ($gpuLower -match "rx 7|rx 9") {
            return @{ Device = "AMD"; Series = "amd_rdna3"; HasAV1 = $true }
        } elseif ($gpuLower -match "rx 6") {
            return @{ Device = "AMD"; Series = "amd_rdna2"; HasAV1 = $false }
        } elseif ($gpuLower -match "rx 5") {
            return @{ Device = "AMD"; Series = "amd_rdna1"; HasAV1 = $false }
        } else {
            return @{ Device = "AMD"; Series = "amd_old"; HasAV1 = $false }
        }
    }
    
    if ($gpuLower -match "intel") {
        if ($gpuLower -match "arc") {
            return @{ Device = "Intel"; Series = "intel_arc"; HasAV1 = $true }
        } elseif ($gpuLower -match "iris xe|uhd 7|uhd 6") {
            return @{ Device = "Intel"; Series = "intel_11gen"; HasAV1 = $false }
        } else {
            return @{ Device = "Intel"; Series = "intel_old"; HasAV1 = $false }
        }
    }
    
    return @{ Device = "Unknown"; Series = "unknown"; HasAV1 = $false }
}

function Apply-OptimalSettings {
    Clear-Host
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "              AUTO-DETECTING HARDWARE                           " -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    Detect-Hardware
    Write-Host ""
    
    $gpuInfo = Analyze-GPU
    Write-Host "Analyzing optimal settings..." -ForegroundColor Yellow
    Write-Host ""
    
    $useGPU = $false
    $reason = ""
    
    if ($gpuInfo.Device -ne "Unknown" -and $gpuInfo.Series -notmatch "old|pascal") {
        $useGPU = $true
        
        if ($detectedCPUCores -ge 8 -and $gpuInfo.Series -match "turing|rdna1|intel_11gen") {
            $useGPU = $false
            $reason = "Powerful CPU ($detectedCPUCores cores) detected. CPU encoding will give better quality."
        } else {
            $reason = "Modern GPU detected. GPU encoding is 5-20x faster with good quality."
        }
    } else {
        $reason = "No modern GPU detected or GPU too old. Using CPU for best quality."
    }
    
    $recDevice = ""
    $recSeries = ""
    $recCodec = ""
    $recCRF = 0
    $recPreset = ""
    
    if ($useGPU) {
        $recDevice = $gpuInfo.Device
        $recSeries = $gpuInfo.Series
        
        if ($gpuInfo.HasAV1) {
            $recCodec = "av1"
            $recCRF = 28
            Write-Host "Recommended: GPU + AV1 (best compression)" -ForegroundColor Green
        } else {
            $recCodec = "h265"
            $recCRF = 24
            Write-Host "Recommended: GPU + H.265 (good compression)" -ForegroundColor Green
        }
        $recPreset = "balanced"
    } else {
        $recDevice = "CPU"
        $recSeries = "none"
        
        if ($detectedCPUCores -ge 8 -and $detectedRAM -ge 16) {
            $recCodec = "av1"
            $recCRF = 28
            $recPreset = "quality"
            Write-Host "Recommended: CPU + AV1 (best quality, needs powerful CPU)" -ForegroundColor Green
        } else {
            $recCodec = "h265"
            $recCRF = 23
            $recPreset = "balanced"
            Write-Host "Recommended: CPU + H.265 (good balance)" -ForegroundColor Green
        }
    }
    
    Write-Host ""
    Write-Host "Reason: $reason" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Recommended settings:" -ForegroundColor Yellow
    Write-Host "  Device: $recDevice" -ForegroundColor White
    Write-Host "  GPU Series: $recSeries" -ForegroundColor White
    Write-Host "  Codec: $recCodec" -ForegroundColor White
    Write-Host "  Quality: $recCRF" -ForegroundColor White
    Write-Host "  Preset: $recPreset" -ForegroundColor White
    Write-Host ""
    Write-Host "Current settings:" -ForegroundColor Yellow
    Write-Host "  Device: $hwDevice" -ForegroundColor White
    Write-Host "  GPU Series: $gpuSeries" -ForegroundColor White
    Write-Host "  Codec: $codec" -ForegroundColor White
    Write-Host "  Quality: $crfValue" -ForegroundColor White
    Write-Host "  Preset: $qualityPreset" -ForegroundColor White
    Write-Host ""
    Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
    
    $answer = Read-Host "Apply recommended settings? (Y/N)"
    
    if ($answer -eq 'Y' -or $answer -eq 'y') {
        $script:hwDevice = $recDevice
        $script:gpuSeries = $recSeries
        $script:codec = $recCodec
        $script:crfValue = $recCRF
        $script:qualityPreset = $recPreset
        
        Write-Host ""
        Write-Host "Recommended settings applied!" -ForegroundColor Green
        Write-Host "You can fine-tune these settings in the main menu." -ForegroundColor Gray
    } else {
        Write-Host ""
        Write-Host "Settings not changed. Current settings preserved." -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Cyan
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Get-SupportedCodecs {
    switch ($gpuSeries) {
        "nvidia_turing" { return @("h264", "h265") }
        "nvidia_ampere" { return @("h264", "h265") }
        "nvidia_ada" { return @("h264", "h265", "av1") }
        "amd_rdna1" { return @("h264", "h265") }
        "amd_rdna2" { return @("h264", "h265") }
        "amd_rdna3" { return @("h264", "h265", "av1") }
        "intel_11gen" { return @("h264", "h265") }
        "intel_arc" { return @("h264", "h265", "av1") }
        default { return @("h264", "h265", "av1") }
    }
}

function Get-HardwareDescription {
    $deviceDesc = switch ($hwDevice) {
        "CPU" { "CPU (Software)" }
        "NVIDIA" { "NVIDIA GPU" }
        "AMD" { "AMD GPU" }
        "Intel" { "Intel GPU" }
    }
    $seriesDesc = switch ($gpuSeries) {
        "none" { "" }
        "nvidia_turing" { "Turing (16xx/20xx)" }
        "nvidia_ampere" { "Ampere (30xx)" }
        "nvidia_ada" { "Ada/Blackwell (40xx/50xx)" }
        "amd_rdna1" { "RDNA 1 (RX 5000)" }
        "amd_rdna2" { "RDNA 2 (RX 6000)" }
        "amd_rdna3" { "RDNA 3 (RX 7000+)" }
        "intel_11gen" { "11th Gen+" }
        "intel_arc" { "Arc" }
    }
    $codecDesc = switch ($codec) {
        "h264" { "H.264" }
        "h265" { "H.265/HEVC" }
        "av1" { "AV1" }
    }
    $presetDesc = switch ($qualityPreset) {
        "fast" { "Fast" }
        "balanced" { "Balanced" }
        "quality" { "Quality" }
        "max" { "Max Quality" }
    }
    
    if ($hwDevice -eq "CPU") {
        return "$deviceDesc | $codecDesc | $presetDesc"
    } else {
        return "$deviceDesc ($seriesDesc) | $codecDesc | $presetDesc"
    }
}

function Build-VideoArgs {
    param ([int]$quality)
    
    if ($hwDevice -eq "CPU") {
        $encoder = switch ($codec) {
            "h264" { "libx264" }
            "h265" { "libx265" }
            "av1" { "libsvtav1" }
        }
        
        $presetArg = switch ($qualityPreset) {
            "fast" { 
                if ($codec -eq "av1") { "8" } else { "veryfast" }
            }
            "balanced" { 
                if ($codec -eq "av1") { "6" } else { "medium" }
            }
            "quality" { 
                if ($codec -eq "av1") { "4" } else { "slow" }
            }
            "max" { 
                if ($codec -eq "av1") { "2" } else { "veryslow" }
            }
        }
        
        return "-c:v $encoder -crf $quality -preset $presetArg"
    }
    
    if ($hwDevice -eq "NVIDIA") {
        $encoder = switch ($codec) {
            "h264" { "h264_nvenc" }
            "h265" { "hevc_nvenc" }
            "av1" { "av1_nvenc" }
        }
        
        $presetArg = switch ($qualityPreset) {
            "fast" { "p1" }
            "balanced" { "p4" }
            "quality" { "p6" }
            "max" { "p7" }
        }
        
        $tuneArg = ""
        if ($gpuSeries -eq "nvidia_ada" -and $codec -eq "av1") {
            if ($qualityPreset -eq "max") { $tuneArg = "-tune uhq" }
            else { $tuneArg = "-tune hq" }
        } elseif ($codec -eq "h265") {
            $tuneArg = "-tune hq"
        }
        
        return "-c:v $encoder -preset $presetArg -rc vbr -cq $quality $tuneArg".Trim()
    }
    
    if ($hwDevice -eq "AMD") {
        $encoder = switch ($codec) {
            "h264" { "h264_amf" }
            "h265" { "hevc_amf" }
            "av1" { "av1_amf" }
        }
        
        $presetArg = switch ($qualityPreset) {
            "fast" { "speed" }
            "balanced" { "balanced" }
            "quality" { "quality" }
            "max" { "quality" }
        }
        
        return "-c:v $encoder -quality $presetArg -rc cqp -qp-i $quality -qp-p $quality -qp-b $quality"
    }
    
    if ($hwDevice -eq "Intel") {
        $encoder = switch ($codec) {
            "h264" { "h264_qsv" }
            "h265" { "hevc_qsv" }
            "av1" { "av1_qsv" }
        }
        
        $presetArg = switch ($qualityPreset) {
            "fast" { "veryfast" }
            "balanced" { "balanced" }
            "quality" { "slow" }
            "max" { "veryslow" }
        }
        
        return "-c:v $encoder -preset $presetArg -global_quality $quality"
    }
    
    return "-c:v libx264 -crf $quality -preset medium"
}

function Get-VideoFiles {
    $allFiles = Get-ChildItem -Path $inputFolder -File -Recurse:$enableRecursiveSearch -ErrorAction SilentlyContinue
    $files = @($allFiles | Where-Object {
        $isVideo = $extensions -contains $_.Extension.ToLower()
        $isAllowed = $true
        if ($isVideo) {
            $pathParts = $_.DirectoryName.Split('\')
            foreach ($part in $pathParts) {
                if ($excludedFolders -contains $part.ToLower()) {
                    $isAllowed = $false
                    break
                }
            }
        }
        return ($isVideo -and $isAllowed)
    })
    return $files
}

function Get-VideoFilesCount {
    return (Get-VideoFiles).Count
}

function Select-InputFolder {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select folder with video files"
    $dialog.ShowNewFolderButton = $false
    $dialog.SelectedPath = $inputFolder
    if ($dialog.ShowDialog() -eq 'OK') {
        $script:inputFolder = $dialog.SelectedPath
        $script:outputFolder = Join-Path $script:inputFolder "compressed"
        $script:logsFolder = Join-Path $script:inputFolder "logs"
        Write-Host "Input folder changed to: $script:inputFolder" -ForegroundColor Green
    }
    Write-Host "`nPress any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Toggle-RecursiveSearch {
    $script:enableRecursiveSearch = -not $script:enableRecursiveSearch
    if ($script:enableRecursiveSearch) {
        Write-Host "Recursive search ENABLED" -ForegroundColor Green
        Write-Host "Excluded folders: $($excludedFolders -join ', ')" -ForegroundColor Gray
    } else {
        Write-Host "Recursive search DISABLED" -ForegroundColor Yellow
    }
    Write-Host "`nPress any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Show-HardwareMenu {
    do {
        Clear-Host
        Write-Host "================================================================" -ForegroundColor Cyan
        Write-Host "              HARDWARE ACCELERATION SETTINGS                    " -ForegroundColor Cyan
        Write-Host "================================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Current configuration:" -ForegroundColor Yellow
        Write-Host "  $(Get-HardwareDescription)" -ForegroundColor White
        Write-Host ""
        Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
        Write-Host "  1. Change device (current: $hwDevice)" -ForegroundColor White
        Write-Host "  2. Change GPU series (current: $gpuSeries)" -ForegroundColor White
        Write-Host "  3. Change codec (current: $codec)" -ForegroundColor White
        Write-Host "  4. Change quality preset (current: $qualityPreset)" -ForegroundColor White
        Write-Host "  5. Back to main menu" -ForegroundColor Yellow
        Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
        Write-Host ""
        
        $choice = Read-Host "Enter your choice (1-5)"
        
        switch ($choice) {
            '1' {
                Clear-Host
                Write-Host "================================================================" -ForegroundColor Cyan
                Write-Host "              SELECT DEVICE                                       " -ForegroundColor Cyan
                Write-Host "================================================================" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "  1. CPU (Software encoding - slow, best quality)" -ForegroundColor White
                Write-Host "  2. NVIDIA GPU (NVENC - fast, good quality)" -ForegroundColor White
                Write-Host "  3. AMD GPU (AMF - fast, good quality)" -ForegroundColor White
                Write-Host "  4. Intel GPU (QSV - fast, good quality)" -ForegroundColor White
                Write-Host "  5. Back" -ForegroundColor Yellow
                Write-Host ""
                $devChoice = Read-Host "Enter your choice"
                switch ($devChoice) {
                    '1' { $script:hwDevice = "CPU"; $script:gpuSeries = "none"; Write-Host "Device set to CPU" -ForegroundColor Green }
                    '2' { $script:hwDevice = "NVIDIA"; Write-Host "Device set to NVIDIA. Please select GPU series." -ForegroundColor Green }
                    '3' { $script:hwDevice = "AMD"; Write-Host "Device set to AMD. Please select GPU series." -ForegroundColor Green }
                    '4' { $script:hwDevice = "Intel"; Write-Host "Device set to Intel. Please select GPU series." -ForegroundColor Green }
                }
                Write-Host "`nPress any key to continue..."
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            '2' {
                Clear-Host
                Write-Host "================================================================" -ForegroundColor Cyan
                Write-Host "              SELECT GPU SERIES                                 " -ForegroundColor Cyan
                Write-Host "================================================================" -ForegroundColor Cyan
                Write-Host ""
                
                if ($hwDevice -eq "CPU") {
                    Write-Host "CPU selected - no GPU series needed" -ForegroundColor Yellow
                } elseif ($hwDevice -eq "NVIDIA") {
                    Write-Host "  1. Turing (GTX 16xx, RTX 20xx)" -ForegroundColor White
                    Write-Host "  2. Ampere (RTX 30xx)" -ForegroundColor White
                    Write-Host "  3. Ada Lovelace / Blackwell (RTX 40xx, 50xx) - supports AV1" -ForegroundColor Green
                    Write-Host "  4. Back" -ForegroundColor Yellow
                    Write-Host ""
                    $seriesChoice = Read-Host "Enter your choice"
                    switch ($seriesChoice) {
                        '1' { $script:gpuSeries = "nvidia_turing"; Write-Host "Series set to Turing" -ForegroundColor Green }
                        '2' { $script:gpuSeries = "nvidia_ampere"; Write-Host "Series set to Ampere" -ForegroundColor Green }
                        '3' { $script:gpuSeries = "nvidia_ada"; Write-Host "Series set to Ada/Blackwell (AV1 supported)" -ForegroundColor Green }
                    }
                } elseif ($hwDevice -eq "AMD") {
                    Write-Host "  1. RDNA 1 (Radeon RX 5000 series)" -ForegroundColor White
                    Write-Host "  2. RDNA 2 (Radeon RX 6000 series)" -ForegroundColor White
                    Write-Host "  3. RDNA 3 (Radeon RX 7000+ series) - supports AV1" -ForegroundColor Green
                    Write-Host "  4. Back" -ForegroundColor Yellow
                    Write-Host ""
                    $seriesChoice = Read-Host "Enter your choice"
                    switch ($seriesChoice) {
                        '1' { $script:gpuSeries = "amd_rdna1"; Write-Host "Series set to RDNA 1" -ForegroundColor Green }
                        '2' { $script:gpuSeries = "amd_rdna2"; Write-Host "Series set to RDNA 2" -ForegroundColor Green }
                        '3' { $script:gpuSeries = "amd_rdna3"; Write-Host "Series set to RDNA 3 (AV1 supported)" -ForegroundColor Green }
                    }
                } elseif ($hwDevice -eq "Intel") {
                    Write-Host "  1. 11th Gen+ (Integrated graphics)" -ForegroundColor White
                    Write-Host "  2. Arc (A380, A750, A770) - supports AV1" -ForegroundColor Green
                    Write-Host "  3. Back" -ForegroundColor Yellow
                    Write-Host ""
                    $seriesChoice = Read-Host "Enter your choice"
                    switch ($seriesChoice) {
                        '1' { $script:gpuSeries = "intel_11gen"; Write-Host "Series set to 11th Gen+" -ForegroundColor Green }
                        '2' { $script:gpuSeries = "intel_arc"; Write-Host "Series set to Arc (AV1 supported)" -ForegroundColor Green }
                    }
                }
                Write-Host "`nPress any key to continue..."
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            '3' {
                Clear-Host
                Write-Host "================================================================" -ForegroundColor Cyan
                Write-Host "              SELECT CODEC                                      " -ForegroundColor Cyan
                Write-Host "================================================================" -ForegroundColor Cyan
                Write-Host ""
                $supported = Get-SupportedCodecs
                Write-Host "Supported codecs for current hardware:" -ForegroundColor Yellow
                $i = 1
                foreach ($c in $supported) {
                    $desc = switch ($c) {
                        "h264" { "H.264 (best compatibility)" }
                        "h265" { "H.265/HEVC (better compression)" }
                        "av1" { "AV1 (best compression, newest)" }
                    }
                    Write-Host "  $i. $desc" -ForegroundColor White
                    $i++
                }
                Write-Host "  $($supported.Count + 1). Back" -ForegroundColor Yellow
                Write-Host ""
                $codecChoice = Read-Host "Enter your choice"
                if ($codecChoice -match '^\d+$') {
                    $idx = [int]$codecChoice - 1
                    if ($idx -ge 0 -and $idx -lt $supported.Count) {
                        $script:codec = $supported[$idx]
                        Write-Host "Codec set to $script:codec" -ForegroundColor Green
                    }
                }
                Write-Host "`nPress any key to continue..."
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            '4' {
                Clear-Host
                Write-Host "================================================================" -ForegroundColor Cyan
                Write-Host "              SELECT QUALITY PRESET                             " -ForegroundColor Cyan
                Write-Host "================================================================" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "  1. Fast (fastest encoding, larger files)" -ForegroundColor White
                Write-Host "  2. Balanced (recommended)" -ForegroundColor Green
                Write-Host "  3. Quality (slower, better compression)" -ForegroundColor White
                Write-Host "  4. Max Quality (slowest, smallest files)" -ForegroundColor White
                Write-Host "  5. Back" -ForegroundColor Yellow
                Write-Host ""
                $presetChoice = Read-Host "Enter your choice"
                switch ($presetChoice) {
                    '1' { $script:qualityPreset = "fast"; Write-Host "Preset set to Fast" -ForegroundColor Green }
                    '2' { $script:qualityPreset = "balanced"; Write-Host "Preset set to Balanced" -ForegroundColor Green }
                    '3' { $script:qualityPreset = "quality"; Write-Host "Preset set to Quality" -ForegroundColor Green }
                    '4' { $script:qualityPreset = "max"; Write-Host "Preset set to Max Quality" -ForegroundColor Green }
                }
                Write-Host "`nPress any key to continue..."
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            '5' { return }
        }
    } while ($true)
}

function Show-Menu {
    Clear-Host
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "              VIDEO COMPRESSION UTILITY                         " -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    $fileCount = Get-VideoFilesCount
    Write-Host "Input folder: $inputFolder" -ForegroundColor Gray
    Write-Host "Video files found: " -NoNewline -ForegroundColor Gray
    if ($fileCount -gt 0) { Write-Host "$fileCount" -ForegroundColor Green } else { Write-Host "$fileCount" -ForegroundColor Red }
    Write-Host "Excluded folders: " -NoNewline -ForegroundColor Gray
    Write-Host "$($excludedFolders -join ', ')" -ForegroundColor DarkGray
    Write-Host "Settings file: " -NoNewline -ForegroundColor Gray
    Write-Host "$settingsFile" -ForegroundColor DarkGray
    Write-Host "Presets file: " -NoNewline -ForegroundColor Gray
    Write-Host "$presetsFile" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Hardware configuration:" -ForegroundColor Yellow
    Write-Host "  $(Get-HardwareDescription)" -ForegroundColor White
    Write-Host "  Quality (CRF/CQ): $crfValue" -ForegroundColor White
    Write-Host ""
    Write-Host "Search settings:" -ForegroundColor Yellow
    Write-Host "  - Recursive search: " -NoNewline -ForegroundColor Gray
    if ($enableRecursiveSearch) { Write-Host "ON" -ForegroundColor Green } else { Write-Host "OFF" -ForegroundColor Yellow }
    Write-Host ""
    Write-Host "VMAF & Auto CRF settings:" -ForegroundColor Yellow
    Write-Host "  - VMAF: " -NoNewline -ForegroundColor Gray
    if ($enableVMAF) { Write-Host "Enabled" -ForegroundColor Green } else { Write-Host "Disabled" -ForegroundColor Red }
    Write-Host "  - Auto CRF: " -NoNewline -ForegroundColor Gray
    if ($enableAutoCRF) { Write-Host "Enabled (threshold: $vmafThreshold)" -ForegroundColor Green } else { Write-Host "Disabled" -ForegroundColor Red }
    Write-Host ""
    Write-Host "Logs:" -ForegroundColor Yellow
    Write-Host "  - Save logs: " -NoNewline -ForegroundColor Gray
    if ($enableLogs) { Write-Host "Enabled" -ForegroundColor Green } else { Write-Host "Disabled" -ForegroundColor Red }
    Write-Host ""
    Write-Host "Presets:" -ForegroundColor Yellow
    Write-Host "  - Saved presets: " -NoNewline -ForegroundColor Gray
    Write-Host "$($presets.Count)" -ForegroundColor White
    Write-Host ""
    Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "  1. Change input folder" -ForegroundColor White
    Write-Host "  2. Toggle recursive search (current: $(if ($enableRecursiveSearch) { 'ON' } else { 'OFF' }))" -ForegroundColor White
    Write-Host "  H. Hardware Acceleration (device/codec/preset)" -ForegroundColor Cyan
    Write-Host "  D. Auto-detect hardware and apply optimal settings" -ForegroundColor Green
    Write-Host "  P. Presets management (save/load/delete)" -ForegroundColor Magenta
    Write-Host "  Q. Change quality value (current: $crfValue)" -ForegroundColor White
    Write-Host "  V. Toggle VMAF calculation (current: $(if ($enableVMAF) { 'ON' } else { 'OFF' }))" -ForegroundColor White
    Write-Host "  A. Toggle Auto CRF adjustment (current: $(if ($enableAutoCRF) { 'ON' } else { 'OFF' }))" -ForegroundColor White
    Write-Host "  T. Change VMAF threshold (current: $vmafThreshold)" -ForegroundColor White
    Write-Host "  I. Change max iterations (current: $maxIterations)" -ForegroundColor White
    Write-Host "  M. Change minimum CRF (current: $minCRF)" -ForegroundColor White
    Write-Host "  L. Logs management (open/clear/toggle)" -ForegroundColor Magenta
    Write-Host "  S. Save settings now" -ForegroundColor Yellow
    Write-Host "  0. Start compression (press ESC to cancel)" -ForegroundColor Green
    Write-Host "  X. Exit (settings will be saved)" -ForegroundColor Red
    Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host ""
}

function Show-LogsMenu {
    do {
        Clear-Host
        Write-Host "================================================================" -ForegroundColor Cyan
        Write-Host "              LOGS MANAGEMENT                                   " -ForegroundColor Cyan
        Write-Host "================================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Logs folder: $logsFolder" -ForegroundColor Gray
        Write-Host "Save logs: " -NoNewline -ForegroundColor Gray
        if ($enableLogs) { Write-Host "ENABLED" -ForegroundColor Green } else { Write-Host "DISABLED" -ForegroundColor Red }
        Write-Host ""
        
        $logCount = 0
        $totalSize = 0
        if (Test-Path $logsFolder) {
            $logFiles = Get-ChildItem -Path $logsFolder -File -ErrorAction SilentlyContinue
            $logCount = $logFiles.Count
            $totalSize = ($logFiles | Measure-Object -Property Length -Sum).Sum
        }
        $totalSizeFormatted = Format-FileSize $totalSize
        
        Write-Host "Current logs:" -ForegroundColor Yellow
        Write-Host "  Files: $logCount" -ForegroundColor White
        Write-Host "  Total size: $totalSizeFormatted" -ForegroundColor White
        Write-Host ""
        Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
        Write-Host "  1. Open logs folder in Explorer" -ForegroundColor White
        Write-Host "  2. Clear all logs" -ForegroundColor Red
        Write-Host "  3. Toggle log saving (current: $(if ($enableLogs) { 'ON' } else { 'OFF' }))" -ForegroundColor White
        Write-Host "  4. Back to main menu" -ForegroundColor Yellow
        Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
        Write-Host ""
        
        $choice = Read-Host "Enter your choice (1-4)"
        
        switch ($choice) {
            '1' { Open-LogsFolder }
            '2' { Clear-Logs }
            '3' { Toggle-Logs }
            '4' { return }
            default {
                Write-Host "`nInvalid choice." -ForegroundColor Red
                Write-Host "Press any key to continue..."
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
        }
    } while ($true)
}

function Set-CRF {
    Clear-Host
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "              CHANGE QUALITY VALUE                              " -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Current value: $crfValue" -ForegroundColor Yellow
    Write-Host ""
    if ($hwDevice -eq "CPU") {
        Write-Host "This is CRF (Constant Rate Factor) for CPU encoding" -ForegroundColor Gray
    } elseif ($hwDevice -eq "NVIDIA") {
        Write-Host "This is CQ (Constant Quality) for NVENC encoding" -ForegroundColor Gray
    } elseif ($hwDevice -eq "AMD") {
        Write-Host "This is QP (Quantization Parameter) for AMF encoding" -ForegroundColor Gray
    } elseif ($hwDevice -eq "Intel") {
        Write-Host "This is Global Quality for QSV encoding" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "Scale (lower = better quality, larger file):" -ForegroundColor Gray
    Write-Host "  * 18-20: Visually lossless (large files)" -ForegroundColor White
    Write-Host "  * 23: Default balance (recommended)" -ForegroundColor White
    Write-Host "  * 28-30: Good quality, smaller files" -ForegroundColor White
    Write-Host "  * 35+: Lower quality, very small files" -ForegroundColor White
    Write-Host ""
    Write-Host "Enter new value (0-51, or 'b' to go back): " -NoNewline -ForegroundColor Cyan
    $inputValue = Read-Host
    if ($inputValue -eq 'b' -or $inputValue -eq 'B') { return }
    if ($inputValue -match '^\d+$') {
        $newVal = [int]$inputValue
        if ($newVal -ge 0 -and $newVal -le 51) {
            $script:crfValue = $newVal
            Write-Host "Quality value changed to $newVal" -ForegroundColor Green
        } else {
            Write-Host "Invalid value. Must be between 0 and 51" -ForegroundColor Red
        }
    } else {
        Write-Host "Invalid input. Please enter a number" -ForegroundColor Red
    }
    Write-Host "`nPress any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Toggle-VMAF {
    $script:enableVMAF = -not $script:enableVMAF
    if ($script:enableVMAF) {
        Write-Host "VMAF calculation enabled" -ForegroundColor Green
    } else {
        Write-Host "VMAF calculation disabled" -ForegroundColor Red
    }
    Write-Host "`nPress any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Toggle-AutoCRF {
    $script:enableAutoCRF = -not $script:enableAutoCRF
    if ($script:enableAutoCRF) {
        Write-Host "Auto CRF adjustment enabled" -ForegroundColor Green
    } else {
        Write-Host "Auto CRF adjustment disabled" -ForegroundColor Red
    }
    Write-Host "`nPress any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Set-VMAFThreshold {
    Clear-Host
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "              CHANGE VMAF THRESHOLD                             " -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Current threshold: $vmafThreshold" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "If VMAF score is below this value, quality will be increased" -ForegroundColor Gray
    Write-Host "Recommended values: 85-95" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Enter new threshold (0-100, or 'b' to go back): " -NoNewline -ForegroundColor Cyan
    $inputValue = Read-Host
    if ($inputValue -eq 'b' -or $inputValue -eq 'B') { return }
    if ($inputValue -match '^\d+$') {
        $newThreshold = [int]$inputValue
        if ($newThreshold -ge 0 -and $newThreshold -le 100) {
            $script:vmafThreshold = $newThreshold
            Write-Host "VMAF threshold changed to $newThreshold" -ForegroundColor Green
        } else {
            Write-Host "Invalid value. Must be between 0 and 100" -ForegroundColor Red
        }
    } else {
        Write-Host "Invalid input. Please enter a number" -ForegroundColor Red
    }
    Write-Host "`nPress any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Set-MaxIterations {
    Clear-Host
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "              CHANGE MAX ITERATIONS                             " -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Current max iterations: $maxIterations" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Maximum number of quality adjustment attempts per video" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Enter new value (1-10, or 'b' to go back): " -NoNewline -ForegroundColor Cyan
    $inputValue = Read-Host
    if ($inputValue -eq 'b' -or $inputValue -eq 'B') { return }
    if ($inputValue -match '^\d+$') {
        $newMax = [int]$inputValue
        if ($newMax -ge 1 -and $newMax -le 10) {
            $script:maxIterations = $newMax
            Write-Host "Max iterations changed to $newMax" -ForegroundColor Green
        } else {
            Write-Host "Invalid value. Must be between 1 and 10" -ForegroundColor Red
        }
    } else {
        Write-Host "Invalid input. Please enter a number" -ForegroundColor Red
    }
    Write-Host "`nPress any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Set-MinCRF {
    Clear-Host
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "              CHANGE MINIMUM QUALITY                            " -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Current minimum: $minCRF" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Quality will not be increased below this value" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Enter new value (0-51, or 'b' to go back): " -NoNewline -ForegroundColor Cyan
    $inputValue = Read-Host
    if ($inputValue -eq 'b' -or $inputValue -eq 'B') { return }
    if ($inputValue -match '^\d+$') {
        $newMin = [int]$inputValue
        if ($newMin -ge 0 -and $newMin -le 51) {
            $script:minCRF = $newMin
            Write-Host "Minimum quality changed to $newMin" -ForegroundColor Green
        } else {
            Write-Host "Invalid value. Must be between 0 and 51" -ForegroundColor Red
        }
    } else {
        Write-Host "Invalid input. Please enter a number" -ForegroundColor Red
    }
    Write-Host "`nPress any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Start-Compression {
    Clear-Host
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "              STARTING COMPRESSION                              " -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Settings:" -ForegroundColor Yellow
    Write-Host "  - Input folder: $inputFolder" -ForegroundColor White
    Write-Host "  - Output folder: $outputFolder" -ForegroundColor White
    Write-Host "  - Logs folder: $logsFolder" -ForegroundColor White
    Write-Host "  - Hardware: $(Get-HardwareDescription)" -ForegroundColor White
    Write-Host "  - Recursive search: $(if ($enableRecursiveSearch) { 'ON' } else { 'OFF' })" -ForegroundColor White
    Write-Host "  - Save logs: $(if ($enableLogs) { 'Enabled' } else { 'Disabled' })" -ForegroundColor White
    if ($enableVMAF) { Write-Host "  - VMAF: Enabled" -ForegroundColor White } else { Write-Host "  - VMAF: Disabled" -ForegroundColor White }
    if ($enableAutoCRF -and $enableVMAF) {
        Write-Host "  - Auto CRF: Enabled (threshold: $vmafThreshold, max: $maxIterations, min: $minCRF)" -ForegroundColor White
    } else {
        Write-Host "  - Auto CRF: Disabled" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "Press any key to start, 'b' to go back, or 'ESC' to cancel during processing..." -ForegroundColor Cyan
    $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    if ($key.Character -eq 'b' -or $key.Character -eq 'B') { return }

    $originalProgressColor = $Host.PrivateData.ProgressForegroundColor
    $script:cancelRequested = $false

    if (-not (Test-Path $outputFolder)) {
        New-Item -ItemType Directory -Path $outputFolder | Out-Null
        Write-Host "Created folder: $outputFolder" -ForegroundColor Gray
    }
    
    if ($enableLogs -and -not (Test-Path $logsFolder)) {
        New-Item -ItemType Directory -Path $logsFolder | Out-Null
        Write-Host "Created logs folder: $logsFolder" -ForegroundColor Gray
    }

    $files = Get-VideoFiles

    if ($files.Count -eq 0) {
        Write-Host "Error: No video files found in $inputFolder" -ForegroundColor Red
        Write-Host "`nPress any key to continue..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }

    Write-Host "Files found: $($files.Count). Starting compression..." -ForegroundColor Cyan
    Write-Host "Press ESC during processing to cancel..." -ForegroundColor Yellow
    Write-Host "---------------------------------------------------"

    $counter = 1
    foreach ($file in $files) {
        if ($script:cancelRequested) {
            Write-Host "`n!!! CANCELLATION REQUESTED !!!" -ForegroundColor Red
            Write-Host "Skipping remaining files..." -ForegroundColor Yellow
            break
        }

        $inputFile = $file.FullName

        if ($enableRecursiveSearch) {
            $relativePath = $inputFile.Substring($inputFolder.Length).TrimStart('\')
            $relativeDir = Split-Path $relativePath -Parent
            if ($relativeDir) {
                $outputSubDir = Join-Path $outputFolder $relativeDir
                if (-not (Test-Path $outputSubDir)) {
                    New-Item -ItemType Directory -Path $outputSubDir -Force | Out-Null
                }
                $outputFile = Join-Path $outputSubDir "$($file.BaseName)_compressed.mp4"
            } else {
                $outputFile = Join-Path $outputFolder "$($file.BaseName)_compressed.mp4"
            }
        } else {
            $outputFile = Join-Path $outputFolder "$($file.BaseName)_compressed.mp4"
        }

        $sizeBefore = $file.Length
        $sizeBeforeFormatted = Format-FileSize $sizeBefore

        if ($enableRecursiveSearch) {
            $relativePath = $inputFile.Substring($inputFolder.Length).TrimStart('\')
            Write-Host "`n[$counter/$($files.Count)] Processing: $relativePath" -ForegroundColor Yellow
        } else {
            Write-Host "`n[$counter/$($files.Count)] Processing: $($file.Name)" -ForegroundColor Yellow
        }
        Write-Host "  Initial size: $sizeBeforeFormatted" -ForegroundColor Gray

        $totalDuration = 0
        try {
            $probeOutput = & ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$inputFile" 2>$null
            if ($probeOutput) { $totalDuration = [double]$probeOutput }
        } catch {}

        $currentCRF = $crfValue
        $iteration = 0
        $needsRecompression = $true

        while ($needsRecompression) {
            $iteration++
            
            if ($iteration -gt 1) {
                Write-Host "  -> Iteration $iteration (Quality: $currentCRF)" -ForegroundColor Magenta
            }

            $logFile = Join-Path $env:TEMP "ffmpeg_log_$($file.BaseName)_iter$iteration.txt"
            if (Test-Path $logFile) { Remove-Item $logFile -Force }

            $videoArgs = Build-VideoArgs -quality $currentCRF
            $ffmpegArgs = "-i `"$inputFile`" $videoArgs -c:a aac -b:a 128k -y `"$outputFile`""

            $Host.PrivateData.ProgressForegroundColor = "Yellow"

            $process = Start-Process -FilePath "ffmpeg" -ArgumentList $ffmpegArgs -RedirectStandardError $logFile -PassThru -NoNewWindow
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            while (!$process.HasExited) {
                if ([System.Console]::KeyAvailable) {
                    $key = [System.Console]::ReadKey($true)
                    if ($key.Key -eq [System.ConsoleKey]::Escape) {
                        $script:cancelRequested = $true
                        Write-Host "`n  !!! CANCELLATION REQUESTED !!!" -ForegroundColor Red
                        Write-Host "  Stopping ffmpeg process..." -ForegroundColor Yellow
                        
                        try {
                            if (!$process.HasExited) {
                                $process.Kill()
                                $process.WaitForExit(5000)
                            }
                        } catch {}
                        
                        Save-Log -SourceLog $logFile -VideoBaseName $file.BaseName -LogType "compress" -Iteration $iteration
                        
                        Write-Host "  Cleaning up incomplete files..." -ForegroundColor Yellow
                        if (Test-Path $outputFile) {
                            try { Remove-Item $outputFile -Force -ErrorAction SilentlyContinue } catch {}
                        }
                        if (Test-Path $logFile) {
                            try { Remove-Item $logFile -Force -ErrorAction SilentlyContinue } catch {}
                        }
                        
                        Write-Host "  File processing cancelled." -ForegroundColor Red
                        break
                    }
                }

                $elapsed = $stopwatch.Elapsed
                $currentTime = 0
                if (Test-Path $logFile) {
                    try {
                        $lastLine = Get-Content $logFile -Tail 1 -ErrorAction Stop
                        if ($lastLine -match 'time=(\d+):(\d+):(\d+(?:\.\d+)?)') {
                            $h = [int]$matches[1]
                            $m = [int]$matches[2]
                            $s = [double]$matches[3]
                            $currentTime = $h * 3600 + $m * 60 + $s
                        }
                    } catch {}
                }
                $percent = 0
                if ($totalDuration -gt 0) {
                    $percent = [math]::Min(100, ($currentTime / $totalDuration) * 100)
                }
                $statusText = "Time: $($elapsed.ToString('hh\:mm\:ss'))"
                if ($totalDuration -gt 0) {
                    $statusText += " | Progress: $([math]::Round($percent, 1))%"
                }
                Write-Progress -Activity "Compressing: $($file.Name) (Q: $currentCRF)" -Status $statusText -PercentComplete $percent -Id 1
                Start-Sleep -Milliseconds 1000
            }

            if ($script:cancelRequested) {
                $stopwatch.Stop()
                Write-Progress -Activity "Compressing: $($file.Name) (Q: $currentCRF)" -Completed -Id 1
                $Host.PrivateData.ProgressForegroundColor = $originalProgressColor
                break
            }

            $stopwatch.Stop()
            Write-Progress -Activity "Compressing: $($file.Name) (Q: $currentCRF)" -Completed -Id 1
            $Host.PrivateData.ProgressForegroundColor = $originalProgressColor

            Save-Log -SourceLog $logFile -VideoBaseName $file.BaseName -LogType "compress" -Iteration $iteration

            if (Test-Path $logFile) { Remove-Item $logFile -Force }

            if ($LASTEXITCODE -eq 0 -and (Test-Path $outputFile)) {
                $sizeAfter = (Get-Item $outputFile).Length
                $sizeAfterFormatted = Format-FileSize $sizeAfter
                $sizeBeforeNum = [double]$sizeBefore
                $ratio = [math]::Round(($sizeAfter / $sizeBeforeNum) * 100, 1)

                Write-Host "  -> Successfully saved!" -ForegroundColor Green
                Write-Host "  -> Final size: $sizeAfterFormatted (Compressed to $ratio%)" -ForegroundColor Green
                Write-Host "  -> Time taken: $($stopwatch.Elapsed.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan

                if ($enableVMAF) {
                    $vmafWidth = & ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$inputFile" 2>$null
                    $vmafHeight = & ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$inputFile" 2>$null
                    $vmafFpsStr = & ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of csv=p=0 "$inputFile" 2>$null
                    $vmafScore = "N/A"

                    if ($vmafWidth -and $vmafHeight -and $vmafFpsStr) {
                        if ($vmafFpsStr -match '(\d+)/(\d+)') {
                            $vmafFps = [math]::Round([double]$matches[1] / [double]$matches[2], 3)
                        } else {
                            $vmafFps = [double]$vmafFpsStr
                        }

                        $vmafLogFile = Join-Path $env:TEMP "vmaf_log_$($file.BaseName)_iter$iteration.txt"
                        if (Test-Path $vmafLogFile) { Remove-Item $vmafLogFile -Force }

                        $vmafArgs = "-i `"$inputFile`" -i `"$outputFile`" -lavfi `"[0:v]scale=$vmafWidth`:$vmafHeight,fps=$vmafFps[ref];[1:v]scale=$vmafWidth`:$vmafHeight,fps=$vmafFps[dist];[ref][dist]libvmaf`" -f null -"

                        $Host.PrivateData.ProgressForegroundColor = "Cyan"
                        Write-Progress -Activity "Calculating VMAF: $($file.Name)" -Status "Initializing..." -PercentComplete -1 -Id 2

                        $vmafProcess = Start-Process -FilePath "ffmpeg" -ArgumentList $vmafArgs -RedirectStandardError $vmafLogFile -PassThru -NoNewWindow
                        $vmafStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

                        while (!$vmafProcess.HasExited) {
                            if ([System.Console]::KeyAvailable) {
                                $key = [System.Console]::ReadKey($true)
                                if ($key.Key -eq [System.ConsoleKey]::Escape) {
                                    $script:cancelRequested = $true
                                    Write-Host "`n  !!! CANCELLATION REQUESTED !!!" -ForegroundColor Red
                                    Write-Host "  Stopping VMAF calculation..." -ForegroundColor Yellow
                                    
                                    try {
                                        if (!$vmafProcess.HasExited) {
                                            $vmafProcess.Kill()
                                            $vmafProcess.WaitForExit(5000)
                                        }
                                    } catch {}
                                    
                                    Save-Log -SourceLog $vmafLogFile -VideoBaseName $file.BaseName -LogType "vmaf" -Iteration $iteration
                                    
                                    Write-Host "  Cleaning up..." -ForegroundColor Yellow
                                    if (Test-Path $vmafLogFile) {
                                        try { Remove-Item $vmafLogFile -Force -ErrorAction SilentlyContinue } catch {}
                                    }
                                    
                                    Write-Host "  VMAF calculation cancelled." -ForegroundColor Red
                                    break
                                }
                            }

                            $vmafElapsed = $vmafStopwatch.Elapsed
                            $vmafCurrentTime = 0
                            if (Test-Path $vmafLogFile) {
                                try {
                                    $vmafLastLine = Get-Content $vmafLogFile -Tail 1 -ErrorAction Stop
                                    if ($vmafLastLine -match 'time=(\d+):(\d+):(\d+(?:\.\d+)?)') {
                                        $h = [int]$matches[1]
                                        $m = [int]$matches[2]
                                        $s = [double]$matches[3]
                                        $vmafCurrentTime = $h * 3600 + $m * 60 + $s
                                    }
                                } catch {}
                            }
                            $vmafPercent = 0
                            if ($totalDuration -gt 0) {
                                $vmafPercent = [math]::Min(100, ($vmafCurrentTime / $totalDuration) * 100)
                            }
                            $vmafStatusText = "Time: $($vmafElapsed.ToString('hh\:mm\:ss'))"
                            if ($totalDuration -gt 0) {
                                $vmafStatusText += " | Progress: $([math]::Round($vmafPercent, 1))%"
                            }
                            Write-Progress -Activity "Calculating VMAF: $($file.Name)" -Status $vmafStatusText -PercentComplete $vmafPercent -Id 2
                            Start-Sleep -Milliseconds 1000
                        }

                        if ($script:cancelRequested) {
                            $vmafStopwatch.Stop()
                            Write-Progress -Activity "Calculating VMAF: $($file.Name)" -Completed -Id 2
                            $Host.PrivateData.ProgressForegroundColor = $originalProgressColor
                            break
                        }

                        $vmafStopwatch.Stop()
                        Write-Progress -Activity "Calculating VMAF: $($file.Name)" -Completed -Id 2
                        $Host.PrivateData.ProgressForegroundColor = $originalProgressColor

                        Save-Log -SourceLog $vmafLogFile -VideoBaseName $file.BaseName -LogType "vmaf" -Iteration $iteration

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
                        Write-Host "  -> VMAF calculation time: $($vmafStopwatch.Elapsed.ToString('hh\:mm\:ss'))" -ForegroundColor DarkYellow
                    }

                    $vmafColor = "Gray"
                    if ($vmafScore -is [double]) {
                        if ($vmafScore -ge 90) { $vmafColor = "DarkGreen" }
                        elseif ($vmafScore -ge 80) { $vmafColor = "Yellow" }
                        elseif ($vmafScore -ge 70) { $vmafColor = "DarkYellow" }
                        else { $vmafColor = "Red" }
                    }
                    Write-Host "  -> VMAF Quality Score: $vmafScore" -ForegroundColor $vmafColor

                    $needsRecompression = $false
                    if ($enableAutoCRF -and $vmafScore -is [double] -and $vmafScore -lt $vmafThreshold) {
                        if ($iteration -lt $maxIterations) {
                            $newCRF = $currentCRF - 2
                            if ($newCRF -ge $minCRF) {
                                Write-Host "  -> VMAF below $vmafThreshold. Increasing quality from $currentCRF to $newCRF..." -ForegroundColor Yellow
                                $currentCRF = $newCRF
                                $needsRecompression = $true
                                if (Test-Path $outputFile) { Remove-Item $outputFile -Force }
                            } else {
                                Write-Host "  -> Cannot increase quality below $minCRF. Using current quality." -ForegroundColor Yellow
                            }
                        } else {
                            Write-Host "  -> Max iterations reached. Using current quality." -ForegroundColor Yellow
                        }
                    }
                } else {
                    $needsRecompression = $false
                }
            } else {
                Write-Host "  -> ERROR processing file: $($file.Name)" -ForegroundColor Red
                $needsRecompression = $false
            }
        }

        if ($script:cancelRequested) {
            break
        }

        $counter++
    }

    $Host.PrivateData.ProgressForegroundColor = $originalProgressColor
    
    if ($script:cancelRequested) {
        Write-Host "`n---------------------------------------------------"
        Write-Host "!!! PROCESS CANCELLED BY USER !!!" -ForegroundColor Red
        Write-Host "Completed files are preserved. Incomplete files were removed." -ForegroundColor Yellow
        Write-Host "Logs for processed iterations are saved in: $logsFolder" -ForegroundColor DarkGray
    } else {
        Write-Host "`n---------------------------------------------------"
        Write-Host "All tasks completed!" -ForegroundColor Cyan
        if ($enableLogs) {
            Write-Host "Logs saved to: $logsFolder" -ForegroundColor DarkGray
        }
    }
    
    Write-Host "`nPress any key to return to menu..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

try {
    do {
        Show-Menu
        $choice = Read-Host "Enter your choice"
        switch ($choice.ToUpper()) {
            '1' { Select-InputFolder }
            '2' { Toggle-RecursiveSearch }
            'H' { Show-HardwareMenu }
            'D' { Apply-OptimalSettings }
            'P' { Show-PresetsMenu }
            'Q' { Set-CRF }
            'V' { Toggle-VMAF }
            'A' { Toggle-AutoCRF }
            'T' { Set-VMAFThreshold }
            'I' { Set-MaxIterations }
            'M' { Set-MinCRF }
            'L' { Show-LogsMenu }
            'S' {
                Save-Settings
                Write-Host "`nPress any key to continue..."
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
            '0' { Start-Compression }
            'X' {
                Write-Host ""
                Write-Host "Saving settings before exit..." -ForegroundColor Yellow
                Save-Settings
                Write-Host "`nExiting... Goodbye!" -ForegroundColor Cyan
                exit
            }
            default {
                Write-Host "`nInvalid choice. Please try again." -ForegroundColor Red
                Write-Host "Press any key to continue..."
                $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            }
        }
    } while ($true)
} catch {
    Write-Host "`n`n!!! FATAL ERROR !!!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "`nPress any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}