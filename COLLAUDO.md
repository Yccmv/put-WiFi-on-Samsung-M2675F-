# Prove effettuate sul Raspberry Pi Zero 2 W

Aggiornamento del 15 novembre 2026. Riscontri ottenuti sull’esemplare Samsung M2675F descritto nella guida.

| Funzione | Esito |
|---|---|
| Acquisizione USB dal vetro | Riuscita con scanimage e utente del servizio |
| Anteprima web | JPEG verificato, 864 × 1189 |
| Scansione web grigio 100 dpi | JPEG verificato, 832 × 1189 |
| Scansione web colore 150 dpi | JPEG RGB verificato, 1275 × 1784 |
| Scansione web colore 600 dpi | JPEG RGB scaricato e verificato, 5102 × 7136, 4389689 byte |
| Pagina CUPS | Accessibile, coda USB configurata |
| Prima pagina fisica tramite Pi | Da confermare dopo il ripristino del toner |
| Livello toner | Assente nelle risposte IPP osservate, cartuccia rimossa senza segnalazione utile |
| Pannello RAM, temperatura e documenti | Visibile nel browser, endpoint verificato anche dopo riavvio |
| Download automatico e cancellazione server | Codice installato; sequenza trasferimento/download/delete verificata in simulazione. Collaudo finale del download su Safari e altri browser ancora necessario |
| Protezione SD e avvio automatico | Base e boot in sola lettura, servizi attivi dopo riavvio |
| Memoria compressa | Zram 384 MiB, nessun dispositivo di appoggio su SD, verificato dopo riavvio |
| Pulizia automatica | Timer attivo, prova con file scaduto e recente riuscita |
| Standby prolungato e ripresa | Ancora da collaudare |

La prima prova colore a 600 dpi ha esaurito la RAM durante la conversione. Dopo i limiti ImageMagick, tmpfs da 320 MiB e zram, la prova completa è riuscita. La memoria disponibile a riposo misurata dopo l’alleggerimento era circa 274 MiB.

I precedenti timeout USB richiedevano un riavvio completo della Samsung. La loro causa esatta resta aperta. Un singolo errore di lettura microSD è apparso durante la diagnostica; nessun errore analogo è apparso nel successivo avvio controllato.

