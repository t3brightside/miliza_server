#!/bin/bash
# ==============================
# Miliza DietPi Setup (Master Edition)
# Fully headless, persistent, DBus-ready, AAC BlueALSA
# 100% Deterministic, Original Update Logic, Live Terminal Polling
# ==============================

set -e

# =========================================================
# ⚙️ CONFIGURATION BLOCK
# =========================================================
SYSTEM_HOSTNAME="miliza"
BT_DEVICE_NAME="Miliza Hi-Fi"
LOCKFILE="/run/miliza_setup.lock"
# =========================================================

# 🚨 ERROR TRAP: Cleanup lock/interceptor and notify on crash
trap 'rm -f "$LOCKFILE" /etc/profile.d/99-miliza-setup-lock.sh ; echo -e "\n❌ FATAL ERROR: Script crashed on line $LINENO. Setup aborted." ; exit 1' ERR

# --- CREATE SYSTEM-WIDE LOGIN INTERCEPTOR ---
touch "$LOCKFILE"

cat << 'EOF' > /etc/profile.d/99-miliza-setup-lock.sh
#!/bin/bash
LOCKFILE="/run/miliza_setup.lock"

# Only run this for interactive terminal sessions
if [[ $- == *i* ]] && [ -f "$LOCKFILE" ]; then
    CHECKS=0
    while [ -f "$LOCKFILE" ]; do
        clear
        ((CHECKS++))
        echo -e "\e[1;33m=================================================================\e[0m"
        echo -e "\e[1;33m ⚠️  MILIZA SETUP IS IN PROGRESS \e[0m"
        echo -e "\e[1;33m Please wait until the installation completes. \e[0m"
        echo -e "\e[1;33m=================================================================\e[0m"
        echo -e "[ INFO ] Status check \e[1;36m#${CHECKS}\e[0m at \e[1;36m$(date +"%H:%M:%S")\e[0m..."
        echo -e "[ INFO ] Waiting 5 seconds... (Press CTRL+C to abort)"

        # Wait 5 seconds, but allow the user to interrupt with Ctrl+C
        trap 'break' INT
        sleep 5
        trap - INT
    done

    echo ""
    echo -e "\e[1;32m[ OK ] Setup complete! Resuming normal login...\e[0m"
    sleep 1
fi
EOF
chmod +x /etc/profile.d/99-miliza-setup-lock.sh

# Notify any currently open terminals
wall "⚠️ MILIZA SETUP HAS STARTED. Please do not modify system files."

echo "=> Starting Master Setup for $SYSTEM_HOSTNAME..."

# ---------------------------------------------------------
# 🛡️ DETERMINISTIC WAITERS
# ---------------------------------------------------------
wait_for_apt() {
    while fuser /var/lib/dpkg/lock >/dev/null 2>&1 || fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
        sleep 0.5
    done
}

wait_for_service() {
    local service=$1
    local timeout=30
    echo -n "   -> Waiting for $service to report active..."
    while [ $timeout -gt 0 ]; do
        if systemctl is-active --quiet "$service"; then
            echo " [READY]"
            return 0
        fi
        sleep 0.5
        ((timeout--))
    done
    echo " [FAILED]"
    exit 1
}

# 1. Set Hostname & Local DNS
echo "=> Configuring Hostname to '$SYSTEM_HOSTNAME'..."
echo "$SYSTEM_HOSTNAME" > /etc/hostname
sed -i "s/127.0.1.1.*/127.0.1.1\t$SYSTEM_HOSTNAME $SYSTEM_HOSTNAME.local/g" /etc/hosts
hostname "$SYSTEM_HOSTNAME" || true

# 2. Pre-configure Bluetooth
echo "=> Pre-configuring Bluetooth..."
mkdir -p /etc/bluetooth
cat << EOF > /etc/bluetooth/main.conf
[General]
Name = $BT_DEVICE_NAME
Class = 0x200404
DiscoverableTimeout = 0
ControllerMode = bredr

