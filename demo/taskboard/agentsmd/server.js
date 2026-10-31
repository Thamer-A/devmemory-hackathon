const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const PORT = process.env.PORT || 3000;
const PUBLIC = path.join(__dirname, 'public');
const DATA_FILE = path.join(__dirname, 'data', 'board.json');
const COLUMNS = ['To Do', 'In Progress', 'Done'];
const WIP_LIMIT = 3;
const LABELS = ['Bug', 'Feature', 'Chore'];
const ASSIGNEES = ['Alice', 'Bob', 'Carol', 'Dan'];
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json' };

function load() {
  try { return JSON.parse(fs.readFileSync(DATA_FILE, 'utf8')); } catch { return []; }
}
function save(cards) {
  fs.mkdirSync(path.dirname(DATA_FILE), { recursive: true });
  fs.writeFileSync(DATA_FILE, JSON.stringify(cards, null, 2));
}
function validDate(s) {
  if (typeof s !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(s)) return false;
  const d = new Date(s + 'T00:00:00Z');
  return !isNaN(d) && d.toISOString().slice(0, 10) === s;
}
function send(res, status, obj) {
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(obj));
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
  if (url.pathname === '/api/cards') {
    if (req.method === 'GET') return send(res, 200, load());
    if (req.method === 'POST') {
      let body = '';
      req.on('data', c => { body += c; if (body.length > 1e6) req.destroy(); });
      req.on('end', () => {
        let data;
        try { data = JSON.parse(body || '{}'); } catch { return send(res, 400, { error: 'Invalid JSON' }); }
        const title = typeof data.title === 'string' ? data.title.trim() : '';
        if (!title) return send(res, 400, { error: 'title is required' });
        const column = data.column === undefined ? 'To Do' : data.column;
        if (!COLUMNS.includes(column)) return send(res, 400, { error: 'invalid column' });
        const label = data.label === undefined || data.label === null || data.label === '' ? null : data.label;
        if (label !== null && !LABELS.includes(label)) return send(res, 400, { error: 'invalid label' });
        const dueDate = data.dueDate === undefined || data.dueDate === null || data.dueDate === '' ? null : data.dueDate;
        if (dueDate !== null && !validDate(dueDate)) return send(res, 400, { error: 'invalid dueDate' });
        const assignee = data.assignee === undefined || data.assignee === null || data.assignee === '' ? null : data.assignee;
        if (assignee !== null && !ASSIGNEES.includes(assignee)) return send(res, 400, { error: 'invalid assignee' });
        const card = { id: crypto.randomUUID(), title, column, label, dueDate, assignee };
        const cards = load();
        if (column === 'In Progress' && cards.filter(c => c.column === column).length >= WIP_LIMIT) return send(res, 409, { error: 'In Progress is full (max 3 cards)' });
        cards.push(card);
        save(cards);
        send(res, 201, card);
      });
      return;
    }
    return send(res, 405, { error: 'Method not allowed' });
  }
  const m = url.pathname.match(/^\/api\/cards\/([^/]+)$/);
  if (m) {
    const id = decodeURIComponent(m[1]);
    if (req.method === 'DELETE') {
      const cards = load();
      const i = cards.findIndex(c => c.id === id);
      if (i < 0) return send(res, 404, { error: 'Card not found' });
      cards.splice(i, 1);
      save(cards);
      res.writeHead(204);
      return res.end();
    }
    if (req.method === 'PATCH') {
      let body = '';
      req.on('data', c => { body += c; if (body.length > 1e6) req.destroy(); });
      req.on('end', () => {
        let data;
        try { data = JSON.parse(body || '{}'); } catch { return send(res, 400, { error: 'Invalid JSON' }); }
        if (!data || !COLUMNS.includes(data.column)) return send(res, 400, { error: 'invalid column' });
        const cards = load();
        const card = cards.find(c => c.id === id);
        if (!card) return send(res, 404, { error: 'Card not found' });
        if (data.column === 'In Progress' && card.column !== 'In Progress' && cards.filter(c => c.column === 'In Progress').length >= WIP_LIMIT) return send(res, 409, { error: 'In Progress is full (max 3 cards)' });
        card.column = data.column;
        save(cards);
        send(res, 200, card);
      });
      return;
    }
    return send(res, 405, { error: 'Method not allowed' });
  }
  if (req.method !== 'GET') return send(res, 405, { error: 'Method not allowed' });
  const rel = url.pathname === '/' ? 'index.html' : decodeURIComponent(url.pathname);
  const file = path.join(PUBLIC, rel);
  if (!file.startsWith(PUBLIC + path.sep)) return send(res, 403, { error: 'Forbidden' });
  fs.readFile(file, (err, buf) => {
    if (err) return send(res, 404, { error: 'Not found' });
    res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream' });
    res.end(buf);
  });
});

server.listen(PORT, () => console.log(`Task board on http://localhost:${PORT}`));
