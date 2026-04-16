#!/bin/sh
# =========================================================
# Miliza Alpine Linux Headless Setup
# Native Alpine bluez-alsa integration with AAC
# Run this script as a root in a fresh Alpine linux install
# =========================================================

set -e

# =========================================================
# ⚙️ CONFIGURATION BLOCK
# =========================================================
SYSTEM_HOSTNAME="miliza"
BT_DEVICE_NAME="Miliza Hi-Fi"
LOCKFILE="/run/miliza_setup.lock"
# =========================================================

# 🚨 ERROR TRAP: Cleanup lock/interceptor and notify on crash in POSIX sh
SETUP_SUCCESS=0
trap 'if [ "$SETUP_SUCCESS" -ne 1 ]; then rm -f "$LOCKFILE" /etc/profile.d/99-miliza-setup-lock.sh ; echo -e "\n❌ FATAL ERROR: Setup aborted prematurely. Check output above." ; exit 1; fi' EXIT

# --- CREATE SYSTEM-WIDE LOGIN INTERCEPTOR ---
touch "$LOCKFILE"
mkdir -p /etc/profile.d

cat << 'EOF' > /etc/profile.d/99-miliza-setup-lock.sh
#!/bin/sh
LOCKFILE="/run/miliza_setup.lock"

# Only run this for interactive terminal sessions
case "$-" in
    *i*)
        if [ -f "$LOCKFILE" ]; then
            CHECKS=0
            while [ -f "$LOCKFILE" ]; do
                clear
                CHECKS=$((CHECKS + 1))
                echo -e "\033[1;33m=================================================================\033[0m"
                echo -e "\033[1;33m ⚠️  MILIZA SETUP IS IN PROGRESS \033[0m"
                echo -e "\033[1;33m Please wait until the installation completes. \033[0m"
                echo -e "\033[1;33m=================================================================\033[0m"
                echo -e "[ INFO ] Status check \033[1;36m#${CHECKS}\033[0m at \033[1;36m$(date +"%H:%M:%S")\033[0m..."
                echo -e "[ INFO ] Waiting 5 seconds... (Press CTRL+C to abort)"

                trap 'break' INT
                sleep 5
                trap - INT
            done

            echo ""
            echo -e "\033[1;32m[ OK ] Setup complete! Resuming normal login...\033[0m"
            sleep 1
        fi
        ;;
esac
EOF
chmod +x /etc/profile.d/99-miliza-setup-lock.sh

# Notify all currently open terminals (Native alternative to 'wall')
for tty in /dev/pts/* /dev/tty[0-9]*; do
    if [ -w "$tty" ]; then
        echo "⚠️ MILIZA SETUP HAS STARTED. Please do not modify system files." > "$tty" 2>/dev/null || true
    fi
done

echo "=> Starting Master Setup for $SYSTEM_HOSTNAME on Alpine Linux..."

# ---------------------------------------------------------
# 🛡️ DETERMINISTIC WAITERS (Native POSIX)
# ---------------------------------------------------------
wait_for_apk() {
    # Natively checks if the 'apk' process is running, ignoring static files
    while pidof apk >/dev/null 2>&1; do
        sleep 0.5
    done
}

wait_for_service() {
    local service=$1
    local timeout=30
    echo -n "   -> Waiting for $service to report started..."
    while [ $timeout -gt 0 ]; do
        if rc-service "$service" status 2>/dev/null | grep -q "started"; then
            echo " [READY]"
            return 0
        fi
        sleep 0.5
        timeout=$((timeout - 1))
    done
    echo " [WARNING: Service failed/missing hardware. Continuing...]"
    return 0
}

# 1. Set Hostname & Local DNS
echo "=> Configuring Hostname to '$SYSTEM_HOSTNAME'..."
echo "$SYSTEM_HOSTNAME" > /etc/hostname
sed -i "s/127.0.1.1.*/127.0.1.1\t$SYSTEM_HOSTNAME $SYSTEM_HOSTNAME.local/g" /etc/hosts
hostname -F /etc/hostname || true

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

# 3. Install Dependencies (GUI-Free Edition)
echo "=> Installing Core Dependencies..."
wait_for_apk
# Switch to edge branch for the latest packages
sed -i -e 's/v[0-9]\.[0-9]*/edge/g' /etc/apk/repositories
# Unlock the community repository
sed -i '/community/s/^#//' /etc/apk/repositories
apk update
wait_for_apk

apk add --no-cache \
    glib python3 avahi alsa-utils bluez bluez-alsa bluez-alsa-utils dbus util-linux coreutils \
    gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav gstreamer-tools \
    curl ca-certificates nano

# 4. Configure Native BlueALSA
echo "=> Configuring Native BlueALSA with AAC and High-Res Codecs..."
cat << 'EOF' > /etc/conf.d/bluealsa
# Custom Miliza High-Res Audio Arguments
BLUEALSA_CONF="-p a2dp-sink -p a2dp-source"
EOF

# 5. Patch Bluetooth Daemon
echo "=> Patching Bluetooth Daemon for Alpine..."
echo 'command_args="--noplugin=hostname"' > /etc/conf.d/bluetooth

# 6. Install Caddy
echo "=> Installing Caddy..."
wait_for_apk
apk add --no-cache caddy
mkdir -p /var/www/html
rm -f /var/www/html/index.html /usr/share/caddy/index.html || true

# 7. Fetch Miliza App
echo "=> Fetching Miliza Alpha App..."
mkdir -p /root/.config/miliza/data
rc-service miliza stop 2>/dev/null || true
curl -kL https://miliza.eu/fileadmin/user_upload/latest/miliza_alpha_alpine_aarch64_latest -o /usr/local/bin/miliza
chmod +x /usr/local/bin/miliza