[Policy]
AutoEnable=false
EOF

# 3. Install Dependencies
echo "=> Installing Core Dependencies & Build Tools..."
wait_for_apt
apt-get update
wait_for_apt
apt-get install -y \
    rclone fuse3 \
    libbluetooth3 libsbc1 libfreeaptx0 libldacbt-enc2 libldacbt-abr2 \
    libgirepository-2.0-0 gir1.2-glib-2.0 python3-gi \
    avahi-daemon alsa-utils bluez bluez-tools rfkill dbus \
    gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav gstreamer1.0-tools gstreamer1.0-alsa \
    gir1.2-gst-plugins-base-1.0 libfdk-aac2 curl ca-certificates nano \
    git build-essential autoconf automake libtool pkg-config \
    libasound2-dev libbluetooth-dev libglib2.0-dev libsbc-dev \
    libfdk-aac-dev libfreeaptx-dev libldacbt-enc-dev libldacbt-abr-dev \
    libdbus-1-dev libsystemd-dev smbclient cifs-utils udisks2 id3v2 rsync

echo "=> Configuring FUSE permissions for Cloud Storage..."
sed -i 's/#user_allow_other/user_allow_other/g' /etc/fuse.conf

# 4. Compile BlueALSA
echo "=> Building Custom BlueALSA with AAC..."
PROJECT_DIR="/tmp/bluealsa-build-temp"
rm -rf "$PROJECT_DIR"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

git clone https://github.com/arkq/bluez-alsa.git .
mkdir -p m4
autoreconf --install --force --verbose
./configure --prefix=/usr --enable-aac --enable-aptx --with-libfreeaptx --enable-ldac --enable-aplay --enable-systemd
make -j$(nproc)
make install
ln -sf /usr/bin/bluealsad /usr/bin/bluealsa

echo "=> Enforcing BlueALSA AAC SystemD Service..."
cat << 'EOF' > /etc/systemd/system/bluealsa.service
[Unit]
Description=BluezALSA proxy
Requires=bluetooth.service
After=bluetooth.service

[Service]
Type=simple
ExecStart=/usr/bin/bluealsad -p a2dp-sink -p a2dp-source --all-codecs --aac-afterburner
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 5. Purge Build Tools
echo "=> Protecting high-res codec runtime libraries..."
wait_for_apt
apt-mark manual libfreeaptx0 libldacbt-enc2 libldacbt-abr2

echo "=> Cleaning up build environment..."
cd /root
rm -rf "$PROJECT_DIR"
wait_for_apt
apt-get purge -y git build-essential autoconf automake libtool pkg-config \
    libasound2-dev libbluetooth-dev libglib2.0-dev libsbc-dev \
    libfdk-aac-dev libfreeaptx-dev libldacbt-enc-dev libldacbt-abr-dev \
    libdbus-1-dev libsystemd-dev
wait_for_apt
apt-get autoremove -y
apt-get clean

# 6. Patch Bluetooth Daemon
echo "=> Patching Bluetooth Daemon..."
mkdir -p /etc/systemd/system/bluetooth.service.d
cat << 'EOF' > /etc/systemd/system/bluetooth.service.d/override.conf
[Service]
ExecStart=
ExecStart=/usr/libexec/bluetooth/bluetoothd --noplugin=hostname
EOF

# 7. Install Caddy
echo "=> Installing Caddy..."
wait_for_apt
apt-get install -y caddy
rm -f /var/www/html/index.html /usr/share/caddy/index.html || true

# 8. Fetch Miliza App
echo "=> Fetching Miliza Alpha App..."
mkdir -p /root/.config/miliza/data
systemctl stop miliza 2>/dev/null || true
curl -kL https://miliza.eu/fileadmin/user_upload/latest/miliza_alpha_debian_aarch64_latest -o /usr/local/bin/miliza
chmod +x /usr/local/bin/miliza

