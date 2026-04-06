# ==========================================
# 1. SETUP PATHS
# ==========================================
$ScriptPath = $MyInvocation.MyCommand.Definition
$RootDir = Split-Path -Parent $ScriptPath
$AssetDir = Join-Path $RootDir "assets"
$BgImage = Join-Path $AssetDir "background.jpg"
$ClientSecrets = Join-Path $AssetDir "client_secrets.json"
$TokenFile = Join-Path $AssetDir "youtube.token"
$FFmpegPath = "C:\ffmpeg\bin\ffmpeg.exe"

# Verify essential paths exist
if (-not (Test-Path $BgImage)) {
    Write-Host "Background image not found at: $BgImage" -ForegroundColor Red
    pause; exit
}
if (-not (Test-Path $FFmpegPath)) {
    Write-Host "FFmpeg not found at: $FFmpegPath" -ForegroundColor Red
    Write-Host "Please install FFmpeg or update the path in the script." -ForegroundColor Red
    pause; exit
}

# --- FONT PATH FIX ---
# FFmpeg needs the colon escaped like C\: on Windows within filter strings
$FontPath = "C\:/Windows/Fonts/arial.ttf"

$UploaderScript = Join-Path $RootDir "youtube-upload\bin\youtube-upload"
if (-not (Test-Path $UploaderScript)) {
    $uploaderFile = Get-ChildItem -Path $RootDir -Filter "youtube-upload" -Recurse -File | Select-Object -First 1
    if ($uploaderFile) {
        $UploaderScript = $uploaderFile.FullName
    } else {
        Write-Host "YouTube uploader script not found!" -ForegroundColor Red
        pause; exit
    }
}

$PythonCmd = "$env:LOCALAPPDATA\Programs\Python\Python314\python.exe"
if (-not (Test-Path $PythonCmd)) {
    $PythonCmd = "python"
    # Test if python command works
    try {
        & $PythonCmd --version
    } catch {
        Write-Host "Python not found! Please ensure Python is installed and accessible." -ForegroundColor Red
        pause; exit
    }
}

# ==========================================
# 2. TARGET DIRECTORY
# ==========================================
$TargetDir = if ($args[0]) { $args[0] } else { "." }
if (-not (Test-Path $TargetDir)) {
    Write-Host "Target directory not found: $TargetDir" -ForegroundColor Red
    pause; exit
}
Set-Location $TargetDir

# ==========================================
# 3. PROCESS FILES
# ==========================================
$Files = Get-ChildItem -Include "*.mp3", "*.ogg", "*.wav" -Recurse
Write-Host "Found $($Files.Count) audio files." -ForegroundColor Magenta

foreach ($file in $Files) {
    $f = $file.FullName
    # Sanitize filename for title - remove track numbers and clean up underscores
    $CleanTitle = ($file.BaseName -replace '^[0-9]+[_\s]*', '' -replace '^S_', '' -replace '_', ' ').Trim()
    
    # Extract category from folder name
    $FolderCategory = (Split-Path $file.Directory -Leaf).TrimEnd("s", "S")
    $ParentDir = Split-Path $file.Directory -Parent
    $DeviceName = if ($ParentDir) { 
        (Split-Path $ParentDir -Leaf) -replace '[-_]', ' ' 
    } else { 
        "Mobile" 
    }
    
    # Ensure Title isn't empty
    if ([string]::IsNullOrWhiteSpace($DeviceName)) { 
        $DeviceName = "Device" 
    }
    if ([string]::IsNullOrWhiteSpace($CleanTitle)) {
        $CleanTitle = $file.BaseName
    }
    
    $VideoTitle = "$DeviceName $FolderCategory - $CleanTitle"
    
    # Create temp video in the script root to avoid permission issues in target folders
    $TempVideo = Join-Path $RootDir "temp_rendering_$((Get-Date).ToFileTime()).mp4"

    Write-Host "`n--- Processing: $VideoTitle ---" -ForegroundColor Green
    Write-Host "File: $($file.Name)" -ForegroundColor Gray

    # FFmpeg Command - properly escape special characters in text
    $EscapedTitle = $CleanTitle -replace "'", "'\\''"  # Escape single quotes for FFmpeg
    
    Write-Host "Encoding Video..." -ForegroundColor Yellow
    $FFmpegArgs = @(
        "-loop", "1",
        "-i", "`"$BgImage`"",
        "-i", "`"$f`"",
        "-c:v", "libx264",
        "-tune", "stillimage",
        "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2,drawtext=fontfile='$FontPath':text='$CleanTitle':fontsize=h/20:fontcolor=white:borderw=2:bordercolor=black:x=(w-text_w)/2:y=(h-text_h)/2
        "-c:a", "aac",
        "-b:a", "192k",
        "-pix_fmt", "yuv420p",
        "-shortest",
        "`"$TempVideo`"",
        "-y"
    )
    
    $result = & $FFmpegPath $FFmpegArgs
    $ffprobe = $LASTEXITCODE

    # Check and Upload
    if ((Test-Path $TempVideo) -and ($ffprobe -eq 0)) {
        Write-Host "Uploading to YouTube..." -ForegroundColor Green
        $uploadResult = & $PythonCmd "`"$UploaderScript`"" --title "`"$VideoTitle`"" --client-secrets "`"$ClientSecrets`"" --credentials-file "`"$TokenFile`"" "`"$TempVideo`""
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Upload successful!" -ForegroundColor Green
        } else {
            Write-Host "Upload failed!" -ForegroundColor Red
        }
        
        Remove-Item "$TempVideo" -ErrorAction SilentlyContinue
        Write-Host "taking a 30 sec nap... zzz..." -ForegroundColor Gray
        Start-Sleep -Seconds 30
    } else {
        Write-Host "ERROR: FFmpeg failed to create the file." -ForegroundColor Red
        Write-Host "Attempting emergency encode without text overlay..." -ForegroundColor Yellow
        
        # Try encoding without text overlay as fallback
        $FFmpegArgsFallback = @(
            "-loop", "1",
            "-i", "`"$BgImage`"",
            "-i", "`"$f`"",
            "-c:v", "libx264",
            "-tune", "stillimage",
            "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2",
            "-c:a", "aac",
            "-b:a", "192k",
            "-pix_fmt", "yuv420p",
            "-shortest",
            "`"$TempVideo`"",
            "-y"
        )
        
        & $FFmpegPath $FFmpegArgsFallback
        
        if (Test-Path $TempVideo) {
            Write-Host "Fallback encoding successful. Uploading..." -ForegroundColor Yellow
            $uploadResult = & $PythonCmd "`"$UploaderScript`"" --title "`"$VideoTitle`"" --client-secrets "`"$ClientSecrets`"" --credentials-file "`"$TokenFile`"" "`"$TempVideo`""
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Upload successful!" -ForegroundColor Green
            } else {
                Write-Host "Upload failed!" -ForegroundColor Red
            }
            
            Remove-Item "$TempVideo" -ErrorAction SilentlyContinue
        } else {
            Write-Host "Both encoding attempts failed for file: $($file.Name)" -ForegroundColor Red
        }
        
        Write-Host "taking a 30 sec nap... zzz..." -ForegroundColor Gray
        Start-Sleep -Seconds 30
    }
}

Write-Host "`n i'm done! Processed $($Files.Count) files." -ForegroundColor Cyan
Read-Host -Prompt "Press Enter to close"