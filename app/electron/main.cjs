const { app, BrowserWindow, shell } = require('electron');
const path = require('path');
const http = require('http');
const fs = require('fs');

const gotLock = app.requestSingleInstanceLock();
if (!gotLock) app.quit();

let mainWindow;
let syncServer;
const syncPort = 8765;
const syncStore = path.join(app.getPath('userData'), 'green-rack-runner-sync-state.json');

function json(res, code, body) {
  res.writeHead(code, {
    'content-type': 'application/json',
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET,POST,OPTIONS',
    'access-control-allow-headers': 'content-type'
  });
  res.end(JSON.stringify(body));
}

function startSyncServer() {
  if (syncServer) return;
  const dist = path.join(__dirname, '..', 'dist');
  syncServer = http.createServer((req, res) => {
    if (req.method === 'OPTIONS') return json(res, 200, { ok: true });
    if (req.url === '/api/sync' && req.method === 'GET') {
      try {
        if (!fs.existsSync(syncStore)) return json(res, 200, { ok: true, hasState: false, updatedAt: 0 });
        return json(res, 200, Object.assign({ ok: true, hasState: true }, JSON.parse(fs.readFileSync(syncStore, 'utf8'))));
      } catch (e) {
        return json(res, 500, { ok: false, error: e.message });
      }
    }
    if (req.url === '/api/sync' && req.method === 'POST') {
      let body = '';
      req.on('data', chunk => { body += chunk; if (body.length > 5_000_000) req.destroy(); });
      req.on('end', () => {
        try {
          const parsed = JSON.parse(body || '{}');
          fs.writeFileSync(syncStore, JSON.stringify(Object.assign({ updatedAt: Date.now() }, parsed), null, 2));
          json(res, 200, { ok: true });
        } catch (e) {
          json(res, 400, { ok: false, error: e.message });
        }
      });
      return;
    }
    const file = req.url === '/' ? 'index.html' : req.url.replace(/^\/+/, '');
    const target = path.normalize(path.join(dist, file));
    if (!target.startsWith(dist)) return json(res, 403, { ok: false });
    fs.readFile(target, (err, data) => {
      if (err) return json(res, 404, { ok: false });
      res.writeHead(200, { 'content-type': target.endsWith('.html') ? 'text/html' : 'application/octet-stream' });
      res.end(data);
    });
  });
  syncServer.listen(syncPort, '0.0.0.0');
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1440,
    height: 960,
    minWidth: 390,
    minHeight: 700,
    backgroundColor: '#050908',
    show: false,
    title: 'Rack Runner',
    autoHideMenuBar: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true
    }
  });

  mainWindow.loadURL(`http://127.0.0.1:${syncPort}/`);
  mainWindow.once('ready-to-show', () => mainWindow.show());
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    if (/^https?:\/\//i.test(url)) shell.openExternal(url);
    return { action: 'deny' };
  });
}

app.on('second-instance', () => {
  if (mainWindow) {
    if (mainWindow.isMinimized()) mainWindow.restore();
    mainWindow.focus();
  }
});

app.whenReady().then(() => {
  app.setAppUserModelId('com.justinevans.rackrunner');
  startSyncServer();
  createWindow();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
