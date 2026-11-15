# Guida completa alla Samsung M2675F con Raspberry Pi Zero 2 W

Procedura ricostruita dalle prove effettuate nel novembre 2026. Lo scanner dal vetro è stato collaudato fino a 600 dpi a colori. La coda di stampa riceve PDF, ma il foglio fisico dopo la sostituzione del toner resta da verificare. Il [registro dei collaudi](COLLAUDO.md) riporta i singoli esiti. L’installatore completo raccoglie i passaggi applicati sul banco; una nuova installazione da zero con questo unico lanciatore resta da collaudare.

## Cosa serve e cosa fa il Pi

- Samsung Xpress M2675F USB, Pi Zero 2 W, microSD e lettore per Windows.
- Cavo dati USB-A/B e adattatore OTG host per la porta micro-USB del Pi marcata USB.
- Wi-Fi domestico a 2,4 GHz e accesso Internet per scaricare i pacchetti.
- Alimentazione adatta al Pi oppure derivazione interna realizzata e verificata da una persona qualificata.

Il Pi esegue CUPS per la stampa IPP, scanservjs per acquisire dal browser e Avahi per il nome stampante-pi.local. Tutti i client devono poter comunicare sulla stessa LAN. Alcune reti ospiti isolano i dispositivi. Scanner e coda web sono accessibili rispettivamente sulle porte 8080 e 631. La pagina scanner può acquisire documenti dal dispositivo fisico, quindi limitarla alla rete di fiducia.

## 1. Collegamento hardware