# 8. Miliza Smart Update Script
echo "=> Creating Miliza Update Service..."
cat << 'EOF' > /usr/local/bin/miliza-update
#!/bin/sh

CURRENT_BIN="/usr/local/bin/miliza"
TEMP_BIN="/tmp/miliza_new"

SUFFIX="latest"
if [ "$1" = "test" ]; then
    SUFFIX="test"
    echo "=> [Test Mode] Fetching the test branch..."
fi

URL="https://miliza.eu/fileadmin/user_upload/latest/miliza_alpha_alpine_aarch64_${SUFFIX}"

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
        rc-service miliza stop
        echo "=> Applying update..."
        mv "$TEMP_BIN" "$CURRENT_BIN"
        chmod +x "$CURRENT_BIN"
        echo "=> Restarting service..."
        rc-service miliza start
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

# 9. OpenRC Service (SMART CPU PINNING)
CORES=$(nproc)
if [ "$CORES" -ge 4 ]; then
    EXEC_ARGS="-f 50 taskset -c 2,3 /usr/local/bin/miliza"
elif [ "$CORES" -eq 2 ]; then
    EXEC_ARGS="-f 50 taskset -c 1 /usr/local/bin/miliza"
else
    EXEC_ARGS="-f 50 /usr/local/bin/miliza"
fi

cat << EOF > /etc/init.d/miliza
#!/sbin/openrc-run

name="miliza"
description="Miliza App"
command="/usr/bin/chrt"
command_args="$EXEC_ARGS"
command_background=true
pidfile="/run/\${RC_SVCNAME}.pid"
command_user="root:root"

depend() {
    need net dbus bluetooth
}
EOF
chmod +x /etc/init.d/miliza

# 10. Configure Caddy & Network Buffers
echo "=> Increasing UDP buffer sizes for HTTP/3..."
cat << EOF > /etc/sysctl.d/99-caddy-quic.conf
net.core.rmem_max=2500000
net.core.wmem_max=2500000
EOF
sysctl -p /etc/sysctl.d/99-caddy-quic.conf > /dev/null || true

echo "=> Configuring Caddy Reverse Proxy for ${SYSTEM_HOSTNAME}.local..."
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

# 11. Enable & Start Services
echo "=> Enabling and starting all services via OpenRC..."
rc-update add dbus default
rc-update add bluetooth default
rc-update add bluealsa default
rc-update add avahi-daemon default
rc-update add caddy default
rc-update add miliza default

rc-service dbus restart || true
wait_for_service dbus
sleep 1

rc-service avahi-daemon restart || true
wait_for_service avahi-daemon
sleep 1

rc-service bluetooth restart || true
wait_for_service bluetooth
sleep 1

rc-service bluealsa restart || true
wait_for_service bluealsa
sleep 1

rc-service miliza restart || true
wait_for_service miliza
sleep 1

rc-service caddy restart || true
wait_for_service caddy
caddy reload --config /etc/caddy/Caddyfile || true

# 12. Root CA Export
echo "=> Exporting Caddy Root CA..."

CADDY_TIMEOUT=30
while ! curl -s http://localhost:2019/config/ > /dev/null; do
    sleep 0.5
    CADDY_TIMEOUT=$((CADDY_TIMEOUT - 1))
    if [ "$CADDY_TIMEOUT" -le 0 ]; then
        echo "❌ ERROR: Caddy API failed to respond in time."
        exit 1
    fi
done

curl -sk "https://${SYSTEM_HOSTNAME}.local" > /dev/null || true

ROOT_CRT=$(find /var/lib/caddy /usr/share/caddy -name root.crt 2>/dev/null | grep "caddy/pki/authorities/local/root.crt" | head -n 1)

CRT_TIMEOUT=30
while [ $CRT_TIMEOUT -gt 0 ]; do
    if [ -n "$ROOT_CRT" ] && [ -f "$ROOT_CRT" ]; then break; fi
    sleep 0.5
    ROOT_CRT=$(find /var/lib/caddy /usr/share/caddy -name root.crt 2>/dev/null | grep "caddy/pki/authorities/local/root.crt" | head -n 1)
    CRT_TIMEOUT=$((CRT_TIMEOUT - 1))
done

if [ -n "$ROOT_CRT" ] && [ -f "$ROOT_CRT" ]; then
    cp "$ROOT_CRT" "/var/www/html/${SYSTEM_HOSTNAME}.crt"
    chown caddy:caddy "/var/www/html/${SYSTEM_HOSTNAME}.crt"
    chmod 644 "/var/www/html/${SYSTEM_HOSTNAME}.crt"
    echo "✅ Root CA successfully exported."
else
    echo "❌ ERROR: Root CA not found."
fi

# 13. Verification
echo "=> Verifying Caddy Web Server..."
HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}\n" "http://${SYSTEM_HOSTNAME}.local/${SYSTEM_HOSTNAME}.crt" || echo "000")
if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ Success! Certificate downloadable at: http://${SYSTEM_HOSTNAME}.local/${SYSTEM_HOSTNAME}.crt"
else
    echo "⚠️  Note: Internal verification of ${SYSTEM_HOSTNAME}.local failed (HTTP $HTTP_STATUS), but Caddy is running."
    echo "   You should still be able to access it from other devices on your network!"
fi

# --- CLEANUP LOCK & INTERCEPTOR ---
SETUP_SUCCESS=1
rm -f "$LOCKFILE"
rm -f /etc/profile.d/99-miliza-setup-lock.sh

echo "-------------------------------------------------------"
echo "✅ $SYSTEM_HOSTNAME Master Setup Complete (Alpine Edition)!"
echo "-------------------------------------------------------"
