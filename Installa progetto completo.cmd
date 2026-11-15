@echo off
setlocal
title Server Samsung - installazione completa
echo Richiede Raspberry Pi OS con protezione SD disabilitata.
scp "%~dp0samsung-server.sh" "%~dp0samsung-splix-2.0.2.drv" "%~dp0ottimizza-pi.sh" "%~dp0install-web-panel.py" "%~dp0pi-status.js" "%~dp0web-panel.js" stampa@stampante-pi.local:./
if errorlevel 1 goto fine
ssh -t stampa@stampante-pi.local "sudo bash samsung-server.sh && sudo bash ottimizza-pi.sh && sudo python3 install-web-panel.py && sudo reboot"
:fine
echo.
echo Se il riavvio e' stato eseguito, attendi qualche minuto e apri la pagina scanner.
echo Controlla eventuali errori sopra prima di chiudere.
pause

