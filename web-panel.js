/* Pi status and automatic download for scanservjs 3.x. */
(() => {
  const nativeFetch = window.fetch.bind(window);
  const panel = document.createElement('div');
  panel.style.cssText = 'position:fixed;bottom:8px;left:8px;right:8px;z-index:9999;background:#15232e;color:#fff;padding:9px 12px;border-radius:8px;font:12px system-ui;box-shadow:0 2px 10px #0005';
  const metrics = document.createElement('div');
  const feedback = document.createElement('div');
  feedback.textContent = 'Download automatico attivo · abilita i download quando il browser lo richiede';
  const retry = document.createElement('button');
  retry.textContent = 'Scarica il documento';
  retry.hidden = true;
  retry.style.cssText = 'margin-top:6px;padding:6px 12px';
  panel.append(metrics, feedback, retry);
  document.body.append(panel);
  document.body.style.paddingBottom = '90px';
  const mib = bytes => Math.round(bytes / 1048576);
  async function update() {
    try {
      const response = await nativeFetch('/pi-status', {cache: 'no-store'});
      if (!response.ok) throw new Error();
      const status = await response.json();
      metrics.textContent = 'RAM disponibile ' + mib(status.available) + '/' + mib(status.total) +
        ' MB · Scansioni ' + mib(status.scans) + ' MB · Temperatura ' +
        (status.temperature === null ? '—' : status.temperature.toFixed(0) + ' °C');
    } catch {
      metrics.textContent = 'Stato Pi temporaneamente non raggiungibile';
    }
  }
  async function download(file) {
    feedback.textContent = 'Scaricamento di ' + file.name + '…';
    try {
      const url = '/api/v1/files/' + encodeURIComponent(file.name);
      const response = await nativeFetch(url);
      if (!response.ok) throw new Error('Trasferimento non riuscito');
      const blob = await response.blob();
      const blobUrl = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = blobUrl;
      link.download = file.name;
      document.body.append(link);
      link.click();
      link.remove();
      retry.textContent = 'Salva di nuovo sul dispositivo';
      retry.hidden = false;
      retry.onclick = () => {
        const anotherLink = document.createElement('a');
        anotherLink.href = blobUrl;
        anotherLink.download = file.name;
        document.body.append(anotherLink);
        anotherLink.click();
        anotherLink.remove();
      };
      const deletion = await nativeFetch(url, {method: 'DELETE'});
      if (!deletion.ok) throw new Error('File ricevuto, pulizia sul Pi non riuscita');
      feedback.textContent = 'Documento trasferito al browser e rimosso dal Pi. Controlla Download sul dispositivo.';
      update();
    } catch (error) {
      feedback.textContent = error.message + '. Il documento resta sul Pi.';
      retry.hidden = false;
      retry.onclick = () => download(file);
    }
  }
  window.fetch = async function(input, init) {
    const response = await nativeFetch(input, init);
    const url = typeof input === 'string' ? input : input.url;
    const method = (init?.method || input?.method || 'GET').toUpperCase();
    if (new URL(url, location.href).pathname === '/api/v1/scan' && method === 'POST' && response.ok) {
      response.clone().json().then(result => {
        if (result.file?.name) {
          retry.hidden = false;
          retry.onclick = () => download(result.file);
          download(result.file);
        }
      }).catch(() => {});
    }
    return response;
  };
  update();
  setInterval(update, 15000);
})();

