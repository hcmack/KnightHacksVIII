import http from 'http';
import url from 'url';

const PORT = 29706;
const AUTH_TOKEN = process.env.AUTH_TOKEN || 'secret123';

// In-memory storage for the string
let storedString = '';

const server = http.createServer((req, res) => {
  const parsedUrl = url.parse(req.url || '', true);
  const pathname = parsedUrl.pathname;
  const token = parsedUrl.query.token;

  // Set CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  // Handle preflight
  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  // Check authorization
  if (token !== AUTH_TOKEN) {
    res.writeHead(401, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Unauthorized' }));
    return;
  }

  // POST /upload?token=xxx - Upload a string
  if (req.method === 'POST' && pathname === '/upload') {
    let body = '';

    req.on('data', chunk => {
      body += chunk.toString();
    });

    req.on('end', () => {
      storedString = body;
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        success: true,
        message: 'String stored successfully',
        length: storedString.length
      }));
    });
    return;
  }

  // GET /get?token=xxx - Retrieve the string
  if (req.method === 'GET' && pathname === '/get') {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end(storedString);
    return;
  }

  // 404 for unknown routes
  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Not found' }));
});

server.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
  console.log(`Auth token: ${AUTH_TOKEN}`);
  console.log(`\nUsage:`);
  console.log(`  Upload: curl -X POST "http://localhost:${PORT}/upload?token=${AUTH_TOKEN}" -d "your string here"`);
  console.log(`  Get:    curl "http://localhost:${PORT}/get?token=${AUTH_TOKEN}"`);
});
