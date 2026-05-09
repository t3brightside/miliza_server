# Miliza Install
There's IMG for Raspberry Pi and universal install script. See which suits you best.
<br /><br />
## System Requirements
* **Architecture:** aarch64, x86_64, aarch32, x86_32
* **OS:** Debian-based Linux
* **Storage:** Approximately **6GB** of disk space. (A Debian-based OS brings lot of overhead, but this only impacts disk usage).
* **Memory:** Approximately **500MB RAM** usage for the entire system.
<br /><br />
## Raspberry Pi image install
There is an image file available at **https://miliza.eu**

1. **Flash the image** using Raspberry Pi Imager software and boot your Pi.
2. **If using Wi-Fi** connect to "Miliza Setup" and configure network.
3. **SSH** access `miliza / miliza123`, better change that pass!
<br /><br />
## Universal install script

Besides a fully functional Miliza instance, this setup configures Bluetooth (optional) with high-quality AAC codecs.

1.  **OS Install:** Install Debian based Linux with minimal package.
2.  **Script:** Download [install-deb-universal.sh](https://raw.githubusercontent.com/t3brightside/miliza_server/refs/heads/main/install-miliza-deb.sh).
3.  **Execute:** Run the script as root: `sudo ./install-miliza-deb.sh`
<br /><br />
## Usage

* **Access:** Visit ***http**://miliza.local* or IP
* **SSL Certificate:** Visit ***http**://miliza.local/miliza.crt* to download the certificate and install on your devices.
* **Web App:** With the cert in place visit ***https**://miliza.local* so you can install Miliza as a PWA.
* **Bluetooth:** To pair Bluetooth sources, initiate the search from your device and confirm the pairing within in Miliza.
