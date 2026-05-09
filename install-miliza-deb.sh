#!/bin/bash
# ========================================================
# Miliza OS Setup (Universal x86_64 / aarch64 / x86_32 / aarch_32)
# Fully headless, optional AAC and Bluetooth setup
# Run this script as root in a Debian based distro
# ========================================================

set -e

# =========================================================
# 🚨 ERROR TRAP
# =========================================================
trap 'echo -e "\n❌ FATAL ERROR: Script crashed on line $LINENO. Setup aborted." ; exit 1' ERR

# Ensure the script is run with root privileges
if [ "$EUID" -ne 0 ]; then
  echo "❌ Error: Please run this script as root or using sudo."
  exit 1
fi

# =========================================================
# 🏗️ ARCHITECTURE DETECTION
# =========================================================
echo "=> Detecting system architecture..."
ARCH=$(uname -m)

if [ "$ARCH" = "x86_64" ]; then
    echo "   -> x86_64 architecture detected."
    MILIZA_BIN_URL="https://miliza.eu/latest/miliza_debian_x86_64_stable"
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    echo "   -> ARM64 architecture detected."
    MILIZA_BIN_URL="https://miliza.eu/latest/miliza_debian_aarch64_stable"
elif [ "$ARCH" = "i386" ] || [ "$ARCH" = "i686" ] || [ "$ARCH" = "x86_32" ]; then
    echo "   -> x86_32 (32-bit) architecture detected."
    MILIZA_BIN_URL="https://miliza.eu/latest/miliza_debian_x86_32_stable"
elif [[ "$ARCH" == armv* ]] || [ "$ARCH" = "aarch32" ]; then
    echo "   -> aarch_32 (ARM 32-bit) architecture detected."
    MILIZA_BIN_URL="https://miliza.eu/latest/miliza_debian_aarch_32_stable"
else
    echo "❌ ERROR: Unsupported architecture ($ARCH)."
    exit 1
fi

# =========================================================
# 🎧 INTERACTIVE PROMPTS
# =========================================================
echo ""
# Prompt for Hostname
read -p "=> Enter machine name (default 'miliza'): " INPUT_HOSTNAME
INPUT_HOSTNAME=${INPUT_HOSTNAME:-miliza}

