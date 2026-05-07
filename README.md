# Miliza

**Miliza is a Linux based music streaming server.**

<br>Run it as a media server and access over web interface in local network.

Integrates with the Tidal through EbbLabs/python-tidal API.
<br>Finding internet radios throguh radio-browser.info and plays from direct links.

Try it out on your Raspberry PI or some other ARM64 / x86_64 Linux machine running Debian based OS.

## 🔽 Download
This repository is for installation scripts, documentation and bug tracking only.
<br>Binary downloads are available on the website: **https://miliza.eu**

## ⚠️ Disclaimer
The software is distributed as-is, without warranty of any kind. By using this software, you acknowledge that you do so at your own risk, and the author assumes no liability for any damages, legal issues, or other consequences arising from its use.

Commercial use, selling, or redistributing this software in any form is not permitted.
This software is not officially related to TIDAL music app in any way.

Tidal integration deploys EbbLabs/python-tidal API.
Stations search is based on radio-browser.info.

## ✨ Features
For now there is two compiled versions. One compiled on ARM64 Debian and one for x86_64 Ubuntu/Debian.

* **Web UI:** Accessible via web browser in local network. Installs as a WebApp.
* **Play files from:** Removable media, NAD, and cloud like Dropbox, Google, OneDrive
* **Tidal Integration:** Access your favorite Tidal tracks, playlists, albums, and discover curated content. Hi-res playback.
* **Online radio stations:** Search stations, and listen to direct stream links.
* **Bluetooth:** multi-device connectivity
* **Hardware Audio:** Direct ALSA output and Bluetooth routing support.
* **DSP:** 64-bit dynamic loudness control, Auto EQ, 10-band EQ
* **Standalone Binary:** Compiled into a single executable for easy deployment.
* **Raspberry Pi:** Install image setup with access point for headless WiFi configuration.

## 🛠️ 1. System Prerequisites

Even though Miliza is packaged as a standalone binary, it relies on system-level C-libraries for audio playback and Bluetooth management. **GStreamer**, **ALSA**, and **BlueZ** must be installed on the host system before running the app.

Packages you need:

```
apt-get install -y \
    rclone fuse3 \
    libbluetooth3 libsbc1 libfreeaptx0 libldacbt-enc2 libldacbt-abr2 libfdk-aac2 \
    libmp3lame0 libmpg123-0 libopus0 \
    libgirepository-2.0-0 gir1.2-glib-2.0 python3-gi \
    avahi-daemon alsa-utils bluez bluez-tools rfkill dbus \
    gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
    gstreamer1.0-libav gstreamer1.0-tools gstreamer1.0-alsa \
    gir1.2-gst-plugins-base-1.0 curl ca-certificates nano \
    git build-essential autoconf automake libtool pkg-config \
    libasound2-dev libbluetooth-dev libglib2.0-dev libsbc-dev \
    libfdk-aac-dev libfreeaptx-dev libldacbt-enc-dev libldacbt-abr-dev \
    libmp3lame-dev libmpg123-dev libopus-dev libdbus-1-dev smbclient cifs-utils udisks2 id3v2
```

## 🚀 2. Running Miliza

There are 2 binaries available for now. Both for Debian based systems.
* **x86_64**
* **aarch64**

1. **Run the server:**
   ```bash
   ./miliza_server_alpha_arm64_202603141200
   ```

2. **Access the Interface:**
   Once the backend starts, open a web browser and navigate to:
   ```text
   http://IP-ADDRESS:5000
   ```

## 🔈 Usage

Go to Settings. Auth for Tidal or add some network drives. Set the output hardware and try it out.


## 📝 License

**This software is provided free of charge for personal use only.**

The software is distributed as-is, without any warranty of any kind. By using this software, you acknowledge that you do so at your own risk, and the author assumes no liability for any damages, legal issues, or other consequences arising from its use.

Commercial use, selling, or redistributing this software in any form is not permitted.