# ---------------------------------------------------------
# 8.5 USB AUTOMOUNT & CLEANUP RULES
# ---------------------------------------------------------
echo "=> Configuring headless USB automounting..."

# 1. The Mount Rule
# When a USB block device with a filesystem is plugged in, systemd mounts it to /media/USB-<partition>
cat << 'EOF' > /etc/udev/rules.d/99-usb-automount.rules
ACTION=="add", SUBSYSTEMS=="usb", SUBSYSTEM=="block", ENV{ID_FS_USAGE}=="filesystem", RUN+="/usr/bin/systemd-mount --no-block --collect $devnode /media/USB-%k"
EOF

# 2. The Cleanup Rule
# When the USB is unplugged, unmount it cleanly and delete the empty folder from /media/
cat << 'EOF' > /etc/udev/rules.d/99-usb-cleanup.rules
ACTION=="remove", SUBSYSTEMS=="usb", SUBSYSTEM=="block", ENV{ID_FS_USAGE}=="filesystem", RUN+="/usr/bin/systemd-umount /media/USB-%k", RUN+="/bin/rmdir /media/USB-%k"
EOF

# Reload udev so the rules take effect immediately
udevadm control --reload-rules
udevadm trigger

# 9. Miliza Smart Update Script
echo "=> Creating Miliza Update Service..."
cat << 'EOF' > /usr/local/bin/miliza-update
#!/bin/bash

CURRENT_BIN="/usr/local/bin/miliza"
TEMP_BIN="/tmp/miliza_new"

# Default to latest, but switch to test if the argument is provided
SUFFIX="latest"
if [ "$1" = "test" ]; then
    SUFFIX="test"
    echo "=> [Test Mode] Fetching the test branch..."
fi

URL="https://miliza.eu/fileadmin/user_upload/latest/miliza_alpha_debian_aarch64_${SUFFIX}"

echo "=> Checking server for Miliza updates ($SUFFIX)..."

if [ ! -f "$CURRENT_BIN" ]; then
    echo "   [!] Current binary not found. Forcing fresh download."
    touch -d "2000-01-01 00:00:00" "$CURRENT_BIN"
fi

HTTP_STATUS=$(curl -kL -s -w "%{http_code}" -z "$CURRENT_BIN" -o "$TEMP_BIN" "$URL")

if [ "$HTTP_STATUS" = "200" ]; then
    if [ -s "$TEMP_BIN" ]; then
        echo "✅ New version downloaded successfully!"
        echo "=> Stopping service..."
        systemctl stop miliza
        echo "=> Applying update..."
        mv "$TEMP_BIN" "$CURRENT_BIN"
        chmod +x "$CURRENT_BIN"
        echo "=> Restarting service..."
        systemctl start miliza
        echo "🚀 Update complete. Miliza is running the ${SUFFIX} version."
    else
        echo "⚠️ ERROR: Server returned success, but file is empty!"
        rm -f "$TEMP_BIN"
    fi
elif [ "$HTTP_STATUS" = "304" ]; then
    echo "👍 You are already running the ${SUFFIX} version. No update needed."
    rm -f "$TEMP_BIN"
else
    echo "❌ Update failed! HTTP status code: $HTTP_STATUS"
    rm -f "$TEMP_BIN"
fi
EOF
chmod +x /usr/local/bin/miliza-update

# 10. Systemd Service (SMART CPU PINNING)
CORES=$(nproc)
if [ "$CORES" -ge 4 ]; then
    EXEC_CMD="/usr/bin/chrt -f 50 taskset -c 2,3 /usr/local/bin/miliza"
elif [ "$CORES" -eq 2 ]; then
    EXEC_CMD="/usr/bin/chrt -f 50 taskset -c 1 /usr/local/bin/miliza"
else
    EXEC_CMD="/usr/bin/chrt -f 50 /usr/local/bin/miliza"
fi

cat << EOF > /etc/systemd/system/miliza.service
[Unit]
Description=Miliza App
After=network.target bluetooth.target dbus.service

