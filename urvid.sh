#!/bin/bash

# 1. Set the target folder (where your alarms are)
TARGET_DIR="${1:-.}"
cd "$TARGET_DIR" || exit

# 2. Identify the phone/folder names for YouTube
current_folder=$(basename "$PWD")
clean_folder="${current_folder%s}"
parent_path=$(dirname "$PWD")
parent_folder=$(basename "$parent_path")
clean_phone_name="${parent_folder//-/ }"
playlist_name="$clean_phone_name - $current_folder"

# 3. Find the background image RIGHT HERE in the alarms folder
BG_IMAGE=$(find . -maxdepth 1 -iname "background.*" | head -n 1)

if [ -z "$BG_IMAGE" ]; then
    echo "Error: No background.jpg found in $PWD"
    echo "Please copy your background image into this folder."
    exit 1
fi

for f in *.ogg; do
    raw_title="${f%.ogg}"
    raw_title=$(echo "$raw_title" | sed -E 's/^([0-9]+_|S_)//')
    clean_title="${raw_title//_/ }"
    final_title="${clean_title,,}"
    final_title="${final_title^}"
    
    video_title="$clean_phone_name $clean_folder - $final_title"
    file_name="$video_title.mp4"

    # FFmpeg uses the background found in the CURRENT folder
    ffmpeg -loop 1 -i "$BG_IMAGE" -i "$f" -c:v libx264 -tune stillimage -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2,drawtext=text='$final_title':fontcolor=white:fontsize=h/20:borderw=3:bordercolor=black:x=(w-text_w)/2:y=(h-text_h)/2" -c:a aac -b:a 192k -pix_fmt yuv420p -movflags +faststart -shortest "$file_name"

    # Upload using the secrets file in the CURRENT folder
    youtube-upload \
      --title="$video_title" \
      --description="Enjoy $final_title from $clean_phone_name." \
      --client-secrets="client_secrets.json" \
      "$file_name"
done
