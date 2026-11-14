#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
if [[ $(findmnt -n -o FSTYPE /) == overlay ]]; then
    echo "Salvataggio della sola impostazione WebInterface sulla microSD..."
    overlayroot-chroot sh -eu -c '
        conf=/etc/cups/cupsd.conf
        tmp=$(mktemp /etc/cups/.web-interface.XXXXXX)
        trap '\''rm -f "$tmp"'\'' EXIT
        cp -p "$conf" "$tmp"
        awk '\''tolower($1) != "webinterface" {print} END {print "WebInterface Yes"}'\'' "$conf" > "$tmp"
        cupsd -t -c "$tmp"
        mv -f "$tmp" "$conf"
        sync
    '
    case ",$(findmnt -n -o OPTIONS /media/root-ro)," in
        *,ro,*) ;;
        *) echo "Verifica richiesta: il filesystem di base non risulta in sola lettura." >&2; exit 1 ;;
    esac
fi
cupsctl WebInterface=yes
for attempt in {1..15}; do
    if page=$(curl -fsS -H 'Accept-Language: en' http://localhost:631/printers/Samsung-M2675F) &&
       grep -qi 'Samsung-M2675F' <<< "$page" && ! grep -qi 'Web Interface is Disabled' <<< "$page"; then
        echo "Verificata la pagina Samsung: http://stampante-pi.local:631/printers/Samsung-M2675F"
        exit 0
    fi
    sleep 1
done
echo "La pagina della coda non e' stata verificata." >&2
exit 1
