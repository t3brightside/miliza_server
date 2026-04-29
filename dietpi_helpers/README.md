# Miliza on Raspberry Pi

This setup is based on a **DietPi** installation. In addition to a fully functional Miliza instance, it configures Bluetooth with high-quality AAC codecs.

### System Requirements
* **Storage:** Approximately **1.7GB** of disk space.
* **Memory:** Approximately **500MB RAM** usage for the entire system.

---

### Installation Steps

1.  **Flash the OS:** Use the [RPI Imager](https://www.raspberrypi.com/software/) to find **DietPi** and flash it to your SD card.
2.  **Configuration:** In the root directory of your new SD card, replace the default `dietpi.txt` with [this version](https://raw.githubusercontent.com/t3brightside/miliza_server/refs/heads/main/dietpi_helpers/dietpi.txt).
3.  **Network:** Preconfigure your WiFi or Ethernet settings.
4.  **Boot:** Insert the card into your Raspberry Pi and power it on. The installation process takes around **15 to 20 minutes**. Please be patient!
5.  **Access:** Once finished, visit **http://miliza.local** to start listening to music.

---

### Optional Steps

* **Tidal:** Authorize your Tidal account in the settings menu.
* **SSL Certificate:** Visit **http://miliza.local/miliza.crt** to download the security certificate for your devices.
* **Web App:** Install the downloaded certificate on your phone, then visit **https://miliza.local** to install Miliza as a Progressive Web App (PWA).
* **Updates:** You can run `miliza-update` in the terminal at any time to fetch the latest version.
* **Bluetooth:** To pair a Bluetooth source, initiate the pairing process from your mobile device/transmitter and confirm the connection via the Miliza interface.
