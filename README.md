
***

```markdown
# URVID (Universal Ringtone Video & Upload Daemon)

[![GitHub Repo](https://img.shields.io/badge/Source-theegoiko%2Furvid-blue?logo=github)](https://github.com/theegoiko/urvid)

URVID is an automated batch-processing tool designed to take entire folders of audio files (like phone ringtones or notifications), convert them into high-quality static-image videos using FFmpeg with auto-scaling text overlays, and automatically upload them to YouTube via the YouTube Data API.

## 🌟 Features
* **Batch Processing:** Point it at a folder and let it encode/upload dozens of files consecutively.
* **Auto-Scaling Text:** FFmpeg logic automatically scales the text overlay proportionally to your background image (`h/20`).
* **Smart Titling:** Automatically generates YouTube titles based on your folder structure (e.g., `Device Name Category - Audio Name`).
* **Cross-Platform:** Core logic relies on Python and FFmpeg, operable on Windows, macOS, and Linux.

---

## 🖥️ Minimum System Requirements
Since URVID processes static images rather than full-motion video, it runs well on lightweight systems.
* **OS:** Windows 10/11, macOS 10.15+, or Linux (Ubuntu 20.04+ / Arch / Fedora).
* **CPU:** Dual-core processor (1.5 GHz or higher).
* **RAM:** 4 GB minimum (8 GB recommended for smoother FFmpeg execution).
* **Storage:** ~500 MB for Python, FFmpeg, and the repo + temporary space for video rendering (cleaned up automatically).
* **Network:** Stable internet connection for YouTube API uploads.

---

## 🛠️ Installation Guide

### 1. Prerequisites (All Operating Systems)
You need to download your audio files to process. A massive, excellent archive of zipped phone ringtones can be found here:
🔗 **[Andre Louis's Phonetones Archive](http://onj3.andrelouis.com/phonetones/zipped/)**

### Windows
1. **Install Python:** Download and install Python 3.x from [python.org](https://www.python.org/downloads/). *(Make sure to check "Add Python to PATH" during installation!)*
2. **Install FFmpeg:** Download FFmpeg from [gyan.dev](https://www.gyan.dev/ffmpeg/builds/) or install via Winget:
   ```powershell
   winget install ffmpeg
   ```
3. **Clone the Repository:**
   ```powershell
   git clone [https://github.com/theegoiko/urvid.git](https://github.com/theegoiko/urvid.git)
   cd urvid
   ```
4. **Install Python Dependencies:**
   ```powershell
   python -m pip install google-api-python-client oauth2client httplib2
   ```

### macOS
1. **Install Homebrew** (if you don't have it):
   ```bash
   /bin/bash -c "$(curl -fsSL [https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh](https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh))"
   ```
2. **Install Python & FFmpeg:**
   ```bash
   brew install python ffmpeg git
   ```
3. **Clone and Setup:**
   ```bash
   git clone [https://github.com/theegoiko/urvid.git](https://github.com/theegoiko/urvid.git)
   cd urvid
   pip3 install google-api-python-client oauth2client httplib2
   ```

### Linux (Debian / Ubuntu)
1. **Install System Packages:**
   ```bash
   sudo apt update
   sudo apt install python3 python3-pip ffmpeg git -y
   ```
2. **Clone and Setup:**
   ```bash
   git clone [https://github.com/theegoiko/urvid.git](https://github.com/theegoiko/urvid.git)
   cd urvid
   pip3 install google-api-python-client oauth2client httplib2
   ```

---

## ⚙️ Configuration & Project Setup

Before running the script, ensure your `urvid` folder is structured correctly:

1. **Background Image:** Place a background image named `background.jpg` inside the `assets/` folder.
2. **YouTube API Credentials:** * You need a YouTube Data API v3 application setup in Google Cloud Console.
   * Download your OAuth 2.0 Client IDs JSON file.
   * Rename it to `client_secrets.json` and place it in the `assets/` folder.
3. **YouTube-Upload Module:** Ensure the `youtube-upload` folder/submodule is present inside the root directory.

*Note for Windows Users: The script automatically bypasses FFmpeg's notorious `fontconfig` crash by pointing directly to `C:/Windows/Fonts/arial.ttf`.*

---

## 🚀 How to Use

URVID uses a **smart-naming system**. It looks at the folder structure of your audio files to determine the YouTube video title. 

Organize your downloaded audio files like this:
```text
Downloads/
└── TCL-60-XE/                 <-- Device Name
    └── ringtones/             <-- Category
        ├── Bell_Phone.mp3     <-- Audio File
        └── Cyan.mp3
```
*This will generate a YouTube video titled: **"TCL 60 XE ringtone - Bell Phone"***

### Running the Batch Upload

**On Windows (PowerShell):**
Open PowerShell, navigate to your `urvid` folder, and run the script, passing the target audio folder in quotes:

```powershell
.\urvid_windows.ps1 "C:\Users\YourName\Downloads\TCL-60-XE\ringtones"
```

**On Linux / Mac (Bash):**
*(Assuming you have a bash equivalent script like `urvid.sh`)*
```bash
./urvid.sh "/home/user/Downloads/TCL-60-XE/ringtones"
```

### First-Time Upload Authentication
The very first time you run URVID, it will pause the upload and prompt you with a URL.
1. Copy the Google URL and paste it into your browser.
2. Sign in to the YouTube channel where you want to upload the videos.
3. Allow the requested permissions.
4. Copy the authorization code provided by Google.
5. Paste it back into your terminal. 

*URVID will generate a `youtube.token` file in your `assets/` folder, meaning you won't have to sign in again for future uploads!*
```
