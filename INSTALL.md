## System Requirements
* **Storage:** Approximately **6GB** of disk space. (A Debian-based OS brings lot of overhead, but this only impacts disk usage).
* **Memory:** Approximately **500MB RAM** usage for the entire system.

## Raspberry Pi OS image install
There is an img file available at **https://miliza.eu**

1. **Flash the image** using Raspberry Pi Imager software and boot your Pi.
2. **If using Wi-Fi** connect to "Miliza Setup" and configure network.

## Universal installer script

Besides a fully functional Miliza instance, this setup configures Bluetooth with high-quality AAC codecs.

1.  **OS Install:** Install aarch64 or x86_64 Debian based Linux with minimal package.
2.  **Script:** Download the `install-deb-universal.sh` script from this repository.
3.  **Execute:** Run the script as root:
    ```bash
    sudo ./install-deb-universal.sh
    ```

## Usage

* **Access:** Visit ***http**://miliza.local* or IP to access Miliza
* **SSL Certificate:** Visit ***http**://miliza.local/miliza.crt* to download the certificate and install on your devices.
* **Web App:** With the cert in place visit ***https**://miliza.local* to install Miliza as a Progressive Web App (PWA).
* **Bluetooth:** To pair Bluetooth sources, initiate the search from your device and confirm the pairing within the Miliza interface.