[Service]
ExecStart=$EXEC_CMD
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# 11. Configure Caddy & Network Buffers
echo "=> Increasing UDP buffer sizes for HTTP/3..."
cat << EOF > /etc/sysctl.d/99-caddy-quic.conf
net.core.rmem_max=2500000
net.core.wmem_max=2500000
EOF
sysctl --system > /dev/null || true

echo "=> Configuring Caddy Reverse Proxy for ${SYSTEM_HOSTNAME}.local..."
mkdir -p /var/www/html
cat << EOF > /etc/caddy/Caddyfile
{
    skip_install_trust
    pki {
        ca local {
            name "${SYSTEM_HOSTNAME} CA"
        }
    }
}
http://${SYSTEM_HOSTNAME}.local {
    handle /${SYSTEM_HOSTNAME}.crt {
        root * /var/www/html
        file_server
    }
    handle {
        reverse_proxy 127.0.0.1:5000
    }
}
https://${SYSTEM_HOSTNAME}.local {
    reverse_proxy 127.0.0.1:5000
}
EOF

# Auto-format the Caddyfile to prevent log warnings
caddy fmt --overwrite /etc/caddy/Caddyfile

# 12. Enable & Start Services
echo "=> Starting all services..."
systemctl daemon-reload
systemctl enable caddy avahi-daemon miliza bluetooth bluealsa

# 'reload' instead of 'restart'. This loads new configs without breaking live connections.
systemctl reload dbus || true
wait_for_service dbus

systemctl restart bluetooth
wait_for_service bluetooth

systemctl restart bluealsa
wait_for_service bluealsa

systemctl restart miliza
wait_for_service miliza

systemctl restart caddy
wait_for_service caddy
caddy reload --config /etc/caddy/Caddyfile || true

# 13. Root CA Export (Deterministic Path & Safe Timeout)
echo "=> Exporting Caddy Root CA..."

# Wait for Caddy API to respond (WITH TIMEOUT)
CADDY_TIMEOUT=30
while ! curl -s http://localhost:2019/config/ > /dev/null; do
    sleep 0.5
    ((CADDY_TIMEOUT--))
    if [ "$CADDY_TIMEOUT" -le 0 ]; then
        echo "❌ ERROR: Caddy API failed to respond in time."
        exit 1 # This will trigger the trap and clean up the lock
    fi
done

# Trigger a request to ensure the certificate is minted
curl -sk "https://${SYSTEM_HOSTNAME}.local" > /dev/null || true

# Deterministic path for the caddy user's local root CA
ROOT_CRT="/var/lib/caddy/.local/share/caddy/pki/authorities/local/root.crt"

CRT_TIMEOUT=30
while [ $CRT_TIMEOUT -gt 0 ]; do
    if [ -f "$ROOT_CRT" ]; then break; fi
    sleep 0.5
    ((CRT_TIMEOUT--))
done

if [ -f "$ROOT_CRT" ]; then
    cp "$ROOT_CRT" "/var/www/html/${SYSTEM_HOSTNAME}.crt"
    chown caddy:caddy "/var/www/html/${SYSTEM_HOSTNAME}.crt"
    chmod 644 "/var/www/html/${SYSTEM_HOSTNAME}.crt"
    echo "✅ Root CA successfully exported."
else
    echo "❌ ERROR: Root CA not found at $ROOT_CRT"
fi

# 14. Verification
HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}\n" "http://${SYSTEM_HOSTNAME}.local/${SYSTEM_HOSTNAME}.crt")
if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ Success! Certificate downloadable at: http://${SYSTEM_HOSTNAME}.local/${SYSTEM_HOSTNAME}.crt"
fi

# --- CLEANUP LOCK & INTERCEPTOR ---
rm -f "$LOCKFILE"
rm -f /etc/profile.d/99-miliza-setup-lock.sh

echo "-------------------------------------------------------"
echo "✅ $SYSTEM_HOSTNAME Master Setup Complete!"
echo "-------------------------------------------------------"
