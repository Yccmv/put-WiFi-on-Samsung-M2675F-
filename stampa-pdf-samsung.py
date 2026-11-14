import getpass
import http.client
import struct
import socket
import sys
import time
import threading
from queue import Queue, Empty
from pathlib import Path
from tkinter import Tk, Label, Button, filedialog

HOST = "stampante-pi.local"
QUEUE = "/printers/Samsung-M2675F"
last_address = None


def attribute(tag, name, value):
    name = name.encode()
    value = value.encode()
    return struct.pack(">BH", tag, len(name)) + name + struct.pack(">H", len(value)) + value


def decode_attributes(body):
    attrs = {}
    offset = 8
    while offset < len(body):
        tag = body[offset]
        offset += 1
        if tag == 3:
            return attrs
        if tag < 16:
            continue
        fields = []
        for _ in range(2):
            length = struct.unpack_from(">H", body, offset)[0]
            offset += 2
            fields.append(body[offset:offset + length])
            offset += length
        name, raw = fields
        if name:
            key = name.decode()
        value = int.from_bytes(raw, "big") if tag in (0x21, 0x22, 0x23) else raw.decode(errors="replace")
        attrs.setdefault(key, []).append(value)
    raise ValueError("Risposta IPP incompleta.")


def request(operation, path=None, job_id=None):
    global last_address
    header = struct.pack(">BBHI", 1, 1, operation, 1) + b"\x01"
    for tag, name, value in [
        (0x47, "attributes-charset", "utf-8"),
        (0x48, "attributes-natural-language", "it"),
        (0x45, "printer-uri", f"ipp://{HOST}:631{QUEUE}"),
        (0x42, "requesting-user-name", getpass.getuser()),
    ]:
        header += attribute(tag, name, value)
    if job_id is not None:
        header += b"\x21\x00\x06job-id\x00\x04" + struct.pack(">I", job_id)
    if operation in (2, 4):
        header += attribute(0x42, "job-name", path.name if path else "Verifica PDF")
        header += attribute(0x49, "document-format", "application/pdf")
    header += b"\x03"
    connection = http.client.HTTPConnection(HOST, 631, timeout=90)
    try:
        try:
            connection.connect()
            peer = connection.sock.getpeername()
            last_address = peer[0] + (f"%{peer[3]}" if len(peer) == 4 and peer[3] and "%" not in peer[0] else "")
        except socket.gaierror:
            if not last_address:
                raise
            connection = http.client.HTTPConnection(last_address, 631, timeout=90)
            connection.connect()
        connection.putrequest("POST", QUEUE, skip_host=True)
        connection.putheader("Host", f"{HOST}:631")
        connection.putheader("Content-Type", "application/ipp")
        connection.putheader("Content-Length", str(len(header) + (path.stat().st_size if path else 0)))
        connection.endheaders(header)
        if path:
            with path.open("rb") as source:
                while chunk := source.read(65536):
                    connection.send(chunk)
        response = connection.getresponse()
        body = response.read()
        if response.status != 200 or len(body) < 8 or response.getheader("Content-Type", "").split(";")[0] != "application/ipp":
            raise ValueError(f"Risposta HTTP {response.status} inattesa.")
        status = int.from_bytes(body[2:4], "big")
        if status >= 0x100:
            raise ValueError(f"CUPS ha restituito il codice IPP 0x{status:04x}.")
        return decode_attributes(body)
    finally:
        connection.close()


JOB = {3: "in attesa", 4: "trattenuto", 5: "in elaborazione", 6: "sospeso", 7: "annullato", 8: "interrotto", 9: "completato secondo CUPS"}
PRINTER = {3: "in attesa", 4: "in elaborazione", 5: "ferma"}
ALERTS = {"toner-empty": "Toner esaurito", "toner-low": "Toner in esaurimento",
          "marker-supply-empty": "Consumabile esaurito", "marker-supply-missing": "Consumabile assente",
          "media-empty": "Carta esaurita", "media-jam": "Carta inceppata", "cover-open": "Coperchio aperto",
          "door-open": "Sportello aperto", "offline": "Stampante offline"}


def describe(result, job):
    state = result.get("printer-state", [0])[0]
    count = result.get("queued-job-count", ["?"])[0]
    lines = [f"Coda Samsung {PRINTER.get(state, 'in stato sconosciuto')} · lavori presenti: {count}"]
    reasons = result.get("printer-state-reasons", []) + (job or {}).get("job-state-reasons", [])
    for reason in dict.fromkeys(reasons):
        if reason in ("none", "job-printing", "job-completed-successfully"):
            continue
        base = reason.removesuffix("-error").removesuffix("-warning").removesuffix("-report")
        lines.append(ALERTS.get(base, reason))
    lines.extend(filter(None, result.get("printer-state-message", []) + (job or {}).get("job-state-message", [])))
    if "marker-levels" not in result:
        lines.append("Livello del toner non comunicato.")
    else:
        for name, level in zip(result.get("marker-names", []), result["marker-levels"]):
            level = int.from_bytes(level.to_bytes(4, "big"), "big", signed=True)
            lines.append(f"{name}: {str(level) + '%' if 0 <= level <= 100 else 'livello sconosciuto'}")
    return "\n".join(lines)


def window(status_only):
    root = Tk()
    root.withdraw()
    path = None
    if not status_only:
        filename = filedialog.askopenfilename(title="Scegli il PDF da stampare sulla Samsung", filetypes=[("PDF", "*.pdf")])
        if not filename:
            root.destroy()
            return
        path = Path(filename)
    root.title("Samsung M2675F · Stato di stampa")
    label = Label(root, text="Invio del PDF…" if path else "Lettura della coda…", justify="left", wraplength=510, padx=22, pady=22)
    label.pack()
    Button(root, text="Chiudi", command=root.destroy).pack(pady=(0, 12))
    root.deiconify()
    updates = Queue()

    def monitor():
        job_id = None
        if path:
            try:
                reply = request(2, path)
                job_id = reply["job-id"][0]
            except Exception as error:
                updates.put(f"Invio non confermato: {error}\nControlla la coda prima di ritentare.")
                return
        previous = None
        since = time.monotonic()
        while True:
            try:
                printer = request(11)
                job = request(9, job_id=job_id) if job_id else None
                text = describe(printer, job)
                state = job.get("job-state", [0])[0] if job else None
                if job:
                    text = f"Lavoro {job_id}: {JOB.get(state, 'stato sconosciuto')}.\n" + text
                if text != previous:
                    previous, since = text, time.monotonic()
                if state == 9:
                    text += "\nUscita del foglio non verificabile dal PC."
                elif (state in (3, 4, 5, 6) or printer.get("queued-job-count", [0])[0]) and time.monotonic() - since >= 60:
                    text += "\nNessun cambio di stato da almeno un minuto. Controlla il display, la cartuccia e la carta prima di reinviare il PDF."
                updates.put(text)
                if state in (7, 8, 9):
                    return
            except Exception as error:
                updates.put(f"Lettura dello stato non riuscita: {error}\nNuovo controllo automatico tra pochi secondi.")
            time.sleep(5)

    def refresh():
        try:
            while True:
                label.configure(text=updates.get_nowait())
        except Empty:
            root.after(250, refresh)

    threading.Thread(target=monitor, daemon=True).start()
    refresh()
    root.mainloop()


if __name__ == "__main__":
    if sys.argv[1:] == ["--verifica"]:
        request(4)
        print("CUPS accetta la verifica di un documento PDF.")
    else:
        window("--stato" in sys.argv)
