const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const PORT = process.env.PORT || 3000;
const PUBLIC = path.join(__dirname, 'public');
const DATA_FILE = path.join(__dirname, 'data', 'board.json');
const COLUMNS = ['To Do', 'In Progress', 'Done'];
const LABELS = ['Bug', 'Feature', 'Chore'];
const ASSIGNEES = ['Alice', 'Bob', 'Carol', 'Dan'];
const ASSIGNEE_ERR = 'assignee must be one of: ' + ASSIGNEES.join(', ');
function parseDue(v) {
  if (v === undefined || v === null || v === '') return null;
  if (typeof v !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(v)) return undefined;
  const d = new Date(v + 'T00:00:00Z');
  return !isNaN(d) && d.toISOString().slice(0, 10) === v ? v : undefined;
}
const DUE_ERR = 'dueDate must be a valid date in YYYY-MM-DD format';
const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
};

function load() {
  try {
    const v = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
    return Array.isArray(v) ? v : [];
  } catch {
    return [];
  }
}

function save(cards) {
  fs.mkdirSync(path.dirname(DATA_FILE), { recursive: true });
  const tmp = DATA_FILE + '.tmp';
  fs.writeFileSync(tmp, JSON.stringify(cards, null, 2));
  fs.renameSync(tmp, DATA_FILE);
}

function send(res, status, body) {
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(body));
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', (c) => {
      data += c;
      if (data.length > 1e6) {
        reject(new Error('too large'));
        req.destroy();
      }
    });
    req.on('end', () => resolve(data));
    req.on('error', reject);
  });
}

const WIP_COLUMN = 'In Progress';
const WIP_LIMIT = 3;
const WIP_ERR = `${WIP_COLUMN} can hold at most ${WIP_LIMIT} cards`;

async function handleApi(req, res) {
  if (req.method === 'GET') return send(res, 200, load());
  if (req.method === 'POST') {
    let body;
    try {
      body = JSON.parse(await readBody(req));
    } catch {
      return send(res, 400, { error: 'Invalid JSON' });
    }
    const title = body && typeof body.title === 'string' ? body.title.trim() : '';
    if (!title) return send(res, 400, { error: 'title is required' });
    const column = body.column === undefined || body.column === null ? 'To Do' : body.column;
    if (!COLUMNS.includes(column)) {
      return send(res, 400, { error: 'column must be one of: ' + COLUMNS.join(', ') });
    }
    const label = body.label === undefined || body.label === null || body.label === '' ? null : body.label;
    if (label !== null && !LABELS.includes(label)) {
      return send(res, 400, { error: 'label must be one of: ' + LABELS.join(', ') });
    }
    const dueDate = parseDue(body.dueDate);
    if (dueDate === undefined) return send(res, 400, { error: DUE_ERR });
    const assignee = body.assignee === undefined || body.assignee === null || body.assignee === '' ? null : body.assignee;
    if (assignee !== null && !ASSIGNEES.includes(assignee)) return send(res, 400, { error: ASSIGNEE_ERR });
    const card = { id: crypto.randomUUID(), title, column, label, dueDate, assignee };
    const cards = load();
    if (column === WIP_COLUMN && cards.filter((c) => c.column === WIP_COLUMN).length >= WIP_LIMIT) {
      return send(res, 409, { error: WIP_ERR });
    }
    cards.push(card);
    save(cards);
    return send(res, 201, card);
  }
  send(res, 405, { error: 'Method not allowed' });
}

async function handleCard(req, res, id) {
  const cards = load();
  const idx = cards.findIndex((c) => c.id === id);
  if (idx === -1) return send(res, 404, { error: 'Card not found' });
  if (req.method === 'DELETE') {
    const [removed] = cards.splice(idx, 1);
    save(cards);
    return send(res, 200, removed);
  }
  if (req.method === 'PATCH') {
    let body;
    try {
      body = JSON.parse(await readBody(req));
    } catch {
      return send(res, 400, { error: 'Invalid JSON' });
    }
    if (!body || typeof body !== 'object') return send(res, 400, { error: 'Invalid JSON' });
    const hasColumn = body.column !== undefined;
    const hasLabel = body.label !== undefined;
    const hasDue = body.dueDate !== undefined;
    const hasAssignee = body.assignee !== undefined;
    if (!hasColumn && !hasLabel && !hasDue && !hasAssignee) return send(res, 400, { error: 'column, label, dueDate or assignee is required' });
    const assignee = body.assignee === '' ? null : body.assignee;
    if (hasAssignee && assignee !== null && !ASSIGNEES.includes(assignee)) return send(res, 400, { error: ASSIGNEE_ERR });
    const dueDate = parseDue(body.dueDate);
    if (hasDue && dueDate === undefined) return send(res, 400, { error: DUE_ERR });
    if (hasColumn && !COLUMNS.includes(body.column)) {
      return send(res, 400, { error: 'column must be one of: ' + COLUMNS.join(', ') });
    }
    const label = body.label === '' ? null : body.label;
    if (hasLabel && label !== null && !LABELS.includes(label)) {
      return send(res, 400, { error: 'label must be one of: ' + LABELS.join(', ') });
    }
    if (hasColumn && body.column === WIP_COLUMN && cards[idx].column !== WIP_COLUMN &&
        cards.filter((c) => c.column === WIP_COLUMN).length >= WIP_LIMIT) {
      return send(res, 409, { error: WIP_ERR });
    }
    if (hasColumn) cards[idx].column = body.column;
    if (hasLabel) cards[idx].label = label;
    if (hasDue) cards[idx].dueDate = dueDate;
    if (hasAssignee) cards[idx].assignee = assignee;
    save(cards);
    return send(res, 200, cards[idx]);
  }
  send(res, 405, { error: 'Method not allowed' });
}

function serveStatic(req, res) {
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    res.writeHead(405);
    return res.end();
  }
  let pathname;
  try {
    pathname = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  } catch {
    res.writeHead(400);
    return res.end();
  }
  if (pathname === '/') pathname = '/index.html';
  const file = path.normalize(path.join(PUBLIC, pathname));
  if (file !== PUBLIC && !file.startsWith(PUBLIC + path.sep)) {
    res.writeHead(403);
    return res.end('Forbidden');
  }
  fs.readFile(file, (err, buf) => {
    if (err) {
      res.writeHead(404);
      return res.end('Not found');
    }
    res.writeHead(200, { 'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream' });
    res.end(buf);
  });
}

http
  .createServer((req, res) => {
    const pathname = new URL(req.url, 'http://x').pathname;
    if (pathname === '/api/cards') return handleApi(req, res).catch(() => send(res, 500, { error: 'Server error' }));
    const m = pathname.match(/^\/api\/cards\/([^/]+)$/);
    if (m) {
      let id;
      try {
        id = decodeURIComponent(m[1]);
      } catch {
        return send(res, 400, { error: 'Bad id' });
      }
      return handleCard(req, res, id).catch(() => send(res, 500, { error: 'Server error' }));
    }
    serveStatic(req, res);
  })
  .listen(PORT, () => console.log(`Task board running on http://localhost:${PORT}`));
