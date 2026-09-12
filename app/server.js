const http = require('node:http');

const escapeHtml = (value) => String(value).replace(/[&<>"']/g, char => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
}[char]));

const server = http.createServer((req, res) => {
  res.setHeader('Cache-Control', 'no-store');
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ status: 'ok' }));
  }
  if (req.url !== '/') {
    res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    return res.end('Page not found');
  }
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(`<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Lab04 — App Service</title>
<style>body{font:18px/1.6 system-ui,sans-serif;background:#f0f5fa;color:#17324d;margin:0;padding:8vw}main{max-width:720px;background:white;padding:40px;border-radius:16px;border-top:6px solid #0078d4}h1{line-height:1.2}code{background:#eaf2fa;padding:4px 8px;border-radius:4px}</style></head>
<body><main><p>AZ-104 · Hilaire</p><h1>Lab04 — App Service</h1>
<p>My Node.js application is running on Azure App Service.</p>
<p>Environment: <code>${escapeHtml(process.env.APP_ENV || 'local')}</code></p>
<p>Infrastructure deployed with Bicep · Application published from a ZIP archive.</p>
</main></body></html>`);
});

if (require.main === module) {
  server.listen(process.env.PORT || 8080, '0.0.0.0');
}
module.exports = server;