Leggere la [sezione hardware con foto](README.md#1-alimentazione-e-cablaggio) prima di intervenire. Sull’alimentatore KINGBIRD-V2-SEC osservato, CON3 è marcato +5 V/1,6 A e +24 V/2 A. La corrente è condivisa con la stampante. Un diverso alimentatore o revisione richiede una nuova verifica dei contatti.

Con alimentazione staccata, la derivazione verificata del +5 V va al **pin fisico 2** del Pi e la massa verificata al **pin fisico 6**. L’alimentazione da pin richiede polarità e tensione corretta prima del collegamento. Nel montaggio GPIO lasciare libera PWR IN. In alternativa si può usare un cavo micro-USB di alimentazione verificato sulla porta PWR IN. I colori dei fili richiedono conferma con la piedinatura del cavo.

Il cavo dati va dalla USB-B della Samsung alla porta USB del Pi mediante adattatore OTG host. Il Pi è esterno, in contenitore isolante con cavi fissati. Le foto del progetto indicano zone e scritte osservate. La numerazione completa dei contatti CON3 resta da verificare sul singolo esemplare. La scheda di alimentazione contiene tensione di rete e condensatori potenzialmente carichi; misure in funzione richiedono accessi isolati al secondario con protezioni rimontate.

## 2. Scrivere Raspberry Pi OS da Windows

1. Scaricare [Raspberry Pi Imager](https://www.raspberrypi.com/software/) dal sito ufficiale e avviarlo.
2. Inserire la microSD nel PC. Se contiene dati utili, salvarli prima. La scrittura li cancella.
3. Selezionare **Raspberry Pi Zero 2 W** come dispositivo.
4. Scegliere **Raspberry Pi OS Lite (32-bit)**, eventualmente sotto Raspberry Pi OS (other). La versione Lite evita il costo in memoria del desktop. Le ottimizzazioni di questa guida usano Raspberry Pi OS basato su Debian Trixie con rpi-swap.
5. Selezionare la microSD controllando la capacità.
6. Aprire la personalizzazione e impostare hostname **stampante-pi**, utente **stampa** e una password personale. Configurare nome e password del Wi-Fi a 2,4 GHz, paese IT e fuso Europe/Rome se usato in Italia. Abilitare SSH con autenticazione tramite password.
7. Scrivere, attendere la verifica ed espellere la scheda da Windows.

I nomi stampante-pi e stampa sono esempi usati anche dai lanciatori CMD. Per cambiarli occorre modificare i comandi SSH e SCP corrispondenti. [Guida ufficiale al primo avvio](https://www.raspberrypi.com/documentation/computers/getting-started.html)

### Se Imager ha saltato la personalizzazione

La procedura seguente vale per immagini recenti con cloud-init, **prima del primo avvio**. In Esplora file aprire bootfs, la piccola partizione FAT32. Se non appare, in Gestione disco fare clic destro su bootfs, quindi Cambia lettera e percorso di unità → Aggiungi. Lasciare intatta la partizione Linux. Annullare le richieste Windows di formattazione.

Devono esistere i file user-data, network-config e meta-data accanto a config.txt. Se mancano, verificare la versione dell’immagine e usare la personalizzazione Imager appropriata.

Aprire user-data con Blocco note, sostituire il contenuto seguente e salvare senza aggiungere estensioni. Cambiare la password di esempio prima del salvataggio.

```yaml
#cloud-config
hostname: stampante-pi
manage_etc_hosts: true
timezone: Europe/Rome
enable_ssh: true
ssh_pwauth: true
users:
  - name: stampa
    groups: [adm, sudo, plugdev, netdev]
    shell: /bin/bash
    lock_passwd: false
    plain_text_passwd: 'CAMBIA-QUESTA-PASSWORD'
```

Aprire network-config e sostituire il contenuto con questo esempio, inserendo i propri dati **solo sul PC locale**.

```yaml
network:
  version: 2
  renderer: NetworkManager
  wifis:
    wlan0:
      dhcp4: true
      regulatory-domain: IT
      access-points:
        'NOME-RETE':
          password: 'PASSWORD-RETE'
```

Conservare gli spazi iniziali, usare spazi invece di tabulazioni e mantenere i due blocchi in file separati. In YAML un apostrofo dentro una stringa tra apici singoli si rappresenta raddoppiandolo. Lasciare meta-data com’è. Questi file possono contenere credenziali leggibili, quindi conservarli privatamente. [Configurazione cloud-init di Raspberry Pi OS](https://www.raspberrypi.com/news/cloud-init-on-raspberry-pi-os/)

## 3. Primo avvio e accesso remoto

Inserire la scheda a Pi spento. Con cablaggio completo e protezioni rimontate accendere e aspettare alcuni minuti. Sul PC aprire PowerShell e digitare:

```powershell
ssh stampa@stampante-pi.local
```

Confermare la chiave del proprio Pi al primo collegamento. Inserire la password dell’utente stampa. I caratteri digitati della password sono invisibili. Quando il prompt diventa stampa@stampante-pi, si stanno eseguendo comandi Linux sul Pi.

Se il nome non viene trovato, attendere il completamento del primo avvio e verificare il Wi-Fi. In alternativa trovare l’IP del Pi nella pagina del router e usarlo al posto di stampante-pi.local. Lo stesso vale per gli indirizzi nel browser. Prenotare l’indirizzo tramite DHCP sul router permette di mantenerlo stabile.

Sul Pi verificare:

```bash
cat /etc/os-release
hostname
lsusb
free -h
```

La Samsung deve apparire con ID **04e8:3461**. Se manca, controllare che il cavo sia collegato alla porta USB dati del Pi tramite OTG. Per tornare a PowerShell Windows usare exit.

## 4. Scaricare e installare tutto il progetto

Su GitHub usare **Code → Download ZIP** ed estrarre lo ZIP sul PC. Tutti i file del progetto devono restare nella stessa cartella.

Aprire **Installa progetto completo.cmd**. Inserire la password di stampa alle richieste SSH/SCP e sudo. Il lanciatore copia i sei file necessari e avvia nell’ordine server, ottimizzazioni e pannello. Alla fine riavvia il Pi. Attendere alcuni minuti e aprire la pagina scanner. Se un passaggio fallisce, leggere l’errore nella finestra prima di chiuderla.

Per chi preferisce eseguire i passaggi manualmente, dalla PowerShell aperta nella cartella del progetto:

```powershell
scp samsung-server.sh samsung-splix-2.0.2.drv ottimizza-pi.sh install-web-panel.py pi-status.js web-panel.js stampa@stampante-pi.local:./
ssh stampa@stampante-pi.local
```

Poi, nella sessione Linux:

```bash
sudo bash samsung-server.sh
sudo bash ottimizza-pi.sh
sudo python3 install-web-panel.py
sudo reboot
```

Eseguire i comandi uno per volta e controllarne l’esito. Questa installazione richiede la protezione overlay disabilitata. Il punto 9 spiega come abilitarla a configurazione conclusa e come fare manutenzione.

L’installazione scarica CUPS, filtri di stampa, SpliX, Avahi, SANE e scanservjs. È stato provato scanservjs 3.3.0. Lo script richiede il rilascio corrente, quindi versioni successive richiedono un nuovo collaudo. L’estrazione del pacchetto può richiedere parecchi minuti sullo Zero 2 W. Per controllare avanzamento senza interrompere il processo, aprire un’altra sessione SSH ed eseguire:

```bash
df -h /
free -h
ps -eo pid,stat,etime,time,comm | grep -E 'apt|dpkg|tar|xz|zstd'
tail -n 10 /var/log/dpkg.log
```

## 5. Perché era necessaria l’ottimizzazione della RAM

Sul nostro Pi era installato il desktop. Il kernel aveva registrato esaurimenti di memoria, e in un controllo restavano circa 26 MiB disponibili sui circa 424 MiB utilizzabili. Disabilitando l’avvio grafico e i servizi superflui si è arrivati a circa 274 MiB disponibili a riposo.

La scansione a 600 dpi a colori ha creato un TIFF temporaneo di circa 105 MiB. Il programma di conversione ImageMagick ha bisogno di ulteriore spazio per decodificarlo e generare JPEG e anteprima. La prima conversione è terminata con codice 137, con memoria esaurita. Dopo la configurazione descritta qui la scansione web completa è riuscita.

Il sorgente eseguibile completo è [ottimizza-pi.sh](ottimizza-pi.sh). Imposta:

| Componente | Impostazione e scopo |
|---|---|
| Avvio | multi-user.target per avviare il server senza desktop |
| Audio e desktop | Maschere PipeWire, Pulse, WirePlumber, colord e PackageKit, inutili per questo server dedicato |
| Swap | Zram da 384 MiB con Mechanism=zram, memoria compressa senza file di appoggio sulla SD |
| ImageMagick | 24 MiB per il pixel cache in memoria, mappatura disattivata, cache temporanea limitata a 256 MiB, un thread |
| Cartella temporanea | /tmp in tmpfs da 320 MiB per i file di lavoro della conversione |
| SANE | Solo backend xerox_mfp per il servizio, associato all’ID Samsung |
| Pulizia | Timer ogni ora, documenti scaduti dopo 24 ore e temporanei dopo un’ora |

Zram e tmpfs consumano la RAM fisica secondo l’uso. Le dimensioni indicate sono limiti logici, non quantità di memoria prenotate alla partenza. Zram aiuta se i dati si comprimono; un insieme di pagine molto complesso o più acquisizioni contemporanee può ancora esaurire le risorse. Questa configurazione è stata provata con una pagina per volta.

Per applicare soltanto l’ottimizzazione a un server già installato, con protezione SD disabilitata, dalla cartella del progetto sul Pi:

```bash
sudo bash ottimizza-pi.sh
sudo reboot
```

Il comando systemctl set-default nello script cambia il prossimo avvio. I servizi utente già in esecuzione terminano al riavvio. Lo script contiene tutti i file di configurazione e le unità di pulizia in blocchi heredoc leggibili. Per rivedere i parametri:

```bash
cat /etc/rpi/swap.conf.d/90-print-server.conf
cat /etc/systemd/system/scanservjs.service.d/imagemagick.conf
cat /etc/systemd/system/tmp.mount.d/print-server.conf
cat /usr/local/sbin/scanservjs-cleanup
```

## 6. Collaudo dopo il riavvio

Rientrare con SSH e controllare:

```bash
systemctl get-default
systemctl is-active cups avahi-daemon scanservjs
systemctl is-active scanservjs-cleanup.timer
free -h
swapon --show
cat /sys/block/zram0/backing_dev
df -h /tmp
lpstat -v Samsung-M2675F
sudo vcgencmd get_throttled
```

Risultati attesi: multi-user.target, servizi e timer attivi, /dev/zram0 da 384 MiB, backing_dev pari a none, /tmp da 320 MiB e coda associata a usb://Samsung/…. throttled=0x0 indica che il firmware non segnala limitazioni dall’ultimo avvio. Ripetere il controllo dopo un ciclo di stampa e scansione. Un valore diverso richiede di interpretare i bit e verificare alimentazione o temperatura.

Mettere il documento sul vetro, faccia da acquisire verso il basso. Aprire **http://stampante-pi.local:8080/** dal browser del client. Iniziare con Flatbed, grigio e 100 dpi. Poi provare colore a 150 dpi. Per il massimo esposto dal driver scegliere **600 dpi**. La conversione può durare molto più dell’acquisizione. Lasciare la scheda del browser aperta.

La prova a 600 dpi colore ha prodotto un JPEG RGB di **5102 × 7136 pixel e 4389689 byte**, scaricato e decodificato con successo. La geometria predefinita del backend può differire leggermente dall’A4 nominale.

## 7. Pannello e download automatico

Il pannello in basso legge ogni 15 secondi RAM disponibile, temperatura e dimensione totale dei documenti sul Pi. Le dimensioni includono i documenti finali, mentre i temporanei si controllano con df e du.

I sorgenti sono [pi-status.js](pi-status.js), [web-panel.js](web-panel.js) e [install-web-panel.py](install-web-panel.py). Il programma Python verifica i punti d’inserimento di scanservjs 3.x, copia il modulo API e il codice browser, quindi aggiorna pagina iniziale e registrazione degli endpoint. Per reinstallare soltanto il pannello in manutenzione:

```bash
sudo python3 install-web-panel.py
sudo systemctl restart scanservjs
```

Alla risposta di una nuova scansione, solo il browser che l’ha richiesta scarica il documento completo. Poi avvia il salvataggio sul dispositivo e invia DELETE al server per rimuovere il documento e la miniatura. Se il trasferimento fallisce, la copia rimane sul Pi. Il browser conserva la propria copia e offre **Salva di nuovo sul dispositivo**. Chiudere o ricaricare la pagina può perdere questa copia.

Safari può chiedere l’autorizzazione al download. Controllare sempre il documento in Download prima di chiudere la pagina. Il trasferimento completo al browser è verificabile dal codice; il salvataggio definitivo nel filesystem del telefono richiede il riscontro dell’utente. Il collaudo finale del download automatico sui diversi browser rimane aperto.

File e anteprima si trovano rispettivamente in /var/lib/scanservjs/output e /var/lib/scanservjs/preview. La cartella temp contiene i file intermedi. Questi percorsi stanno nell’overlay in RAM quando la protezione è attiva. La rimozione del JPEG finale libera il suo spazio; il picco della scansione a 600 dpi dipende soprattutto dal TIFF e dalle cache durante l’elaborazione.

Come pulizia di riserva, il timer controlla ogni ora i documenti più vecchi di 24 ore e i temporanei più vecchi di un’ora. Salta il controllo se trova processi scanimage o convert. Questa scelta è stata provata con un file scaduto e uno recente. I dati temporanei vanno comunque scaricati prima di spegnere.

## 8. Stampa e gestione degli errori

La coda è **Samsung-M2675F**. Aprire **http://stampante-pi.local:631/printers/Samsung-M2675F** per vederla. L’installatore abilita WebInterface=yes e condivisione CUPS. Se un’installazione precedente mostra la pagina disabilitata, usare Abilita pagina CUPS.cmd. Per client IPP l’indirizzo è **ipp://stampante-pi.local:631/printers/Samsung-M2675F**.

Su Windows il tentativo Add-Printer -IppURL ha restituito 0x80070bc4 sul PC usato. È disponibile il client PDF del progetto. Installare Python 3 con Tkinter e comando python disponibile, poi aprire Stampa PDF Samsung.cmd. Il selettore invia subito il PDF scelto. Iniziare con una sola pagina. Stato Samsung.cmd controlla il lavoro e gli stati esposti da CUPS.

Su Android e iPhone cercare la Samsung dal menu Stampa dell’app con il dispositivo nella stessa rete. AirPrint, servizio Android e stampa fisica devono essere verificati sui client.

Un PDF accettato dalla coda può restare fermo se manca il toner. Nelle nostre prove la cartuccia rimossa non produceva un motivo utile in IPP e mancava il livello consumabile. Rendering completed descrive l’elaborazione sul server. Controllare il display fisico in caso di attesa prolungata.

```bash
lpstat -o
lpstat -p Samsung-M2675F
```

Se si vuole annullare un lavoro, usare cancel seguito dal suo identificativo letto nell’elenco. Prima di spegnere attendere che le pagine siano uscite o annullare consapevolmente i lavori pendenti.

## 9. Proteggere la microSD

Concludere installazione e prove prima di attivare la protezione. Eseguire:

```bash
sudo raspi-config
```

Scegliere Performance Options → Overlay File System. Abilitare overlay e protezione della partizione di boot. Accettare il riavvio e lasciare alimentato il Pi durante la generazione degli initramfs.

Dopo essersi ricollegati:

```bash
findmnt -n -o FSTYPE /
findmnt -n -o OPTIONS /media/root-ro
findmnt -n -o OPTIONS /boot/firmware
swapon --show
cat /sys/block/zram0/backing_dev
```

Il sistema deve usare overlay, la base e boot devono mostrare ro, lo swap deve essere zram con backing_dev none. Le modifiche durante l’uso vanno in RAM e si perdono al riavvio. Le impostazioni preparate prima della protezione vengono ricaricate a ogni accensione.

Per aggiornare o cambiare in modo permanente il server, riaprire raspi-config, disabilitare overlay e protezione boot e riavviare. Applicare gli aggiornamenti desiderati, riapplicare il pannello se scanservjs ha sostituito i file, collaudare e riattivare la protezione. La scrittura temporanea nella base con overlayroot-chroot richiede verifica del rimontaggio ro; sul banco una volta il filesystem era occupato e il riavvio ordinato ha ripristinato la protezione. La procedura di manutenzione tramite raspi-config rende il flusso più semplice da riprodurre. [Documentazione ufficiale](https://www.raspberrypi.com/documentation/computers/configuration.html#enable-or-disable-overlay-file-system)

Per arrestare ordinatamente il Pi usare sudo poweroff e attendere prima di togliere alimentazione. L’overlay riduce scritture e rischio di corruzione durante spegnimenti improvvisi, mentre un’interruzione durante un aggiornamento permanente resta delicata. Nessuna certificazione o prova industriale è stata eseguita.

## 10. Diagnosi riproducibile

### Pagina irraggiungibile

Provare l’indirizzo del Pi letto nel router al posto del nome .local e controllare che telefono e Pi siano sulla stessa rete senza isolamento client. Da SSH:

```bash
systemctl is-active scanservjs avahi-daemon cups
curl -fsS http://localhost:8080/pi-status
free -h
df -h / /tmp
du -sh /var/lib/scanservjs/*
sudo journalctl -u scanservjs -n 30 --no-pager
```

Se HTTP via IP funziona e il nome fallisce, approfondire la risoluzione mDNS. Se lo stato memoria mostra risorse libere, attribuire il problema alla RAM richiede ulteriori riscontri.

### Scanner elencato ma acquisizione fallita

L’elenco può provenire da una cache. Leggere lsusb per l’indirizzo corrente, che può cambiare a ogni ricollegamento. Con bus 001 e dispositivo 002, una prova diagnostica è:

```bash
sudo systemctl stop scanservjs
sudo timeout 30 scanimage -d xerox_mfp:libusb:001:002 --source Flatbed --mode Gray --resolution 100 -x 210 -y 297 --format=png > /tmp/prova-scanner.png
file /tmp/prova-scanner.png
sudo systemctl start scanservjs
```

Questa prova acquisisce realmente una pagina. Se fallisce anche l’apertura, raccogliere un log mirato:

```bash
sudo env SANE_DEBUG_XEROX_MFP=4 SANE_DEBUG_SANEI_USB=4 scanimage -d xerox_mfp:libusb:001:002 -A
```

Il messaggio Invalid argument è generico. In alcune prove il log mostrava timeout sull’INQUIRY USB. Verificare il display della Samsung, la coda libera e l’assenza di acquisizioni concorrenti. Sul banco il ricollegamento USB e il riavvio del solo Pi non avevano risolto lo stato bloccato; un ciclo completo della Samsung, con Pi prima arrestato ordinatamente, ha permesso il recupero. Non è stato isolato un rimedio software universale. Il comportamento dopo standby prolungato resta da collaudare.

### Conversione terminata con 137 o server molto lento

```bash
sudo journalctl -k --no-pager | grep -Ei 'Out of memory|Killed process|I/O error'
free -h
swapon --show
zramctl
df -h / /tmp
ps -eo comm,rss --sort=-rss | head -12
```

Verificare l’assenza del desktop, la configurazione di ImageMagick e zram. Evitare nuove scansioni mentre quella precedente è ancora in elaborazione. Per più pagine ad alta risoluzione può essere necessario un Pi con più RAM o una diversa architettura di elaborazione. Un errore di lettura microSD merita una verifica separata della scheda e del sistema.

## 11. Backup, recupero e dati da condividere

Dopo le prove spegnere ordinatamente e creare una copia completa della microSD con uno strumento di imaging. Provare l’avvio con una scheda di ricambio. La copia contiene password, impostazioni della rete e chiavi SSH, quindi tenerla privata.

Questo repository contiene script e guida pubblica. Catture USB originali, scansioni di documenti, credenziali e fotografie complete con identificativi restano nella ricerca privata. Prima di pubblicare log di supporto, controllare che non contengano questi dati.

Per riattivare il desktop in una futura riconversione del Pi, entrare prima in manutenzione con protezione disabilitata e usare systemctl set-default graphical.target. Le maschere dei servizi audio e colord/PackageKit create da ottimizza-pi.sh richiedono unmask nelle rispettive sessioni per riabilitarli. Riavviare, verificare e scegliere nuovamente la modalità di protezione adatta all’uso.

