# Miliza on Raspberry Pi OS

Besides a fully functional Miliza instance, this setup configures Bluetooth with high-quality AAC codecs.

### System Requirements
* **Storage:** Approximately **6GB** of disk space. (The Debian-based OS includes more overhead than DietPi, but only impacts disk usage).
* **Memory:** Approximately **500MB RAM** usage for the entire system.

---

### Installation Steps

1.  **OS Install:** Install **Raspberry Pi OS Lite (64-bit)** on your SD card.
2.  **Download Script:** Download the `rpi_installer.sh` script to your Pi.
3.  **Permissions:** (Optional) Change the final domain name inside the file if you wish. Then, set the permissions:
    ```bash
    chmod 755 rpi_installer.sh
    ```
4.  **Execute:** Run the script as root:
    ```bash
    sudo ./rpi_installer.sh
    ```
5.  **Wait:** Be patient while the script finishes the configuration.
6.  **Access:** Visit **http://miliza.local** to access your music.

---

### Optional Steps

* **Tidal:** Authorize your Tidal account in the settings menu.
* **SSL Certificate:** Visit **http://miliza.local/miliza.crt** to download the certificate for your devices.
* **Web App:** Install the certificate on your phone or computer, then visit **https://miliza.local** to install Miliza as a Progressive Web App (PWA).
* **Updates:** Use the command `miliza-update` in the terminal to fetch the latest available version.
* **Bluetooth:** To pair Bluetooth sources, initiate the search from your device and confirm the pairing within the Miliza interface.
