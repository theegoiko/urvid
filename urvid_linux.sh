#!/bin/bash

# ==========================================
# 1. SETUP PATHS
# ==========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSET_DIR="$SCRIPT_DIR/assets"
BG_IMAGE=$(find "$ASSET_DIR" -maxdepth 1 \( -iname "background.jpg" -o -iname "background.png" \) | head -n 1)
CLIENT_SECRETS="$ASSET_DIR/client_secrets.json"
TOKEN_FILE="$ASSET_DIR/youtube.token"

# Find Python 3 binary
PYTHON_CMD=$(which python3 2>/dev/null || which python 2>/dev/null)
if [ -z "$PYTHON_CMD" ]; then
    echo -e "\e[31mError: Python executable not found.\e[0m"
    exit 1
fi

# Locate youtube-upload script or binary
UPLOADER_SCRIPT=$(which youtube-upload 2>/dev/null)
if [ -z "$UPLOADER_SCRIPT" ]; then
    if [ -f "$HOME/.local/bin/youtube-upload" ]; then
        UPLOADER_SCRIPT="$HOME/.local/bin/youtube-upload"
    else
        UPLOADER_SCRIPT=$(find "$SCRIPT_DIR" -name "youtube-upload" -type f 2>/dev/null | head -n 1)
    fi
fi

if [ -z "$UPLOADER_SCRIPT" ]; then
    echo -e "\e[31mError: youtube-upload script not found.\e[0m"
    exit 1
fi

# ==========================================
# 2. TARGET DIRECTORY
# ==========================================
TARGET_DIR="${1:-.}"
cd "$TARGET_DIR" || { echo "Directory not found: $TARGET_DIR"; exit 1; }

# ==========================================
# 3. IDENTIFY PHONE / FOLDER NAMES
# ==========================================
current_folder=$(basename "$PWD")
clean_folder=$(echo "$current_folder" | sed -E 's/[sS]$//')

parent_folder=$(basename "$(dirname "$PWD")")
clean_phone_name=$(echo "$parent_folder" | sed 's/[-_]/ /g')

# Format target playlist title cleanly (e.g. "Alcatel OneTouch OT903 Ringtone")
# Trim double spaces and force sentence capitalization
playlist_title="$(echo "$clean_phone_name $clean_folder" | xargs)"

# ==========================================
# 4. PROCESS FILES
# ==========================================
shopt -s nullglob
for f in *.ogg *.mp3 *.wav; do
    [ -e "$f" ] || continue
    
    # 1. Title Sanitization
    raw_title="${f%.*}"
    sanitized=$(echo "$raw_title" | sed -E 's/^([0-9]+[_\s]*|S_|ACH_)//g' | sed -E 's/_ACH$//g' | sed 's/_/ /g')
    
    # 2. Capitalization Logic
    lower_title="${sanitized,,}"
    final_title="${lower_title^}"
    
    # Hashtags & Metadata
    tag_phone=$(echo "$clean_phone_name" | tr -d '[:space:]')
    tag_folder=$(echo "$clean_folder" | tr -d '[:space:]')
    
    video_desc="Enjoy the classic $final_title $clean_folder from the legendary $clean_phone_name. #$tag_folder #$tag_phone"
    video_title="$clean_phone_name $clean_folder - $final_title"
    
    temp_file="temp_upload.mp4"

    echo ">>> Encoding: $video_title"

    ffmpeg -loop 1 -i "$BG_IMAGE" -i "$f" -c:v libx264 -tune stillimage \
      -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2,drawtext=text='$final_title':fontcolor=white:fontsize=h/20:borderw=3:bordercolor=black:x=(w-text_w)/2:y=(h-text_h)/2" \
      -c:a aac -b:a 192k -pix_fmt yuv420p -shortest "$temp_file" -y

    if [ -f "$temp_file" ]; then
        echo ">>> Uploading video: '$video_title'"
        echo ">>> Target Playlist: '$playlist_title'"
        
        "$PYTHON_CMD" "$UPLOADER_SCRIPT" \
          --title="$video_title" \
          --description="$video_desc" \
          --playlist="$playlist_title" \
          --client-secrets="$CLIENT_SECRETS" \
          --credentials-file="$TOKEN_FILE" \
          --category="Entertainment" \
          --privacy="public" \
          "$temp_file"
        
        rm "$temp_file"
        echo "Done! 30s nap..."
        sleep 30
    fi
done
shopt -u nullglob
