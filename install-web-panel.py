from pathlib import Path
import shutil

root = Path("/usr/lib/scanservjs")
source = Path(__file__).resolve().parent
server = root / "server/express-configurer.js"
index = root / "client/index.html"
text = server.read_text()
old = "  endpoints() {"
new = "  endpoints() {\n    require('./pi-status')(this.app);"
if "require('./pi-status')" not in text:
    if text.count(old) != 1:
        raise RuntimeError("Versione scanservjs non riconosciuta")
    text = text.replace(old, new)
html = index.read_text()
script = '<script src="/pi-panel.js"></script>'
if script not in html:
    if "</body>" not in html:
        raise RuntimeError("Pagina iniziale non riconosciuta")
    html = html.replace("</body>", script + "\n</body>")
shutil.copyfile(source / "pi-status.js", root / "server/pi-status.js")
shutil.copyfile(source / "web-panel.js", root / "client/pi-panel.js")
server.write_text(text)
index.write_text(html)
print("Pannello installato")

