# 🎵 URVID — Universal Ringtone Video

 ✨ URVID v2 is here - The future of URVID starts now.

**URVID** is a Bash script that turns smartphone audio files—ringtones, notifications, alarms, and UI sounds—into videos with a background image. It uses FFmpeg to combine audio and images and can upload the resulting videos to YouTube.


URVID can also recursively download audio collections from supported browsable directories, such as OnJ3/Andrelouis phone-tone archives, using GNU Wget.

## ✨ Features

- 📥 **Recursive downloading:** Download entire audio directories from supported archive URLs.
- 🔍 **Automatic category detection:** Detect folders such as `ringtones/`, `notifications/`, `alarms/`, and `ui/`.
- 🎛️ **Manual category override:** Use `--category` to force all audio files in the selected source to be processed as one category.
- 📱 **Samsung ringtone merging:** Combine Samsung's `calm/`, `retro/`, `galaxy/`, and `fun/` collections into one ringtone collection when the expected folder structure is detected.
- 🖼️ **Custom backgrounds:** Import a background image from a local file or URL.
- 📐 **Aspect-ratio preservation:** Keep the background image's original aspect ratio and dimensions. Portrait images remain portrait-oriented, making them suitable for creating vertical videos.
- 📂 **Separate YouTube playlists:** Upload videos to category-specific playlists, such as `Lenovo P70A Ringtones` and `Lenovo P70A Notifications`.
- 🏷️ **Device-aware titles:** Generate video titles using the phone brand, model, category, and audio filename.
- 🧪 **Testing options:** Preview planned actions with `--dry-run`, or generate videos without uploading using `--no-upload`.

## 🛠️ Requirements

- **Bash** — runs the script.
- **GNU Wget** — downloads audio archive directories.
- **FFmpeg** — combines audio and background images into videos.
- **Python 3** — required by the upload tool.
- **`youtube-upload`** — the YouTube upload command expected by the current script.
- **YouTube OAuth credentials** — required for authenticated uploads.

On Ubuntu, Linux Mint, and other Debian-based distributions, install the basic dependencies with:

```bash
sudo apt update
sudo apt install wget ffmpeg python3 python-is-python3
```

The `python-is-python3` package provides the `python` command on systems where only `python3` is installed.

You must also install and configure a compatible `youtube-upload` tool and prepare the OAuth credential files described below.

## ⚙️ Installation

Clone the repository and make the script executable:

```bash
git clone https://github.com/theegoiko/urvid.git
cd urvid
chmod +x urvid.sh
```

Install the dependencies listed above, then configure the YouTube uploader before attempting uploads.

The script expects these files in its `assets/` directory:

```text
assets/
├── client_secrets.json
└── youtube.token
```

These files contain authentication-related information. **Do not commit your credentials or tokens to GitHub.**

## 🚀 Quick Start

### 🎼 Process a ringtone collection

Generate videos from a local ringtone directory and upload them using the configured uploader:

```bash
./urvid.sh \
  --category ringtones \
  --background lenovop70a.webp \
  "urvid-work/P70-A/phonetones/unzipped/Lenovo/P70-A/ringtones"
```

For this directory structure, the expected title format is:

```text
Lenovo P70A ringtones - AudioName
```

### 📥 Download an archive only

Download the audio files without generating videos or uploading anything:

```bash
./urvid.sh --download-only \
  "https://3.onj.me/phonetones/unzipped/SKY/IM-A720L-VEGA-Xpress/"
```

### 🧪 Preview actions

Use a dry run to see the planned processing actions without actually encoding or uploading videos:

```bash
./urvid.sh --dry-run \
  "urvid-work/P70-A/phonetones/unzipped/Lenovo/P70-A/ringtones"
```

### 🎬 Generate videos without uploading

Create videos locally and skip YouTube uploads:

```bash
./urvid.sh \
  --category ringtones \
  --background ~/Pictures/background.jpg \
  --no-upload \
  "urvid-work/P70-A/phonetones/unzipped/Lenovo/P70-A/ringtones"
```

### 📱 Create vertical videos

Use a portrait-oriented image as the background:

```bash
./urvid.sh \
  --background ~/Pictures/vertical-wallpaper.webp \
  --no-upload \
  "urvid-work/P70-A/phonetones/unzipped/Lenovo/P70-A/ringtones"
```

URVID preserves the image's aspect ratio instead of stretching it into a landscape frame. Whether a resulting video qualifies for YouTube Shorts depends on YouTube's current requirements and the video's duration.

