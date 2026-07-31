# FFmpeg Compressor

## Key Features

-  Hardware Acceleration: Automatically detects your GPU (NVIDIA, AMD) and applies the optimal encoding parameters. Falls back to CPU, if no modern GPU is found.
-  Smart Auto-CRF & VMAF: Integrates the **VMAF** (Video Multimethod Assessment Fusion) metric to measure perceived video quality. If the VMAF score drops below your threshold, the script automatically lowers the CRF (increases quality) and re-encodes until the target quality is met. In fact, it will check 2-3 times more than the compression itself, I dont recommend it for large files.
-  Batch Processing: Recursively scans directories for video files and compresses them while preserving the original folder structure.
-  Presets Management: Save, load, and delete custom encoding profiles (Presets) for different use cases.
-  Detailed Logging: Generates comprehensive logs for both the compression process and VMAF calculations for every single file.

## How to Use

### 1. Install FFmpeg (First Time Only)
If you don't have FFmpeg installed, you can install it in two ways:
- **A**: Run `install_ffmpeg.ps1` as Administrator.
- **B**: Run `Run_Compress.bat`, press `F` in the menu, and select `1. Automatic installation via script`.

### 2. Compress Videos
1. Place the script files in a folder.
2. Double-click `Run_Compress.bat`.
3. The script will automatically target the **parent folder** containing your videos. (You can change this in the menu).
4. Use the interactive menu to:
   - Press `D` to **Auto-detect hardware** and apply optimal settings.
   - Press `H` to manually tweak Hardware/Codec/Preset settings.
   - Press `V` and `T` to configure **VMAF** and Auto-CRF thresholds.
5. Press `0` to start the compression process.

## Configuration Guide

### Quality (CRF/CQ)
Controls the balance between file size and video quality.
- **18-20**: Visually lossless (large files).
- **23**: Default/Balanced.
- **28-30**: Good quality (smaller files).

### Hardware Acceleration
- **CPU (Software)**: Uses your processor. Slowest, but offers the best compression efficiency and quality.
- **GPU (Hardware)**: Uses your graphics card. 5-20x faster than CPU with very good quality.

### Codecs
- **H.264**: Maximum compatibility. Works everywhere.
- **H.265 (HEVC)**: 30-50% smaller files than H.264 at the same quality. (nvidia 30xx)
- **AV1**: Up to 50% smaller than H.264. Best compression, but requires modern hardware for fast encoding. (nvidia 40xx)

### VMAF & Auto-CRF
- **VMAF** measures perceived video quality on a scale of 0-100 (90+ is excellent).
- **Auto-CRF** automatically improves quality (lowers CRF value) if the initial VMAF score is below your set threshold, ensuring you never get a badly compressed video.
