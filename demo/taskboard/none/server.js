const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const PORT = process.env.PORT || 3000;
const PUBLIC = path.join(__dirname, 'public');
const DATA_FILE = path.join(__dirname, 'data', 'board.json');
const COLUMNS = ['To Do', 'In Progress', 'Done'];
const WIP_LIMIT = 3;
const WIP_COLUMN = 'In Progress';
const LABELS = ['Bug', 'Feature', 'Chore'];
const ASSIGNEES = ['Alice', 'Bob', 'Carol', 'Dan'];
const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json',
  '.svg': 'image/svg+xml',
};

function validDate(v) {
  if (typeof v !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(v)) return false;
  const d = new Date(v + 'T00:00:00Z');
  return !isNaN(d) && d.toISOString().slice(0, 10) === v;
}

function load() {
  try {
    const d = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
    return Array.isArray(d) ? d : (Array.isArray(d.cards) ? d.cards : []);
  } catch (e) {
    return [];
  }
}

function save(cards) {
  fs.mkdirSync(path.dirname(DATA_FILE), { recursive: true });
  const tmp = DATA_FILE + '.tmp';
  fs.writeFileSync(tmp, JSON.stringify({ cards: cards }, null, 2));
  fs.renameSync(tmp, DATA_FILE);
}

function send(res, status, body) {
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(body));
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let s = '';
    req.on('data', (c) => {
      s += c;
      if (s.length > 1e6) {
        reject(new Error('too large'));
        req.destroy();
      }
    });
    req.on('end', () => resolve(s));
    req.on('error', reject);
  });
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');

  if (url.pathname === '/api/cards') {
    if (req.method === 'GET') return send(res, 200, load());
    if (req.method === 'POST') {
      let body;
      try {
        body = JSON.parse(await readBody(req));
      } catch (e) {
        return send(res, 400, { error: 'Invalid JSON' });
      }
      if (!body || typeof body !== 'object') return send(res, 400, { error: 'Invalid body' });
      const title = typeof body.title === 'string' ? body.title.trim() : '';
      if (!title) return send(res, 400, { error: 'title is required' });
      const column = body.column === undefined || body.column === null ? 'To Do' : body.column;
      if (!COLUMNS.includes(column)) {
        return send(res, 400, { error: 'column must be one of: ' + COLUMNS.join(', ') });
      }
      const label = body.label === undefined || body.label === null || body.label === '' ? null : body.label;
      if (label !== null && !LABELS.includes(label)) {
        return send(res, 400, { error: 'label must be one of: ' + LABELS.join(', ') });
      }
      const dueDate = body.dueDate === undefined || body.dueDate === null || body.dueDate === '' ? null : body.dueDate;
      if (dueDate !== null && !validDate(dueDate)) {
        return send(res, 400, { error: 'dueDate must be a valid date in YYYY-MM-DD format' });
      }
      const assignee = body.assignee === undefined || body.assignee === null || body.assignee === '' ? null : body.assignee;
      if (assignee !== null && !ASSIGNEES.includes(assignee)) {
        return send(res, 400, { error: 'assignee must be one of: ' + ASSIGNEES.join(', ') });
      }
      const cards = load();
      if (column === WIP_COLUMN && cards.filter((c) => c.column === WIP_COLUMN).length >= WIP_LIMIT) {
        return send(res, 409, { error: 'In Progress is limited to ' + WIP_LIMIT + ' cards' });
      }
      const card = { id: crypto.randomUUID(), title: title, column: column, label: label, dueDate: dueDate, assignee: assignee };
      cards.push(card);
      save(cards);
      return send(res, 201, card);
    }
    return send(res, 405, { error: 'Method not allowed' });
  }

  const m = url.pathname.match(/^\/api\/cards\/([^/]+)$/);
  if (m) {
    let id;
    try {
      id = decodeURIComponent(m[1]);
    } catch (e) {
      return send(res, 400, { error: 'Bad id' });
    }
    if (req.method === 'PATCH') {
      let body;
      try {
        body = JSON.parse(await readBody(req));
      } catch (e) {
        return send(res, 400, { error: 'Invalid JSON' });
      }
      if (!body || typeof body !== 'object') return send(res, 400, { error: 'Invalid body' });
      const hasColumn = body.column !== undefined;
      const hasLabel = body.label !== undefined;
      const hasDue = body.dueDate !== undefined;
      const hasAssignee = body.assignee !== undefined;
      if (!hasColumn && !hasLabel && !hasDue && !hasAssignee) {
        return send(res, 400, { error: 'column, label, dueDate or assignee is required' });
      }
      if (hasAssignee && body.assignee !== null && !ASSIGNEES.includes(body.assignee)) {
        return send(res, 400, { error: 'assignee must be one of: ' + ASSIGNEES.join(', ') });
      }
      if (hasDue && body.dueDate !== null && !validDate(body.dueDate)) {
        return send(res, 400, { error: 'dueDate must be a valid date in YYYY-MM-DD format' });
      }
      if (hasColumn && !COLUMNS.includes(body.column)) {
        return send(res, 400, { error: 'column must be one of: ' + COLUMNS.join(', ') });
      }
      if (hasLabel && body.label !== null && !LABELS.includes(body.label)) {
        return send(res, 400, { error: 'label must be one of: ' + LABELS.join(', ') });
      }
      const cards = load();
      const card = cards.find((c) => c.id === id);
      if (!card) return send(res, 404, { error: 'Card not found' });
      if (hasColumn && body.column === WIP_COLUMN && card.column !== WIP_COLUMN &&
          cards.filter((c) => c.column === WIP_COLUMN).length >= WIP_LIMIT) {
        return send(res, 409, { error: 'In Progress is limited to ' + WIP_LIMIT + ' cards' });
      }
      if (hasColumn) card.column = body.column;
      if (hasLabel) card.label = body.label;
      if (hasDue) card.dueDate = body.dueDate;
      if (hasAssignee) card.assignee = body.assignee;
      save(cards);
      return send(res, 200, card);
    }
    if (req.method === 'DELETE') {
      const cards = load();
      const idx = cards.findIndex((c) => c.id === id);
      if (idx === -1) return send(res, 404, { error: 'Card not found' });
      cards.splice(idx, 1);
      save(cards);
      res.writeHead(204);
      return res.end();
    }
    return send(res, 405, { error: 'Method not allowed' });
  }

  if (req.method !== 'GET' && req.method !== 'HEAD') {
    return send(res, 405, { error: 'Method not allowed' });
  }
  let rel;
  try {
    rel = decodeURIComponent(url.pathname);
  } catch (e) {
    return send(res, 400, { error: 'Bad path' });
  }
  if (rel.endsWith('/')) rel += 'index.html';
  const file = path.join(PUBLIC, rel);
  if (file !== PUBLIC && !file.startsWith(PUBLIC + path.sep)) {
    return send(res, 403, { error: 'Forbidden' });
  }
  fs.readFile(file, (err, buf) => {
    if (err) return send(res, 404, { error: 'Not found' });
    res.writeHead(200, { 'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream' });
    res.end(buf);
  });
});

server.listen(PORT, () => console.log('Task board running on http://localhost:' + PORT));
