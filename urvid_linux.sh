#!/bin/bash

# 1. Identify where the assets are relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSET_DIR="$(dirname "$SCRIPT_DIR")/assets"

# 2. Set the Target Directory from the command line argument
TARGET_DIR="${1:-.}"

# 3. Validation: Ensure Assets Exist
BG_IMAGE=$(find "$ASSET_DIR" -maxdepth 1 \( -iname "background.jpg" -o -iname "background.png" \) | head -n 1)
CLIENT_SECRETS="$ASSET_DIR/client_secrets.json"

if [ -z "$BG_IMAGE" ] || [ ! -f "$CLIENT_SECRETS" ]; then
    echo "Error: background.jpg/png or client_secrets.json missing in $ASSET_DIR"
    exit 1
fi

# 4. Enter the target folder
cd "$TARGET_DIR" || { echo "Directory not found"; exit 1; }
echo "Processing audio in: $PWD"

# 5. Identify the phone and folder names
current_folder=$(basename "$PWD")
clean_folder="${current_folder%s}"
parent_folder=$(basename "$(dirname "$PWD")")
clean_phone_name="${parent_folder//-/ }"

# 6. Start the Loop (Now supports .ogg and .mp3)
# The 'nullglob' prevents the script from crashing if one format is missing
shopt -s nullglob
for f in *.ogg *.mp3; do
    [ -e "$f" ] || continue
    
    # Strip the extension (works for .mp3 or .ogg)
    raw_title="${f%.*}"
    
    # Remove leading numbers (01_) or S_
    raw_title=$(echo "$raw_title" | sed -E 's/^([0-9]+_|S_)//')
    
    # Replace underscores with spaces
    clean_title="${raw_title//_/ }"
    
    # Lowercase everything then Capitalize the first letter
    final_title="${clean_title,,}"
    final_title="${final_title^}"
    
    video_title="$clean_phone_name $clean_folder - $final_title"
    file_name="$video_title.mp4"

    echo "--- Creating Video: $file_name ---"

    # FFmpeg uses BG_IMAGE from the ASSET_DIR
    ffmpeg -loop 1 -i "$BG_IMAGE" -i "$f" -c:v libx264 -tune stillimage -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2,drawtext=text='$final_title':fontcolor=white:fontsize=h/20:borderw=3:bordercolor=black:x=(w-text_w)/2:y=(h-text_h)/2" -c:a aac -b:a 192k -pix_fmt yuv420p -movflags +faststart -shortest "$file_name" -y

    echo "--- Uploading to YouTube ---"

    # Uses secrets and token from ASSET_DIR
    youtube-upload \
      --title="$video_title" \
      --client-secrets="$CLIENT_SECRETS" \
      --credentials-file="$ASSET_DIR/youtube.token" \
      --category="Entertainment" \
      --privacy="public" \
      "$file_name"

    sleep 30
done
shopt -u nullglob