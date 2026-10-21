#!/usr/bin/env bash
# URVID — Universal Ringtone VIDeo helper (Linux)
# Adds URL downloads, recursive category detection, Samsung filter merging,
# and an interactive background-image picker to the existing upload workflow.
set -Eeuo pipefail
IFS=$'\n\t'

VERSION="2.0.0"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ASSET_DIR="$SCRIPT_DIR/assets"
WORK_ROOT="${URVID_WORK_DIR:-$PWD/urvid-work}"
BG_IMAGE=""
SOURCE=""
MODEL_NAME=""
DRY_RUN=false
NO_UPLOAD=false
DOWNLOAD_ONLY=false
CATEGORY_OVERRIDE=""
CATEGORY_FORCED=false
BACKGROUND_URL=""
UPLOAD_DELAY=30
AUDIO_EXTS=(ogg mp3 wav m4a aac flac opus)

usage() {
  cat <<'EOF'
URVID 2.0 — Android sound archive downloader and YouTube-video helper

Usage:
  ./urvid.sh [options] <folder-or-URL>

Inputs:
  A local folder, or a browsable directory URL from onj3 / Andrelouis.

Options:
  --background FILE     Use an existing image as the video background
  --bg-url URL          Download a background image and use it
  --pick-background     Open an interactive image-file picker
  --work-dir DIR        Download/working directory (default: ./urvid-work)
  --category NAME       Force category: ringtones, alarms, ui, notifications
  --download-only       Download/organize files; do not encode or upload
  --no-upload           Encode videos but skip YouTube uploads
  --dry-run             Show intended actions without downloading/encoding/uploading
  --delay SECONDS       Delay between uploads (default: 30)
  -h, --help            Show this help

Examples:
  ./urvid.sh --download-only \
    'https://3.onj.me/phonetones/unzipped/SKY/IM-A720L-VEGA-Xpress/'
  ./urvid.sh --pick-background --no-upload ~/Downloads/Pixel/ringtones
  ./urvid.sh --background ~/Pictures/wallpaper.jpg ~/Downloads/Phone/audio/

Dependencies:
  bash, find, cp, wget, ffmpeg; python3 and youtube-upload are needed for uploads.
  YouTube OAuth files are expected in assets/client_secrets.json and assets/youtube.token.
EOF
}

log() { printf '[URVID] %s\n' "$*"; }
warn() { printf '[URVID] WARNING: %s\n' "$*" >&2; }
die() { printf '[URVID] ERROR: %s\n' "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing dependency '$1'. Install it and retry."; }

