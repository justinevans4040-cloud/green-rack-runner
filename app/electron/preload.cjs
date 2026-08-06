const { contextBridge } = require('electron');

contextBridge.exposeInMainWorld('rackRunnerDesktop', Object.freeze({
  platform: process.platform,
  version: '1.0.0',
  installed: true
}));
