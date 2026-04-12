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

$UploaderScript = Join-Path $RootDir "youtube-upload\bin\youtube-upload"
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
    
    # Capitalization Logic: Lowercase everything, then capitalize first letter
    $RawName = ($file.BaseName -replace '^[0-9]+[_\s]*', '' -replace '^S_', '' -replace '_', ' ').Trim().ToLower()
    $CleanTitle = if ($RawName.Length -gt 0) { $RawName.Substring(0,1).ToUpper() + $RawName.Substring(1) } else { "Audio" }
    
    $FolderCategory = (Split-Path $file.Directory -Leaf).TrimEnd("s", "S")
    $ParentDir = Split-Path $file.Directory -Parent
    $DeviceName = if ($ParentDir) { (Split-Path $ParentDir -Leaf) -replace '[-_]', ' ' } else { "Mobile" }
    
    # Metadata & Playlist Info
    $TagPhone = $DeviceName -replace '\s+', ''
    $TagFolder = $FolderCategory -replace '\s+', ''
    $VideoDescription = "Enjoy the classic $CleanTitle $FolderCategory from the legendary $DeviceName. #$TagFolder #$TagPhone"
    $VideoTitle = "$DeviceName $FolderCategory - $CleanTitle"
    
    # --- UPDATED PLAYLIST LOGIC ---
    $PlaylistTitle = "$DeviceName $FolderCategory" 
    
    $TempVideo = Join-Path $RootDir "temp_rendering.mp4"

    Write-Host "`n>>> Processing: $VideoTitle" -ForegroundColor Green

    $FFmpegArgs = @(
        "-loop", "1", "-i", "$BgImage", "-i", "$f", "-c:v", "libx264", "-tune", "stillimage",
        "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2,drawtext=fontfile='$FontPath':text='$CleanTitle':fontsize=h/20:fontcolor=white:borderw=2:bordercolor=black:x=(w-text_w)/2:y=(h-text_h)/2",
        "-c:a", "aac", "-b:a", "192k", "-pix_fmt", "yuv420p", "-shortest", "$TempVideo", "-y"
    )
    
    & $FFmpegPath @FFmpegArgs

    if (Test-Path $TempVideo) {
        Write-Host "Uploading to Playlist: $PlaylistTitle" -ForegroundColor Yellow
        & $PythonCmd "$UploaderScript" --title "$VideoTitle" --description "$VideoDescription" `
            --client-secrets "$ClientSecrets" --credentials-file "$TokenFile" `
            --playlist "$PlaylistTitle" "$TempVideo"
        
        Remove-Item "$TempVideo" -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 30
    }
}
Write-Host "`nBatch Complete!" -ForegroundColor Cyan