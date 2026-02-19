current_folder=$(basename "$PWD")
clean_folder="${current_folder%s}"
parent_path=$(dirname "$PWD")
parent_folder=$(basename "$parent_path")
clean_phone_name="${parent_folder//-/ }"

# Create name playlist
playlist_name="$clean_phone_name - $current_folder"

for f in *.ogg; do
    raw_title="${f%.ogg}"
    clean_title="${raw_title//_/ }"
    final_title="${clean_title,,}"
    final_title="${final_title^}"
    
    video_title="$clean_phone_name $clean_folder - $final_title"
    file_name="$video_title.mp4"

    video_tags="$clean_phone_name, $clean_folder, $final_title, ringtone, nostalgia, classic phone"
    video_description="Enjoy the classic $final_title $clean_folder from the legendary $clean_phone_name. Subscribe for more high-quality nostalgia ringtones! #$clean_folder #$clean_phone_name #nostalgia 
I use urvid to automate my videos with ringtones, alarms, notifications and ui. Try it out👉 https://github.com/theegoiko/urvid"

    # Make batch videos
    ffmpeg -loop 1 -i background.* -i "$f" -c:v libx264 -tune stillimage -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2,drawtext=text='$final_title':fontcolor=white:fontsize=60:borderw=3:bordercolor=black:x=(w-text_w)/2:y=(h-text_h)/2" -c:a aac -b:a 192k -pix_fmt yuv420p -movflags +faststart -shortest "$file_name"

    # Upload batched videos
    youtube-upload \
      --title="$video_title" \
      --description="$video_description" \
      --tags="$video_tags" \
      --category="Music" \
      --privacy="public" \
      --playlist="$playlist_name" \
      --client-secrets="client_secrets.json" \
      "$file_name"
done
