const COLUMNS = ['To Do', 'In Progress', 'Done'];
const LABEL_COLORS = { Bug: '#e5484d', Feature: '#3e63dd', Chore: '#8b8d98' };
let allCards = [];
const ASSIGNEES = ['Alice', 'Bob', 'Carol', 'Dan'];
const AVATAR_COLORS = { Alice: '#d6409f', Bob: '#2f9e6b', Carol: '#c26a00', Dan: '#0090ff' };
let filter = null;
let assigneeFilter = null;
const board = document.getElementById('board');
const errorEl = document.getElementById('error');
const searchEl = document.getElementById('search');
searchEl.addEventListener('input', () => render(allCards));
document.getElementById('clear-filters').addEventListener('click', () => {
  searchEl.value = '';
  filter = null;
  assigneeFilter = null;
  render(allCards);
});

let toastTimer;
function showToast(msg) {
  let t = document.getElementById('toast');
  if (!t) {
    t = document.createElement('div');
    t.id = 'toast';
    t.setAttribute('role', 'status');
    document.body.append(t);
  }
  t.textContent = msg;
  t.classList.add('show');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => t.classList.remove('show'), 3500);
}

async function conflictMessage(res) {
  try { return (await res.json()).error; } catch (e) { return null; }
}

function renderFilters() {
  const bar = document.getElementById('filters');
  bar.replaceChildren(...[null, ...Object.keys(LABEL_COLORS)].map((l) => {
    const b = document.createElement('button');
    b.type = 'button';
    b.textContent = l || 'All';
    b.className = 'filter' + (l === filter ? ' active' : '');
    b.setAttribute('aria-pressed', String(l === filter));
    if (l) b.style.setProperty('--c', LABEL_COLORS[l]);
    b.addEventListener('click', () => { filter = l; render(allCards); });
    return b;
  }));
}

function initials(name) {
  return name.split(/\s+/).map((w) => w[0]).join('').slice(0, 2).toUpperCase();
}

function renderAssigneeFilters() {
  const bar = document.getElementById('assignee-filters');
  bar.replaceChildren(...[null, ...ASSIGNEES].map((a) => {
    const b = document.createElement('button');
    b.type = 'button';
    b.textContent = a || 'Anyone';
    b.className = 'filter' + (a === assigneeFilter ? ' active' : '');
    b.setAttribute('aria-pressed', String(a === assigneeFilter));
    if (a) b.style.setProperty('--c', AVATAR_COLORS[a]);
    b.addEventListener('click', () => { assigneeFilter = a; render(allCards); });
    return b;
  }));
}

function todayStr() {
  const n = new Date();
  const p = (x) => String(x).padStart(2, '0');
  return n.getFullYear() + '-' + p(n.getMonth() + 1) + '-' + p(n.getDate());
}

function render(cards) {
  allCards = cards;
  renderFilters();
  renderAssigneeFilters();
  if (filter) cards = cards.filter((c) => c.label === filter);
  if (assigneeFilter) cards = cards.filter((c) => c.assignee === assigneeFilter);
  const q = searchEl.value.trim().toLowerCase();
  if (q) cards = cards.filter((c) => String(c.title).toLowerCase().includes(q));
  board.replaceChildren(...COLUMNS.map((name) => {
    const col = document.createElement('section');
    col.className = 'column';
    const items = cards.filter((c) => c.column === name);
    const h = document.createElement('h2');
    const title = document.createElement('span');
    title.textContent = name;
    const badge = document.createElement('span');
    badge.className = 'badge';
    badge.textContent = items.length;
    badge.setAttribute('aria-label', items.length + ' cards');
    h.append(title, badge);
    col.append(h);
    items.forEach((c) => {
      const d = document.createElement('div');
      d.className = 'card';
      d.draggable = true;
      if (c.dueDate) {
        const today = todayStr();
        if (c.dueDate < today) d.classList.add('overdue');
        else if (c.dueDate === today) d.classList.add('due-today');
      }
      const t = document.createElement('span');
      t.textContent = c.title;
      const del = document.createElement('button');
      del.type = 'button';
      del.className = 'delete';
      del.textContent = '×';
      del.title = 'Delete card';
      del.setAttribute('aria-label', 'Delete card ' + c.title);
      del.addEventListener('click', async () => {
        errorEl.textContent = '';
        const res = await fetch('/api/cards/' + encodeURIComponent(c.id), { method: 'DELETE' });
        if (!res.ok && res.status !== 404) errorEl.textContent = 'Failed to delete card';
        refresh();
      });
      d.addEventListener('dragstart', (e) => {
        e.dataTransfer.setData('text/plain', c.id);
        e.dataTransfer.effectAllowed = 'move';
        d.classList.add('dragging');
      });
      d.addEventListener('dragend', () => d.classList.remove('dragging'));
      const main = document.createElement('div');
      main.className = 'card-main';
      main.append(t);
      if (LABEL_COLORS[c.label]) {
        const pill = document.createElement('span');
        pill.className = 'pill';
        pill.textContent = c.label;
        pill.style.background = LABEL_COLORS[c.label];
        main.append(pill);
      }
      if (c.dueDate) {
        const due = document.createElement('span');
        due.className = 'due';
        due.textContent = 'Due ' + c.dueDate;
        main.append(due);
      }
      const side = document.createElement('div');
      side.className = 'card-side';
      if (AVATAR_COLORS[c.assignee]) {
        const av = document.createElement('span');
        av.className = 'avatar';
        av.textContent = initials(c.assignee);
        av.style.background = AVATAR_COLORS[c.assignee];
        av.title = c.assignee;
        av.setAttribute('aria-label', 'Assigned to ' + c.assignee);
        side.append(av);
      }
      side.append(del);
      d.append(main, side);
      col.append(d);
    });
    col.addEventListener('dragover', (e) => {
      e.preventDefault();
      e.dataTransfer.dropEffect = 'move';
      col.classList.add('over');
    });
    col.addEventListener('dragleave', (e) => {
      if (!col.contains(e.relatedTarget)) col.classList.remove('over');
    });
    col.addEventListener('drop', async (e) => {
      e.preventDefault();
      col.classList.remove('over');
      const id = e.dataTransfer.getData('text/plain');
      if (!id) return;
      errorEl.textContent = '';
      const res = await fetch('/api/cards/' + encodeURIComponent(id), {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ column: name }),
      });
      if (res.status === 409) showToast((await conflictMessage(res)) || 'In Progress is limited to 3 cards');
      else if (!res.ok && res.status !== 404) errorEl.textContent = 'Failed to move card';
      refresh();
    });
    return col;
  }));
}

async function refresh() {
  const res = await fetch('/api/cards');
  render(await res.json());
}

document.getElementById('add-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  errorEl.textContent = '';
  const titleEl = document.getElementById('title');
  const res = await fetch('/api/cards', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ title: titleEl.value, column: document.getElementById('column').value, label: document.getElementById('label').value || null, assignee: document.getElementById('assignee').value || null, dueDate: document.getElementById('dueDate').value || null }),
  });
  if (res.status === 409) {
    showToast((await conflictMessage(res)) || 'In Progress is limited to 3 cards');
    return;
  }
  if (!res.ok) {
    errorEl.textContent = (await res.json()).error || 'Failed to add card';
    return;
  }
  titleEl.value = '';
  document.getElementById('dueDate').value = '';
  refresh();
});

refresh().catch(() => { errorEl.textContent = 'Failed to load cards'; });