while (($#)); do
  case "$1" in
    --background) (($# >= 2)) || die "--background needs a file"; BG_IMAGE=$2; shift 2 ;;
    --bg-url) (($# >= 2)) || die "--bg-url needs a URL"; BACKGROUND_URL=$2; shift 2 ;;
    --pick-background) BG_IMAGE="__PICK__"; shift ;;
    --work-dir) (($# >= 2)) || die "--work-dir needs a directory"; WORK_ROOT=$2; shift 2 ;;
    --category) (($# >= 2)) || die "--category needs a name"; CATEGORY_OVERRIDE=${2,,}; CATEGORY_FORCED=true; shift 2 ;;
    --download-only) DOWNLOAD_ONLY=true; shift ;;
    --no-upload) NO_UPLOAD=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --delay) (($# >= 2)) || die "--delay needs seconds"; [[ $2 =~ ^[0-9]+$ ]] || die "Delay must be a whole number"; UPLOAD_DELAY=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*) die "Unknown option: $1 (try --help)" ;;
    *) [[ -z "$SOURCE" ]] || die "Only one source folder or URL is accepted"; SOURCE=$1; shift ;;
  esac
done

[[ -n "$SOURCE" ]] || { usage; exit 2; }
need_cmd find

is_url() { [[ "$1" =~ ^https?:// ]]; }
is_audio() {
  local lower=${1,,} ext
  for ext in "${AUDIO_EXTS[@]}"; do [[ "$lower" == *."$ext" ]] && return 0; done
  return 1
}
has_audio_files() {
  local f
  while IFS= read -r -d '' f; do
    is_audio "$f" && return 0
  done < <(find "$1" -type f -print0)
  return 1
}
contains_audio_category_dirs() {
  local d base
  while IFS= read -r -d '' d; do
    base=${d##*/}
    case "${base,,}" in
      audio|ringtones|alarms|notifications|notification|ui|system|sounds|calm|retro|galaxy|fun)
        return 0 ;;
    esac
  done < <(find "$1" -mindepth 1 -maxdepth 3 -type d -print0)
  return 1
}

download_source() {
  local url=$1
  need_cmd wget
  mkdir -p "$WORK_ROOT"
  local leaf
  leaf=$(printf '%s' "${url%/}" | awk -F/ '{print $NF}')
  [[ -n "$leaf" ]] || leaf="downloaded-audio"
  # Keep directory names local and predictable; URL is still passed as one argument.
  leaf=${leaf//[^[:alnum:]_. -]/_}
  local dest="$WORK_ROOT/$leaf"
  [[ ! -e "$dest" ]] || dest="$WORK_ROOT/${leaf}-$(date +%Y%m%d-%H%M%S)"
  if $DRY_RUN; then
    log "DRY RUN: would recursively download $url into $dest"
    printf '%s\n' "$dest"
    return 0
  fi
  mkdir -p "$dest"
  log "Downloading archive directory into: $dest"
  # --cut-dirs is deliberately omitted: preserve useful archive subdirectory structure.
  wget --recursive --no-parent --no-host-directories \
    --reject 'index.html*' --wait=1 --tries=4 --retry-connrefused \
    --directory-prefix="$dest" "$url"
  printf '%s\n' "$dest"
}

if is_url "$SOURCE"; then
  [[ "$SOURCE" =~ ^https?:// ]] || die "Only HTTP(S) directory URLs are supported."
  # Derive a useful phone name from archive URLs such as .../Lenovo/P70-A/.
  URL_PATH=${SOURCE%%\?*}
  URL_PATH=${URL_PATH%/}
  if [[ "$URL_PATH" == */phonetones/unzipped/* ]]; then
    REL_PATH=${URL_PATH#*/phonetones/unzipped/}
    BRAND=${REL_PATH%%/*}
    REST=${REL_PATH#*/}
    if [[ "$REST" != "$REL_PATH" ]]; then
      MODEL=${REST%%/*}
      MODEL=${MODEL//-/}
      BRAND=$(printf '%s' "$BRAND" | sed -E 's/[-_]+/ /g')
      MODEL=$(printf '%s' "$MODEL" | sed -E 's/[-_]+/ /g')
      MODEL_NAME="$BRAND $MODEL"
    fi
  fi
  SOURCE="$(download_source "$SOURCE" | tail -n 1)"
  $DRY_RUN && { log "Dry run complete."; exit 0; }
else
  [[ -d "$SOURCE" ]] || die "Source folder does not exist: $SOURCE"
  SOURCE="$(cd -- "$SOURCE" && pwd)"
  # Prefer the original archive hierarchy when a downloaded source contains
  # .../phonetones/unzipped/BRAND/MODEL/<category>. This avoids treating the
  # category folder (e.g. ringtones) as the model and preserves BRAND in titles.
  if [[ "$SOURCE" == */phonetones/unzipped/* ]]; then
    REL_PATH=${SOURCE#*/phonetones/unzipped/}
    BRAND=${REL_PATH%%/*}
    REST=${REL_PATH#*/}
    if [[ "$REST" != "$REL_PATH" ]]; then
      MODEL=${REST%%/*}
      BRAND=$(printf '%s' "$BRAND" | sed -E 's/[-_]+/ /g')
      MODEL=${MODEL//-/}
      MODEL_NAME="$BRAND $MODEL"
    fi
  fi

  # Fallback for ordinary local paths ending in /Brand/Model. Don't use a
  # category directory as the model name.
  if [[ -z "$MODEL_NAME" ]]; then
    BRAND=$(basename -- "$(dirname -- "$SOURCE")")
    MODEL=$(basename -- "$SOURCE")
    case "${MODEL,,}" in audio|ringtones|alarms|notifications|notification|ui|system|sounds) MODEL="" ;; esac
    if [[ -n "$MODEL" ]]; then
      BRAND=$(printf '%s' "$BRAND" | sed -E 's/[-_]+/ /g')
      MODEL=${MODEL//-/}
      MODEL_NAME="$BRAND $MODEL"
    fi
  fi
fi

# If the source has a top-level audio/ folder with nested category folders,
# inspect those nested folders first rather than treating all files as ringtones.
ROOT="$SOURCE"
if [[ -d "$ROOT/audio" ]]; then
  ROOT="$ROOT/audio"
  log "Detected audio/ source directory."
fi

# Validate a forced category once. An explicit --category is authoritative:
# it must bypass both auto-detection and Samsung's automatic ringtone override.
if $CATEGORY_FORCED; then
  case "$CATEGORY_OVERRIDE" in
    ringtone|ringtones) CATEGORY_OVERRIDE=ringtones ;;
    alarm|alarms) CATEGORY_OVERRIDE=alarms ;;
    notification|notifications) CATEGORY_OVERRIDE=notifications ;;
    ui|system|interface) CATEGORY_OVERRIDE=ui ;;
    sounds|sound) CATEGORY_OVERRIDE=sounds ;;
    *) die "Unsupported --category '$CATEGORY_OVERRIDE'. Use ringtones, alarms, notifications, ui, or sounds." ;;
  esac
  log "Forced category enabled: $CATEGORY_OVERRIDE (auto-detection disabled)."
fi

# Samsung's calm/retro/galaxy/fun filters are one ringtone collection, but only
# auto-merge them when the user has NOT explicitly forced a category.
SAMSUNG_PARENT=""
if ! $CATEGORY_FORCED; then
  for candidate in "$ROOT" "$ROOT/ringtones"; do
    [[ -d "$candidate" ]] || continue
    if [[ -d "$candidate/calm" && -d "$candidate/retro" && -d "$candidate/galaxy" && -d "$candidate/fun" ]]; then
      SAMSUNG_PARENT=$candidate
      break
    fi
  done
fi
if [[ -n "$SAMSUNG_PARENT" ]]; then
  COMBINED="$SOURCE/.urvid-combined-ringtones"
  mkdir -p "$COMBINED"
  for filter in calm retro galaxy fun; do
    while IFS= read -r -d '' f; do
      is_audio "$f" || continue
      name=${f##*/}
      dest="$COMBINED/$name"
      if [[ -e "$dest" ]]; then
        stem=${name%.*}; ext=${name##*.}; n=2
        while [[ -e "$COMBINED/${stem}_$n.$ext" ]]; do ((n+=1)); done
        dest="$COMBINED/${stem}_$n.$ext"
      fi
      cp -- "$f" "$dest"
    done < <(find "$SAMSUNG_PARENT/$filter" -type f -print0)
  done
  ROOT="$COMBINED"
  CATEGORY_OVERRIDE="ringtones"
  log "Merged calm/, retro/, galaxy/, and fun/ into one ringtone collection."
fi

# Discover category folders recursively. Archives often contain extra levels such
# as host/brand/model/audio/notifications/; checking only ROOT/<category> made
# those files fall through to the ringtone default.
declare -a JOB_DIRS=()
declare -a JOB_CATS=()
classify_category() {
  local name=${1,,}
  name=${name//[_ -]/}
  case "$name" in
    ringtone|ringtones|ringtonefiles|ringtonesounds|calm|retro|galaxy|fun) printf 'ringtones' ;;
    alarm|alarms|alarmsounds) printf 'alarms' ;;
    notification|notifications|notificationsounds|notificationtones) printf 'notifications' ;;
    ui|system|interface|uisounds|systemsounds) printf 'ui' ;;
    *) return 1 ;;
  esac
}
if [[ -n "$CATEGORY_OVERRIDE" ]]; then
  JOB_DIRS+=("$ROOT"); JOB_CATS+=("$CATEGORY_OVERRIDE")
else
  while IFS= read -r -d '' d; do
    has_audio_files "$d" || continue
    base=${d##*/}
    if cat=$(classify_category "$base"); then
      JOB_DIRS+=("$d"); JOB_CATS+=("$cat")
    fi
  done < <(find "$ROOT" -mindepth 1 -type d -print0)

  # A source URL or local folder may itself point directly at a category,
  # even if wget has put it inside additional directory levels.
  if ((${#JOB_DIRS[@]} == 0)) && has_audio_files "$ROOT"; then
    cat=""
    for path_value in "$ROOT" "$SOURCE"; do
      IFS='/' read -r -a path_parts <<< "$path_value"
      for word in "${path_parts[@]}"; do
        if found=$(classify_category "$word"); then cat=$found; fi
      done
    done
    # Do not mislabel an unknown collection as ringtones; keep it in Sounds.
    [[ -n "$cat" ]] || cat=sounds
    JOB_DIRS+=("$ROOT"); JOB_CATS+=("$cat")
  fi
fi

if ((${#JOB_DIRS[@]} == 0)); then
  if $DOWNLOAD_ONLY; then
    log "Downloaded content, but found no recognized audio files/categories."
    exit 0
  fi
  die "No audio files found. Looked for audio/, ringtones/, alarms/, ui/, and notifications/."
fi

# Background can be supplied as a file, URL, or selected interactively.
if [[ -n "$BACKGROUND_URL" ]]; then
  need_cmd wget
  BG_IMAGE="$ASSET_DIR/imported-background"
  mkdir -p "$ASSET_DIR"
  if $DRY_RUN; then log "DRY RUN: would download background from $BACKGROUND_URL"; BG_IMAGE=""; else
    wget -O "$BG_IMAGE" "$BACKGROUND_URL" || die "Background download failed."
  fi
fi

if [[ "$BG_IMAGE" == "__PICK__" || ( -z "$BG_IMAGE" && -t 0 ) ]]; then
  printf 'Enter path to a background image (jpg/png/webp), or leave blank to search assets/: '
  IFS= read -r BG_IMAGE || true
fi
if [[ -n "$BG_IMAGE" && "$BG_IMAGE" != "__PICK__" ]]; then
  [[ -f "$BG_IMAGE" ]] || die "Background image not found: $BG_IMAGE"
  mkdir -p "$ASSET_DIR"
  # Import to assets so the user need not pre-place background.jpg.
  ext=${BG_IMAGE##*.}; ext=${ext,,}
  case "$ext" in jpg|jpeg|png|webp) ;; *) die "Background must be JPG, JPEG, PNG, or WEBP." ;; esac
  if [[ "$(cd -- "$(dirname -- "$BG_IMAGE")" && pwd)/$(basename -- "$BG_IMAGE")" != "$ASSET_DIR/background.$ext" ]]; then
    if ! $DRY_RUN; then cp -- "$BG_IMAGE" "$ASSET_DIR/background.$ext"; fi
  fi
  BG_IMAGE="$ASSET_DIR/background.$ext"
fi
if [[ -z "$BG_IMAGE" ]]; then
  for candidate in "$ASSET_DIR"/background.jpg "$ASSET_DIR"/background.jpeg "$ASSET_DIR"/background.png "$ASSET_DIR"/background.webp; do
    if [[ -f "$candidate" ]]; then BG_IMAGE=$candidate; break; fi
  done
fi

$DOWNLOAD_ONLY && { log "Download/organization complete. Found ${#JOB_DIRS[@]} category folder(s):"; for i in "${!JOB_DIRS[@]}"; do printf '  %-14s %s\n' "${JOB_CATS[$i]}" "${JOB_DIRS[$i]}"; done; exit 0; }

[[ -n "$BG_IMAGE" && -f "$BG_IMAGE" ]] || die "No background image selected. Use --background FILE, --bg-url URL, or --pick-background."
need_cmd ffmpeg
if ! $NO_UPLOAD; then
  command -v python3 >/dev/null 2>&1 || die "python3 is required for uploads."
  UPLOADER="$SCRIPT_DIR/youtube-upload/bin/youtube-upload"
  [[ -x "$UPLOADER" ]] || UPLOADER="$(command -v youtube-upload || true)"
  [[ -n "$UPLOADER" && -x "$UPLOADER" ]] || die "youtube-upload was not found. Initialize the repository submodule or use --no-upload."
  [[ -f "$ASSET_DIR/client_secrets.json" ]] || die "Missing assets/client_secrets.json."
fi

clean_title() {
  local s=${1%.*}
  s=${s#S_}; s=${s#ACH_}
  s=${s//_/ }
  s=$(printf '%s' "$s" | sed -E 's/^[0-9]+[ -]*//; s/[[:space:]]+/ /g; s/^[[:space:]]+|[[:space:]]+$//g')
  printf '%s' "$s"
}

for i in "${!JOB_DIRS[@]}"; do
  dir=${JOB_DIRS[$i]}; category=${JOB_CATS[$i]}
  phone=${MODEL_NAME:-$(basename -- "$(dirname -- "$dir")")}
  [[ "$dir" == "$ROOT" && -z "$MODEL_NAME" ]] && phone=$(basename -- "$(dirname -- "$SOURCE")")
  phone=$(printf '%s' "$phone" | sed -E 's/[-_]+/ /g')
  mapfile -d '' -t files < <(find "$dir" -type f -print0 | sort -z)
  for f in "${files[@]}"; do
    is_audio "$f" || continue
    raw_title=$(clean_title "$(basename -- "$f")")
    [[ -n "$raw_title" ]] || raw_title="Untitled sound"
    video_title="$phone $category - $raw_title"
    safe=$(printf '%s' "$raw_title" | tr -cs '[:alnum:]_.-' '_' | sed 's/^_*//;s/_*$//')
    [[ -n "$safe" ]] || safe=audio
    out="$WORK_ROOT/videos/$category/${safe}.mp4"
    mkdir -p "$(dirname -- "$out")"
    if $DRY_RUN; then
      log "DRY RUN: would encode '$f' -> '$out' (title: $video_title)"
      continue
    fi
    log "Encoding: $f"
    # Keep the background image's native aspect ratio and dimensions. H.264 4:2:0
    # requires even dimensions, so odd-sized images get at most a 1px edge pad.
    ffmpeg -hide_banner -loglevel error -y -loop 1 -i "$BG_IMAGE" -i "$f" \
      -map 0:v:0 -map 1:a:0 -c:v libx264 -tune stillimage -pix_fmt yuv420p \
      -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2:(ow-iw)/2:(oh-ih)/2,drawtext=text='${raw_title//\'/\\\'}':fontcolor=white:fontsize=36:borderw=2:bordercolor=black:x=(w-text_w)/2:y=h-text_h-50" \
      -c:a aac -b:a 192k -shortest -movflags +faststart "$out"

    if $NO_UPLOAD; then
      log "Created video: $out"
      continue
    fi
    log "Uploading: $video_title"
    playlist_name="$phone ${category^}"
    "$UPLOADER" --title="$video_title" \
      --description="Android $category sound from $phone. Generated with URVID." \
      --playlist="$playlist_name" \
      --privacy=public --client-secrets="$ASSET_DIR/client_secrets.json" \
      --credentials-file="$ASSET_DIR/youtube.token" "$out"
    rm -f -- "$out"
    ((UPLOAD_DELAY == 0)) || sleep "$UPLOAD_DELAY"
  done
done
log "Finished."
