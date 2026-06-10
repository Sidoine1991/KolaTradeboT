const http = require('http');
const fs   = require('fs');
const path = require('path');

const ROOT = __dirname;
const PORT = 7860;
const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js':   'application/javascript',
  '.css':  'text/css',
  '.json': 'application/json',
  '.png':  'image/png',
  '.ico':  'image/x-icon'
};

const server = http.createServer((req, res) => {
  const url = req.url.split('?')[0];
  const fp  = path.join(ROOT, url === '/' ? 'deriv_ea_pro.html' : url);

  if (url === '/favicon.ico') {
    res.writeHead(204);
    res.end();
    return;
  }

  if (!fs.existsSync(fp) || !fs.statSync(fp).isFile()) {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('404 Not Found: ' + url);
    return;
  }

  res.writeHead(200, { 'Content-Type': MIME[path.extname(fp)] || 'text/plain' });
  fs.createReadStream(fp).pipe(res);
});

server.listen(PORT, '127.0.0.1', () => {
  console.log('');
  console.log('  Deriv EA Pro — serveur local');
  console.log('  ─────────────────────────────');
  console.log('  http://127.0.0.1:' + PORT);
  console.log('');
  console.log('  Ctrl+C pour arrêter');
});

server.on('error', (e) => {
  if (e.code === 'EADDRINUSE') {
    console.error('  Port ' + PORT + ' déjà utilisé.');
  } else {
    console.error('  Erreur serveur:', e.message);
  }
  process.exit(1);
});
