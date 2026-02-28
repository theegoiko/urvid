#!/bin/bash

# 1. Set the Target Directory from the command line argument
# If no argument is given, it stays in the current folder (.)
TARGET_DIR="${1:-.}"

# 2. Enter the target folder (e.g., /home/theegoiko/Samsung-Galaxy-S3/alarms)
cd "$TARGET_DIR" || { echo "Directory not found"; exit 1; }

# 3. Inform the user where we are working
echo "Current Working Directory: $PWD"

# 4. Identify the phone and folder names for YouTube
current_folder=$(basename "$PWD")
clean_folder="${current_folder%s}"
parent_path=$(dirname "$PWD")
parent_folder=$(basename "$parent_path")
clean_phone_name="${parent_folder//-/ }"
playlist_name="$clean_phone_name - $current_folder"

# 5. Find the background image RIGHT HERE in the target folder
# -iname makes it case-insensitive (finds .jpg or .JPG)
BG_IMAGE=$(find . -maxdepth 1 -iname "background.*" | head -n 1)

if [ -z "$BG_IMAGE" ]; then
    echo "Error: No background image found in $PWD"
    echo "Please ensure background.jpg is INSIDE the alarms folder."
    exit 1
fi

# 6. Check for client_secrets.json in the target folder
if [ ! -f "client_secrets.json" ]; then
    echo "Error: client_secrets.json not found in $PWD"
    exit 1
fi

# 7. Start the Loop
for f in *.ogg; do
    [ -e "$f" ] || continue # Skip if no .ogg files exist
    
    raw_title="${f%.ogg}"
    # Remove leading numbers (01_) or S_
    raw_title=$(echo "$raw_title" | sed -E 's/^([0-9]+_|S_)//')
    clean_title="${raw_title//_/ }"
    final_title="${clean_title,,}"
    final_title="${final_title^}"
    
    video_title="$clean_phone_name $clean_folder - $final_title"
    file_name="$video_title.mp4"

    video_description="Enjoy the classic $final_title $clean_folder from the legendary $clean_phone_name. #$clean_folder #$clean_phone_name"

    echo "--- Creating Video: $file_name ---"

    # FFmpeg uses the BG_IMAGE found in the TARGET folder
    ffmpeg -loop 1 -i "$BG_IMAGE" -i "$f" -c:v libx264 -tune stillimage -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2,drawtext=text='$final_title':fontcolor=white:fontsize=h/20:borderw=3:bordercolor=black:x=(w-text_w)/2:y=(h-text_h)/2" -c:a aac -b:a 192k -pix_fmt yuv420p -movflags +faststart -shortest "$file_name"

    echo "--- Uploading to YouTube ---"

    # Upload using the secrets file in the TARGET folder
    youtube-upload \
      --title="$video_title" \
      --description="$video_description" \
      --tags="$clean_phone_name, $clean_folder, $final_title" \
      --category="Music" \
      --privacy="public" \
      --playlist="$playlist_name" \
      --client-secrets="client_secrets.json" \
      "$file_name"

    # Wait to avoid hitting API rate limits too fast
    sleep 30
done

echo "Done! All files in $TARGET_DIR processed."
