#!/usr/bin/env bash
set -euo pipefail
if [[ $EUID != 0 ]]; then
    echo "Esegui con sudo bash ottimizza-pi.sh" >&2
    exit 1
fi
if [[ $(findmnt -n -o FSTYPE /) == overlay ]]; then
    echo "Disattiva prima overlay e protezione boot da raspi-config, riavvia e ripeti. Dopo il collaudo riattiva entrambe." >&2
    exit 1
fi
command -v zramctl >/dev/null
test -f /etc/rpi/swap.conf
test -f /usr/lib/scanservjs/server/express-configurer.js
systemctl set-default multi-user.target
install -d /etc/rpi/swap.conf.d /etc/systemd/system/scanservjs.service.d /etc/systemd/system/tmp.mount.d /etc/scanservjs/sane
cat > /etc/rpi/swap.conf.d/90-print-server.conf <<'EOF'
[Main]
Mechanism=zram
[Zram]
FixedSizeMiB=384
EOF
cat > /etc/systemd/system/scanservjs.service.d/imagemagick.conf <<'EOF'
[Service]
Environment=MAGICK_MEMORY_LIMIT=24MiB
Environment=MAGICK_MAP_LIMIT=0
Environment=MAGICK_DISK_LIMIT=256MiB
Environment=MAGICK_THREAD_LIMIT=1
Environment=MAGICK_TEMPORARY_PATH=/tmp
EOF
cat > /etc/systemd/system/tmp.mount.d/print-server.conf <<'EOF'
[Mount]
Options=mode=1777,strictatime,nosuid,nodev,size=320M,nr_inodes=1m
EOF
printf '%s\n' xerox_mfp > /etc/scanservjs/sane/dll.conf
printf '%s\n' 'usb 0x04e8 0x3461' > /etc/scanservjs/sane/xerox_mfp.conf
cat > /etc/systemd/system/scanservjs.service.d/samsung.conf <<'EOF'
[Service]
Environment=SANE_CONFIG_DIR=/etc/scanservjs/sane
EOF
install -d /usr/local/sbin
cat > /usr/local/sbin/scanservjs-cleanup <<'EOF'
#!/bin/sh
set -eu
if pgrep -x scanimage >/dev/null || pgrep -x convert >/dev/null; then exit 0; fi
for directory in output thumbnail; do
    find "/var/lib/scanservjs/$directory" -maxdepth 1 -type f -mmin +1440 -delete
done
for directory in temp preview; do
    find "/var/lib/scanservjs/$directory" -maxdepth 1 -type f ! -name default.jpg -mmin +60 -delete
done
EOF
chmod 755 /usr/local/sbin/scanservjs-cleanup
cat > /etc/systemd/system/scanservjs-cleanup.service <<'EOF'
[Unit]
Description=Remove expired scans and temporary images
[Service]
Type=oneshot
User=scanservjs
Group=users
ExecStart=/usr/local/sbin/scanservjs-cleanup
EOF
cat > /etc/systemd/system/scanservjs-cleanup.timer <<'EOF'
[Unit]
Description=Hourly scan cleanup
[Timer]
OnBootSec=10min
OnUnitActiveSec=1h
[Install]
WantedBy=timers.target
EOF
systemctl mask --now colord.service packagekit.service
account=${SUDO_USER:-stampa}
account_home=$(getent passwd "$account" | cut -d: -f6)
test -n "$account_home"
install -d "$account_home/.config/systemd/user"
for unit in pipewire.service pipewire.socket pipewire-pulse.service pipewire-pulse.socket wireplumber.service; do
    ln -sf /dev/null "$account_home/.config/systemd/user/$unit"
done
chown "$account:" "$account_home/.config/systemd/user"
systemctl daemon-reload
systemctl enable scanservjs-cleanup.timer
echo "Configurazione salvata. Riavvia per applicare zram, tmpfs e avvio senza desktop. Poi verifica i servizi e riattiva la protezione SD."

