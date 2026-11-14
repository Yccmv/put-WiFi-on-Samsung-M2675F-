@echo off
setlocal
title Installazione server Samsung su stampante-pi
echo Copia del programma di installazione sul Raspberry...
scp "%~dp0samsung-server.sh" "%~dp0samsung-splix-2.0.2.drv" stampa@stampante-pi.local:./
if errorlevel 1 goto fine
ssh -t stampa@stampante-pi.local "sudo bash samsung-server.sh %~1"
:fine
echo.
pause
