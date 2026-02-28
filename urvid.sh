#!/bin/bash

# 1. The folder where the script, background, and secrets live
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# 2. The folder containing your ringtones (the path you pass in the terminal)
TARGET_DIR="${1:-.}"
# Convert to absolute path so there is no confusion
AUDIO_DIR=$(readlink -f "$TARGET_DIR")

# Move into the audio directory to start working
cd "$AUDIO_DIR" || exit

# Folder naming logic
current_folder=$(basename "$PWD")
clean_folder="${current_folder%s}"
parent_path=$(dirname "$PWD")
parent_folder=$(basename "$parent_path")
clean_phone_name="${parent_folder//-/ }"
playlist_name="$clean_phone_name - $current_folder"

# Find the background in the SCRIPT_DIR
BG_IMAGE=$(find "$SCRIPT_DIR" -maxdepth 1 -iname "background.*" | head -n 1)

if [ -z "$BG_IMAGE" ]; then
    echo "Error: No background image found in $SCRIPT_DIR"
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

    video_description="Enjoy the classic $final_title $clean_folder from the legendary $clean_phone_name. Subscribe for more high-quality nostalgia ringtones! #$clean_folder #$clean_phone_name #nostalgia 
I use urvid to automate my videos. https://github.com/theegoiko/urvid"

    echo "--- Processing: $f ---"

    # FFmpeg uses BG from SCRIPT_DIR and Audio from current (AUDIO_DIR)
    ffmpeg -loop 1 -i "$BG_IMAGE" -i "$f" -c:v libx264 -tune stillimage -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2,drawtext=text='$final_title':fontcolor=white:fontsize=h/20:borderw=3:bordercolor=black:x=(w-text_w)/2:y=(h-text_h)/2" -c:a aac -b:a 192k -pix_fmt yuv420p -movflags +faststart -shortest "$file_name"

    echo "--- Uploading: $file_name ---"

    # youtube-upload uses secrets from SCRIPT_DIR
    youtube-upload \
      --title="$video_title" \
      --description="$video_description" \
      --tags="$clean_phone_name, $clean_folder, $final_title, ringtone" \
      --category="Music" \
      --privacy="public" \
      --playlist="$playlist_name" \
      --client-secrets="$SCRIPT_DIR/client_secrets.json" \
      "$file_name"

    # Optional: wait to avoid API rate limits
    sleep 30
done
