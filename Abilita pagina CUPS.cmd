@echo off
setlocal
scp "%~dp0abilita-cups-web.sh" stampa@stampante-pi.local:./
if errorlevel 1 goto fine
ssh -t stampa@stampante-pi.local "sudo bash abilita-cups-web.sh"
:fine
pause
