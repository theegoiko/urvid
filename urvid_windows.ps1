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
$FontPath = "C\:/Windows/Fonts/arial.ttf"

# Verify essential paths
if (-not (Test-Path $BgImage)) { Write-Host "Background missing: $BgImage" -ForegroundColor Red; pause; exit }
if (-not (Test-Path $FFmpegPath)) { Write-Host "FFmpeg missing: $FFmpegPath" -ForegroundColor Red; pause; exit }

$UploaderScript = Join-Path $RootDir "youtube-upload\bin\youtube-upload"
if (-not (Test-Path $UploaderScript)) {
    $uploaderFile = Get-ChildItem -Path $RootDir -Filter "youtube-upload" -Recurse -File | Select-Object -First 1
    $UploaderScript = if ($uploaderFile) { $uploaderFile.FullName } else { Write-Host "Uploader missing!" -ForegroundColor Red; pause; exit }
}

$PythonCmd = "$env:LOCALAPPDATA\Programs\Python\Python314\python.exe"
if (-not (Test-Path $PythonCmd)) { $PythonCmd = "python" }

# ==========================================
# 2. TARGET DIRECTORY
# ==========================================
$TargetDir = if ($args[0]) { $args[0] } else { "." }
if (-not (Test-Path $TargetDir)) { Write-Host "Dir not found: $TargetDir" -ForegroundColor Red; pause; exit }
Set-Location $TargetDir

# ==========================================
# 3. PROCESS FILES
# ==========================================
$Files = Get-ChildItem -Include "*.mp3", "*.ogg", "*.wav" -Recurse
Write-Host "Found $($Files.Count) audio files." -ForegroundColor Magenta

foreach ($file in $Files) {
    $f = $file.FullName
    $CleanTitle = ($file.BaseName -replace '^[0-9]+[_\s]*', '' -replace '^S_', '' -replace '_', ' ').Trim()
    
    $FolderCategory = (Split-Path $file.Directory -Leaf).TrimEnd("s", "S")
    $ParentDir = Split-Path $file.Directory -Parent
    $DeviceName = if ($ParentDir) { (Split-Path $ParentDir -Leaf) -replace '[-_]', ' ' } else { "Mobile" }
    
    # --- FIXED DESCRIPTION & HASHTAG LOGIC ---
    $TagPhone = $DeviceName -replace '\s+', ''
    $TagFolder = $FolderCategory -replace '\s+', ''
    $VideoDescription = "Enjoy the classic $CleanTitle $FolderCategory from the legendary $DeviceName. #$TagFolder #$TagPhone"
    $VideoTitle = "$DeviceName $FolderCategory - $CleanTitle"
    
    $TempVideo = Join-Path $RootDir "temp_rendering.mp4"

    Write-Host "`n>>> Processing: $VideoTitle" -ForegroundColor Green

    $FFmpegArgs = @(
        "-loop", "1",
        "-i", "$BgImage",
        "-i", "$f",
        "-c:v", "libx264",
        "-tune", "stillimage",
        "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2,drawtext=fontfile='$FontPath':text='$CleanTitle':fontsize=h/20:fontcolor=white:borderw=2:bordercolor=black:x=(w-text_w)/2:y=(h-text_h)/2",
        "-c:a", "aac",
        "-b:a", "192k",
        "-pix_fmt", "yuv420p",
        "-shortest",
        "$TempVideo",
        "-y"
    )
    
    & $FFmpegPath @FFmpegArgs

    if (Test-Path $TempVideo) {
        Write-Host "Uploading to YouTube..." -ForegroundColor Yellow
        & $PythonCmd "$UploaderScript" --title "$VideoTitle" --description "$VideoDescription" --client-secrets "$ClientSecrets" --credentials-file "$TokenFile" "$TempVideo"
        
        Remove-Item "$TempVideo" -ErrorAction SilentlyContinue
        Write-Host "Done! 30s nap..." -ForegroundColor Gray
        Start-Sleep -Seconds 30
    } else {
        Write-Host "FFmpeg failed. Skipping to fallback..." -ForegroundColor Red
        & $FFmpegPath -loop 1 -i "$BgImage" -i "$f" -c:v libx264 -tune stillimage -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -c:a aac -b:a 192k -pix_fmt yuv420p -shortest "$TempVideo" -y
        if (Test-Path $TempVideo) {
             & $PythonCmd "$UploaderScript" --title "$VideoTitle" --description "$VideoDescription" --client-secrets "$ClientSecrets" --credentials-file "$TokenFile" "$TempVideo"
             Remove-Item "$TempVideo"
        }
    }
}
Write-Host "`nBatch Complete!" -ForegroundColor Cyan
Read-Host -Prompt "Press Enter to close"