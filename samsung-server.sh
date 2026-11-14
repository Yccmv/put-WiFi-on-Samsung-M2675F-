#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
trap 'echo "Installazione interrotta alla riga $LINENO. Leggi il messaggio qui sopra." >&2' ERR

configure_scanner() {
apt-get update
apt-get install -y cups cups-filters printer-driver-splix avahi-daemon sane-utils curl usbutils
if ! dpkg-query -W -f='${Status}' scanservjs 2>/dev/null | grep -qx 'install ok installed'; then
    installer=$(mktemp)
    trap 'rm -f "$installer"' EXIT
    curl -fsSL https://raw.githubusercontent.com/sbs20/scanservjs/master/bootstrap.sh -o "$installer"
    bash "$installer" -v latest
fi

# Give the web scanner access to this USB device, including after reconnects.
getent group scanner >/dev/null || groupadd --system scanner
usermod -aG scanner scanservjs
rule=/etc/udev/rules.d/99-samsung-m2675-scanner.rules
echo 'SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="04e8", ATTR{idProduct}=="3461", GROUP="scanner", MODE="0660"' > "$rule"
udevadm control --reload-rules
udevadm trigger --action=change --subsystem-match=usb --attr-match=idVendor=04e8 --attr-match=idProduct=3461
udevadm settle
systemctl enable --now avahi-daemon cups scanservjs
systemctl restart scanservjs
echo "Scanner rilevati dal servizio:"
runuser -u scanservjs -- scanimage -L
}

if [[ ${1:-} != --solo-stampa ]]; then
    configure_scanner
fi

echo "Configurazione della coda di stampa..."
systemctl enable --now avahi-daemon cups
export CUPS_SERVER=localhost:631
devices=$(lpinfo -v)
uri=$(awk 'tolower($2) ~ /^usb:\/\/samsung\/.*m267/ {print $2; exit}' <<< "$devices")
models=$(lpinfo -m)
model=$(awk 'tolower($0) ~ /m267/ && tolower($0) ~ /splix/ {print $1; exit}' <<< "$models")
if [[ -z "$model" && -n "$uri" ]]; then
    test -x /usr/lib/cups/filter/rastertoqpdl
    install -m 0644 "$(dirname "$0")/samsung-splix-2.0.2.drv" /usr/share/cups/drv/samsung-splix-2.0.2.drv
    models=$(lpinfo -m)
    model=$(awk '$1 == "drv:///samsung-splix-2.0.2.drv/m267x.ppd" {print $1; exit}' <<< "$models")
fi
if [[ -z "$uri" || -z "$model" ]]; then
    echo "Scanner installato. Coda di stampa in attesa: URI USB o driver SpliX M267x non trovato."
    echo "$devices"
    grep -i m267 <<< "$models" || true
    exit 2
fi
cupsctl --share-printers WebInterface=yes
for attempt in {1..15}; do
    if lpstat -r | grep -qx 'scheduler is running'; then break; fi
    sleep 1
done
lpadmin -p Samsung-M2675F -E -v "$uri" -m "$model" -D "Samsung M2675F" -o PageSize=A4 -o printer-is-shared=true
for attempt in {1..10}; do
    if lpstat -v Samsung-M2675F 2>/dev/null; then break; fi
    if [[ $attempt == 10 ]]; then
        echo "CUPS non conferma la coda. Stato e messaggi recenti:"
        lpstat -t || true
        journalctl -u cups -n 15 --no-pager || true
        tail -n 20 /var/log/cups/error_log || true
        exit 3
    fi
    sleep 1
done
echo "Scanner: http://stampante-pi.local:8080"
echo "Stampante: ipp://stampante-pi.local:631/printers/Samsung-M2675F"