## 🖥️ Command-Line Options

| Option | Description |
|---|---|
| `-h`, `--help` | Display the help message. |
| `--background FILE` | Use a local image as the video background. |
| `--bg-url URL` | Download a background image from a URL and use it. |
| `--pick-background` | Interactively enter a background-image path in the terminal. |
| `--work-dir DIR` | Specify the working directory. Default: `./urvid-work`. |
| `--category NAME` | Force a category: `ringtones`, `alarms`, `notifications`, or `ui`. |
| `--download-only` | Download and organize files without encoding or uploading. |
| `--no-upload` | Generate videos but skip YouTube uploads. |
| `--dry-run` | Show planned actions without downloading, encoding, or uploading. |
| `--delay SECONDS` | Set the delay between uploads. Default: `30` seconds. |

## 🎛️ Category Handling

Without `--category`, URVID attempts to identify categories from the source directory structure.

| Category | Intended content |
|---|---|
| `ringtones` | Phone ringtones |
| `notifications` | Notification sounds |
| `alarms` | Alarm sounds |
| `ui` | User-interface and system sounds |

### Force a category

For example:

```bash
./urvid.sh --category ringtones --background lenovop70a.webp \
  "urvid-work/P70-A/phonetones/unzipped/Lenovo/P70-A/ringtones"
```

The explicit category should take priority over automatic category detection. This is useful when you want to process a single category as one batch.

Use `alarms`, `notifications`, or `ui` in place of `ringtones` to force a different category.

## 🏷️ Video Titles and Playlists

URVID builds titles from the phone's brand, model, category, and audio filename.

For example:

```text
Lenovo P70A ringtones - Aesthete
Samsung S10+ alarms - MorningBell
```

The script also uses category-specific playlist names, for example:

```text
Lenovo P70A Ringtones
Lenovo P70A Alarms
Lenovo P70A Notifications
Lenovo P70A Ui
```

Playlist creation and uploads depend on the installed uploader, its supported command-line options, and valid YouTube credentials. Live uploads should be tested before processing a large collection.

## 📂 Output Structure

Generated videos are organized into category-specific directories inside the working directory. For example:

```text
urvid-work/
└── videos/
    ├── ringtones/
    ├── alarms/
    ├── notifications/
    └── ui/
```

This separation helps prevent files with identical names in different categories from overwriting each other.

## 🐛 Troubleshooting

### `python: No such file or directory`

Install the Python compatibility package:

```bash
sudo apt install python-is-python3
```

### FFmpeg reports that a dimension is not divisible by two

Some H.264 encoding configurations require even video dimensions. URVID adds minimal edge padding when necessary, rather than significantly resizing the background image.

### WebP or EXIF warnings

FFmpeg may display metadata warnings when processing some WebP images. Check whether the output video was created correctly before assuming that the warning caused a failure.

### The wrong category is selected

Try forcing the intended category explicitly:

```bash
./urvid.sh --category ringtones --dry-run "/path/to/audio"
```

Review the terminal output before running a real upload.

### YouTube uploads fail

Check that:

- The uploader is installed and executable.
- The OAuth client-secrets file exists.
- The credentials file is valid and accessible.
- Your uploader supports the options used by URVID, including playlist assignment.
- Your YouTube account and API configuration permit the upload.

## ✅ Recommended Testing Checklist

Before processing a large collection:

1. 🧪 Run `--dry-run` to inspect the planned actions.
2. 📂 Test archives containing ringtones, alarms, notifications, and UI sounds.
3. 🎛️ Test `--category` to confirm that the forced category takes priority.
4. 🖼️ Test both portrait and landscape background images.
5. 🎬 Use `--no-upload` to check generated videos locally.
6. 🏷️ Verify the phone model, category, and audio filename in the titles.
7. ▶️ Test uploading a small batch and verify playlist assignment.

## 🤝 Contributing

Contributions, bug reports, and suggestions are welcome!

- 🐛 Report bugs through GitHub Issues.
- 💡 Suggest improvements.
- 🔧 Submit pull requests with fixes or new features.

Please check the repository's licensing terms before redistributing or reusing the code. If the project has no license file, do not assume that it is licensed for unrestricted reuse.

## ⚠️ Responsible Use

Only download, process, and upload audio and images that you have permission to use. Respect the source websites' terms, copyright restrictions, and YouTube's policies.

---

Made with 🎵, 🐧, and ☕ using Bash and FFmpeg.
