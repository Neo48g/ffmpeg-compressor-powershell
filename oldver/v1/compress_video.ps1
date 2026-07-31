# --- SETTINGS ---
$inputFolder = "C:\Users\v86x\Videos\FFmpegVIDS"
$outputFolder = ".\compressed"
# Extensions with a dot at the beginning
$extensions = @(".mp4", ".mkv", ".avi", ".mov", ".m4v", ".webm", ".ts", ".mts", ".m2ts", ".flv", ".wmv")

# 1. Create output folder
if (-not (Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder | Out-Null
    Write-Host "Created folder: $outputFolder" -ForegroundColor Gray
}

# 2. FOOLPROOF FILE SEARCH
# We get all files first, then filter by extension manually to avoid PowerShell -Include bugs
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

    Write-Host "[$counter/$($files.Count)] Compressing: $($file.Name)" -ForegroundColor Yellow

    # Run FFmpeg
    ffmpeg -i "$inputFile" -c:v libx264 -crf 23 -preset medium -c:a aac -b:a 128k -y "$outputFile"

    # Check result
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  -> Successfully saved to: $outputFile" -ForegroundColor Green
    } else {
        Write-Host "  -> ERROR processing file: $($file.Name)" -ForegroundColor Red
    }
    
    $counter++
}

Write-Host "---------------------------------------------------"
Write-Host "All tasks completed!" -ForegroundColor Cyan