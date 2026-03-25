#!/bin/sh

# 1. Unlock the boot drive for writing
mount -o remount,rw /media/mmcblk0p1

# 2. Set custom machine name to miliza
setup-hostname miliza
hostname miliza

# 3. Fix DNS (Allows resolving internet radio URLs)
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

# 4. Fix System Time (Bypasses 'Certificate Not Yet Valid' SSL errors)
# Sets the clock to current time so HTTPS searches work immediately
date -s "2026-03-21 22:30:00"

# 5. Force HTTP Repositories (Reliable package downloading)
echo "http://dl-cdn.alpinelinux.org/alpine/latest-stable/main" > /etc/apk/repositories
echo "http://dl-cdn.alpinelinux.org/alpine/latest-stable/community" >> /etc/apk/repositories

# 6. Update and Install ALL packages
apk update
apk add avahi alsa-utils alsa-lib bluez bluez-tools dbus gstreamer gst-plugins-base \
    gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav \
    gobject-introspection caddy curl util-linux

# 7. Download the Miliza binary (using -k just in case of clock drift)
curl -kL https://miliza.eu/stage/miliza_stage_alpine_aarch64 -o /usr/local/bin/miliza_app
chmod +x /usr/local/bin/miliza_app

# 8. Create the OpenRC service (Real-Time + No Network Lockout)
cat << 'EOF' > /etc/init.d/miliza_app
#!/sbin/openrc-run
name="Miliza App"
command="/usr/bin/chrt"
command_args="-f 50 taskset -c 2,3 /usr/local/bin/miliza_app"
command_background=true
pidfile="/run/miliza_app.pid"

depend() {
    # 'provide net' bypasses the strict 'networking' service check
    provide net
}
EOF
chmod +x /etc/init.d/miliza_app

# 9. Configure Caddy (HTTP and HTTPS support for miliza.local)
mkdir -p /etc/caddy /var/www/html
cat << 'EOF' > /etc/caddy/Caddyfile
{
    pki {
        ca local {
            name "Miliza CA"
        }
    }
}
http://miliza.local {
    handle /miliza.crt {
        root * /var/www/html
        file_server
    }
    handle {
        reverse_proxy 127.0.0.1:5000
    }
}
https://miliza.local {
    reverse_proxy 127.0.0.1:5000
}
EOF

# 10. Enable services for boot
rc-update add avahi-daemon default
rc-update add dbus default
rc-update add bluetooth default
[ -f /etc/init.d/alsasound ] && rc-update add alsasound default
rc-update add miliza_app default
rc-update add caddy default

# 11. Start services NOW (using --nodeps to ignore networking config errors)
rc-service avahi-daemon start
rc-service dbus start
rc-service bluetooth start
[ -f /etc/init.d/alsasound ] && rc-service alsasound start
rc-service miliza_app start --nodeps
rc-service caddy start --nodeps

# 12. Expose the Root CA certificate for easy download
sleep 5
ROOT_CRT=$(find /var/lib/caddy /root -type f -name "root.crt" | grep "pki/authorities/local/root.crt" | head -n 1)
if [ -n "$ROOT_CRT" ]; then
    cp "$ROOT_CRT" /var/www/html/miliza.crt
    chmod 644 /var/www/html/miliza.crt
fi

# 13. Save this entire RAM state to the SD Card
lbu commit -d /media/mmcblk0p1