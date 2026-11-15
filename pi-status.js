const fs = require('fs').promises;
const path = require('path');

module.exports = function(app) {
  app.get('/pi-status', async (req, res) => {
    try {
      const meminfo = await fs.readFile('/proc/meminfo', 'utf8');
      const value = name => Number(meminfo.match(new RegExp('^' + name + ':\\s+(\\d+)', 'm'))[1]) * 1024;
      const directory = '/var/lib/scanservjs/output';
      let scans = 0;
      for (const entry of await fs.readdir(directory, {withFileTypes: true})) {
        if (entry.isFile()) {
          const stat = await fs.stat(path.join(directory, entry.name)).catch(() => null);
          if (stat) scans += stat.size;
        }
      }
      const thermal = await fs.readFile('/sys/class/thermal/thermal_zone0/temp', 'utf8').catch(() => null);
      res.set('Cache-Control', 'no-store');
      res.json({available: value('MemAvailable'), total: value('MemTotal'), scans,
        temperature: thermal === null ? null : Number(thermal) / 1000});
    } catch {
      res.status(503).json({message: 'Stato non disponibile'});
    }
  });
};

