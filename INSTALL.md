## System Requirements
* **Storage:** Approximately **6GB** of disk space. (A Debian-based OS brings lot of overhead, but this only impacts disk usage).
* **Memory:** Approximately **500MB RAM** usage for the entire system.

## Universal installer script

Besides a fully functional Miliza instance, this setup configures Bluetooth with high-quality AAC codecs.

---

### Installation Steps

1.  **OS Install:** Install aarch64 or x86_64 Debian based Linux with minimal package.
2.  **Download Script:** Download the `install-deb-universal.sh` script to your machine.
3.  **Execute:** Run the script as root:
    ```bash
    sudo ./install-deb-universal.sh
    ```
4.  **Access:** Visit **http://miliza.local** to access your music.

---

### Optional Steps

* **SSL Certificate:** Visit **http://miliza.local/miliza.crt** to download the certificate and install on your devices.
* **Web App:** With the cert in place visit **https://miliza.local** to install Miliza as a Progressive Web App (PWA).
* **Bluetooth:** To pair Bluetooth sources, initiate the search from your device and confirm the pairing within the Miliza interface.
