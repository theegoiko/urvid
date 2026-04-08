#!/bin/bash

# 1. Paths Setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSET_DIR="$SCRIPT_DIR/assets"
BG_IMAGE=$(find "$ASSET_DIR" -maxdepth 1 \( -iname "background.jpg" -o -iname "background.png" \) | head -n 1)
CLIENT_SECRETS="$ASSET_DIR/client_secrets.json"
TOKEN_FILE="$ASSET_DIR/youtube.token"

# 2. Target Directory
TARGET_DIR="${1:-.}"
cd "$TARGET_DIR" || exit 1

# 3. Identify Phone/Folder Names
current_folder=$(basename "$PWD")
clean_folder="${current_folder%s}"
parent_folder=$(basename "$(dirname "$PWD")")
clean_phone_name="${parent_folder//-/ }"

# 4. Process Files
shopt -s nullglob
for f in *.ogg *.mp3 *.wav; do
    [ -e "$f" ] || continue
    
    raw_title="${f%.*}"
    raw_title=$(echo "$raw_title" | sed -E 's/^([0-9]+_|S_)//')
    clean_title="${raw_title//_/ }"
    final_title="${clean_title,,}"
    final_title="${final_title^}"
    
    # --- FIXED DESCRIPTION & HASHTAG LOGIC ---
    tag_phone="${clean_phone_name// /}"
    tag_folder="${clean_folder// /}"
    video_desc="Enjoy the classic $final_title $clean_folder from the legendary $clean_phone_name. #$tag_folder #$tag_phone"
    video_title="$clean_phone_name $clean_folder - $final_title"
    
    temp_file="temp_upload.mp4"

    echo ">>> Encoding: $video_title"

    ffmpeg -loop 1 -i "$BG_IMAGE" -i "$f" -c:v libx264 -tune stillimage -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2,drawtext=text='$final_title':fontcolor=white:fontsize=h/20:borderw=3:bordercolor=black:x=(w-text_w)/2:y=(h-text_h)/2" -c:a aac -b:a 192k -pix_fmt yuv420p -shortest "$temp_file" -y

    if [ -f "$temp_file" ]; then
        echo ">>> Uploading..."
        youtube-upload \
          --title="$video_title" \
          --description="$video_desc" \
          --client-secrets="$CLIENT_SECRETS" \
          --credentials-file="$TOKEN_FILE" \
          --category="Entertainment" \
          --privacy="public" \
          "$temp_file"
        
        rm "$temp_file"
        echo "Done. Sleeping 30s..."
        sleep 30
    fi
done
shopt -u nullglob