# Sanitize input: lowercase, spaces to hyphens, strip invalid chars
SYSTEM_HOSTNAME=$(echo "$INPUT_HOSTNAME" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g' | sed 's/[^a-z0-9-]//g')

# Fallback just in case sanitization wipes the whole string
if [ -z "$SYSTEM_HOSTNAME" ]; then
    SYSTEM_HOSTNAME="miliza"
fi

# Dynamically set BT name based on the machine name (capitalizes first letter)
BT_DEVICE_NAME="${SYSTEM_HOSTNAME^} Hi-Fi"

echo "   -> Machine name set to: $SYSTEM_HOSTNAME ($SYSTEM_HOSTNAME.local)"
echo ""

# Prompt for Bluetooth
read -p "=> Do you want to install Bluetooth audio features? (y/n): " INSTALL_BT_PROMPT
if [[ "${INSTALL_BT_PROMPT,,}" == "y" || "${INSTALL_BT_PROMPT,,}" == "yes" ]]; then
    INSTALL_BT=true
    echo "   -> Bluetooth features WILL be installed."
else
    INSTALL_BT=false
    echo "   -> Bluetooth features WILL BE SKIPPED."
fi
echo ""

# --- CLEANUP EXISTING SERVICES FOR RE-RUNS ---
echo "=> Preparing environment..."
systemctl stop caddy miliza bluealsa bluetooth 2>/dev/null || true
rm -f /usr/local/bin/miliza-update # Ensure the old bash updater is dead

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

# 1. Set Hostname, Local DNS, & Fix Mac SSH Locales
echo "=> Configuring Hostname & Locales..."
echo "$SYSTEM_HOSTNAME" > /etc/hostname
sed -i "s/127.0.1.1.*/127.0.1.1\t$SYSTEM_HOSTNAME $SYSTEM_HOSTNAME.local/g" /etc/hosts
hostname "$SYSTEM_HOSTNAME" || true

echo "=> Fixing Locales to prevent APT/Perl warnings..."
echo "en_GB.UTF-8 UTF-8" > /etc/locale.gen
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen > /dev/null 2>&1
update-locale LANG=en_GB.UTF-8 LC_ALL=en_GB.UTF-8
export LANG=en_GB.UTF-8
export LC_ALL=en_GB.UTF-8

# 2. Pre-configure Bluetooth (Conditional)
if [ "$INSTALL_BT" = true ]; then
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
else
    echo "=> Skipping Bluetooth pre-configuration..."
fi

# 3. Purge Debian BlueALSA and Install Dependencies
echo "=> Installing System Dependencies..."
wait_for_apt
apt-get update

# Base packages required regardless of Bluetooth
BASE_PKGS="rclone fuse3 libgirepository-2.0-0 gir1.2-glib-2.0 python3-gi avahi-daemon dbus gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly gstreamer1.0-libav gstreamer1.0-tools gstreamer1.0-alsa gir1.2-gst-plugins-base-1.0 curl ca-certificates nano smbclient cifs-utils udisks2 id3v2"

wait_for_apt
apt-get install -y $BASE_PKGS

if [ "$INSTALL_BT" = true ]; then
    echo "=> Purging Debian BlueALSA and Installing Bluetooth Build Dependencies..."
    wait_for_apt
    apt-get purge -y bluez-alsa-utils || true
    
    BT_PKGS="libbluetooth3 libsbc1 libfreeaptx0 libldacbt-enc2 libldacbt-abr2 libfdk-aac2 libmp3lame0 libmpg123-0 libopus0 alsa-utils bluez bluez-tools rfkill git build-essential autoconf automake libtool pkg-config libasound2-dev libbluetooth-dev libglib2.0-dev libsbc-dev libfdk-aac-dev libfreeaptx-dev libldacbt-enc-dev libldacbt-abr-dev libmp3lame-dev libmpg123-dev libopus-dev libdbus-1-dev"
    
    wait_for_apt
    apt-get install -y $BT_PKGS
fi

echo "=> Configuring FUSE permissions for Cloud Storage..."
sed -i 's/#user_allow_other/user_allow_other/g' /etc/fuse.conf

# 4 & 5 & 6 & 7. Build BlueALSA, SystemD, Patch & Cleanup (Conditional)
if [ "$INSTALL_BT" = true ]; then
    echo "=> Building Custom BlueALSA with AAC, LDAC, aptX, Opus, and MP3..."
    PROJECT_DIR="/tmp/bluealsa-build-temp"
    rm -rf "$PROJECT_DIR"
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"

    git clone https://github.com/arkq/bluez-alsa.git .
    mkdir -p m4
    autoreconf --install --force --verbose

    ./configure --prefix=/usr \
        --enable-aac \
        --enable-aptx --enable-aptx-hd --with-libfreeaptx \
        --enable-ldac \
        --enable-mp3lame --enable-mpg123 \
        --enable-opus \
        --enable-faststream \
        --enable-midi \
        --enable-a2dpconf \
        --enable-aplay \
        --enable-systemd

    make -j$(nproc)
    make install

    ln -sf /usr/bin/bluealsad /usr/bin/bluealsa

    echo "=> Creating persistent BlueALSA state directory..."
    mkdir -p /usr/var/lib/bluealsa
    chmod 755 /usr/var/lib/bluealsa

    echo "=> Configuring Compiled BlueALSA SystemD Service..."
    cat << 'EOF' > /etc/systemd/system/bluealsa.service
[Unit]
Description=BluezALSA proxy
Requires=bluetooth.service
After=bluetooth.service

[Service]
Type=simple
ExecStartPre=/bin/sleep 2
ExecStart=/usr/bin/bluealsa -p a2dp-sink -p a2dp-source --aac-afterburner
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    echo "=> Protecting codec runtime libraries and cleaning up..."
    wait_for_apt
    apt-mark manual libfreeaptx0 libldacbt-enc2 libldacbt-abr2 libfdk-aac2 libmp3lame0 libmpg123-0 libopus0

    cd /root
    rm -rf "$PROJECT_DIR"
    wait_for_apt
    apt-get purge -y git build-essential autoconf automake libtool pkg-config \
        libasound2-dev libbluetooth-dev libglib2.0-dev libsbc-dev \
        libfdk-aac-dev libfreeaptx-dev libldacbt-enc-dev libldacbt-abr-dev \
        libmp3lame-dev libmpg123-dev libopus-dev libdbus-1-dev
    wait_for_apt
    apt-get autoremove -y
    apt-get clean

    echo "=> Patching Bluetooth Daemon..."
    mkdir -p /etc/systemd/system/bluetooth.service.d
    cat << 'EOF' > /etc/systemd/system/bluetooth.service.d/override.conf
[Service]
ExecStart=
ExecStart=/usr/libexec/bluetooth/bluetoothd --noplugin=hostname
EOF

else
    echo "=> Skipping BlueALSA compilation, setup, and Bluetooth daemon patching..."
fi

# 8. Install Caddy
echo "=> Installing Caddy..."
wait_for_apt
apt-get install -y caddy
rm -f /var/www/html/index.html /usr/share/caddy/index.html || true

# ---------------------------------------------------------
# 8.5 USB AUTOMOUNT & CLEANUP RULES
# ---------------------------------------------------------
echo "=> Configuring headless USB automounting..."

cat << 'EOF' > /etc/udev/rules.d/99-usb-automount.rules
ACTION=="add", SUBSYSTEMS=="usb", SUBSYSTEM=="block", ENV{ID_FS_USAGE}=="filesystem", RUN+="/usr/bin/systemd-mount --no-block --collect $devnode /media/USB-%k"
EOF

cat << 'EOF' > /etc/udev/rules.d/99-usb-cleanup.rules
ACTION=="remove", SUBSYSTEMS=="usb", SUBSYSTEM=="block", ENV{ID_FS_USAGE}=="filesystem", RUN+="/usr/bin/systemd-umount /media/USB-%k", RUN+="/bin/rmdir /media/USB-%k"
EOF

udevadm control --reload-rules
udevadm trigger

# 9. Fetch Miliza App
echo "=> Fetching Miliza App (Stable) for $ARCH..."
mkdir -p /root/.config/miliza/data
systemctl stop miliza 2>/dev/null || true
curl -kL "$MILIZA_BIN_URL" -o /usr/local/bin/miliza
chmod +x /usr/local/bin/miliza

# 10. Systemd Service (SMART CPU PINNING & CONDITIONAL BT TARGET)
echo "=> Creating Miliza SystemD Service..."
CORES=$(nproc)
if [ "$CORES" -ge 4 ]; then
    EXEC_CMD="/usr/bin/chrt -f 50 taskset -c 2,3 /usr/local/bin/miliza"
elif [ "$CORES" -eq 2 ]; then
    EXEC_CMD="/usr/bin/chrt -f 50 taskset -c 1 /usr/local/bin/miliza"
else
    EXEC_CMD="/usr/bin/chrt -f 50 /usr/local/bin/miliza"
fi

BT_TARGET=""
[ "$INSTALL_BT" = true ] && BT_TARGET="bluetooth.target"

cat << EOF > /etc/systemd/system/miliza.service
[Unit]
Description=Miliza App
After=network.target dbus.service $BT_TARGET

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

caddy fmt --overwrite /etc/caddy/Caddyfile

# 12. Enable & Start Services
echo "=> Starting all services..."
systemctl daemon-reload
systemctl enable caddy avahi-daemon miliza

if [ "$INSTALL_BT" = true ]; then
    systemctl enable bluetooth bluealsa
fi

systemctl reload dbus || true
wait_for_service dbus

if [ "$INSTALL_BT" = true ]; then
    systemctl restart bluetooth
    wait_for_service bluetooth

    systemctl restart bluealsa
    wait_for_service bluealsa
fi

systemctl restart miliza
wait_for_service miliza

systemctl restart caddy
wait_for_service caddy
caddy reload --config /etc/caddy/Caddyfile || true

# 13. Root CA Export
echo "=> Exporting Caddy Root CA..."

CADDY_TIMEOUT=30
while ! curl -s http://localhost:2019/config/ > /dev/null; do
    sleep 0.5
    ((CADDY_TIMEOUT--))
    if [ "$CADDY_TIMEOUT" -le 0 ]; then
        echo "❌ ERROR: Caddy API failed to respond in time."
        exit 1
    fi
done

curl -sk "https://${SYSTEM_HOSTNAME}.local" > /dev/null || true

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

# 14. Verification & IP Retrieval


# Grab the primary local IP address to show the user
LOCAL_IP=$(hostname -I | awk '{print $1}')
LOCAL_IP=${LOCAL_IP:-"UNAVAILABLE"}

echo "-------------------------------------------------------"
echo "✅ Setup Complete!"
echo "-------------------------------------------------------"
HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}\n" "http://${SYSTEM_HOSTNAME}.local/${SYSTEM_HOSTNAME}.crt")
if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ Certificate ready at: http://${SYSTEM_HOSTNAME}.local/${SYSTEM_HOSTNAME}.crt"
fi
echo "🌐 You can now access your Miliza system at:"
echo "   -> http://${SYSTEM_HOSTNAME}.local"
if [ "$LOCAL_IP" != "UNAVAILABLE" ]; then
echo "   -> http://${LOCAL_IP}"
fi
echo "-------------------------------------------------------"
