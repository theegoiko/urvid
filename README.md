# urvid
Makes a batch of ringtone, notification, alarm and/or UI videos and uploads them to YouTube. 

An automated script on Bash that makes ringtone videos, provide that you have a folder with ringtones/alarms/notifications/ui in .ogg format a background in.png format, and a client_secrets.json file.
For inspiration, look at onj3 andrelouis library (always try to choose Android devices): http://onj3.andrelouis.com/phonetones/zipped/ 
Unzip the archive, put urvid.sh, client_secrets.json and the background.jpg into the desired folder and enjoy!


It makes a video, if provided with background.png file, merges the background.png and the .ogg audio files, adds the ringtone name into a white text with black outline, and uploads them to YouTube.
Look at my channel if you want to see what the final result looks like:
https://youtube.com/@theegoiko?si=m1aByadotdUpuj8C

1. Update and install tools:
sudo apt update && sudo apt upgrade -y
sudo apt install ffmpeg python3 python3-pip python3-setuptools git nano -y

2. Install the Google API libraries:
pip3 install google-api-python-client google-auth-oauthlib google-auth-httplib2 oauth2client --break-system-packages

3. Go to the YouTube uploader and install it:
cd youtube-upload
sudo python3 setup.py install

4. Put urvid.sh into your ringtones/notifications/alarms/ui folder

5. Run:
chmod +x urvid.sh
./urvid.sh

If you do not have a client_secrets.json file, then:

​1. Create a Project
​Go to the Google Cloud Console.
​Click on the project dropdown at the top (next to "Google Cloud") and select New Project.
​Name it something like Ringtone-Uploader and click Create.
​2. Enable the YouTube API
​In the search bar at the top, type "YouTube Data API v3".
​Select it from the results and click the Enable button.
​3. Configure the OAuth Consent Screen
​Google needs to know who is asking for permission.
​Go to APIs & Services > OAuth consent screen in the left sidebar.
​Choose External and click Create.
​Fill in the required fields:
​App name: Ringtone Bot
​User support email: Your email address.
​Developer contact info: Your email address.
​Click Save and Continue through the "Scopes" and "Test Users" sections.
​Crucial: Under "Test Users," add your own Gmail address. This allows you to log in even while the app is in "Testing" mode.
​4. Create the Credentials (The JSON file)
​Go to APIs & Services > Credentials.
​Click + Create Credentials at the top and select OAuth client ID.
​For Application type, select Desktop app (even though you're on Termux, this is the correct choice for scripts).
​Name it and click Create.
​A box will pop up saying "OAuth client created." Click Download JSON.
5. Rename the client_secrets_xxxxxx.json to just client_secrets.json

