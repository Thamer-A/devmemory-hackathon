const COLUMNS = ['To Do', 'In Progress', 'Done'];
const board = document.getElementById('board');
const errorEl = document.getElementById('error');

const LABEL_COLORS = { Bug: '#e5484d', Feature: '#3e63dd', Chore: '#8b8d98' };
const filterBar = document.getElementById('filter-bar');
const ASSIGNEES = ['Alice', 'Bob', 'Carol', 'Dan'];
const assigneeBar = document.getElementById('assignee-filter-bar');
let activeFilter = '';
let activeAssignee = '';
let searchTerm = '';
let allCards = [];
const searchInput = document.getElementById('search');
searchInput.addEventListener('input', () => {
  searchTerm = searchInput.value.trim().toLowerCase();
  render(allCards);
});
document.getElementById('clear-filters').addEventListener('click', () => {
  searchInput.value = '';
  searchTerm = '';
  activeFilter = '';
  activeAssignee = '';
  renderFilter();
  render(allCards);
});

function initials(name) {
  return name.split(/\s+/).map((w) => w[0]).join('').slice(0, 2).toUpperCase();
}

function renderFilter() {
  filterBar.textContent = '';
  for (const name of ['', ...Object.keys(LABEL_COLORS)]) {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = 'filter' + (name === activeFilter ? ' active' : '');
    b.textContent = name || 'All';
    if (name) b.style.setProperty('--c', LABEL_COLORS[name]);
    b.addEventListener('click', () => {
      activeFilter = name;
      renderFilter();
      render(allCards);
    });
    filterBar.appendChild(b);
  }
  assigneeBar.textContent = '';
  for (const name of ['', ...ASSIGNEES]) {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = 'filter' + (name === activeAssignee ? ' active' : '');
    b.textContent = name || 'Everyone';
    b.addEventListener('click', () => {
      activeAssignee = name;
      renderFilter();
      render(allCards);
    });
    assigneeBar.appendChild(b);
  }
}

function todayStr() {
  const d = new Date();
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

function render(cards) {
  allCards = cards;
  board.textContent = '';
  for (const name of COLUMNS) {
    const col = document.createElement('section');
    col.className = 'column';
    const h = document.createElement('h2');
    const items = cards.filter((c) => c.column === name && (!activeFilter || c.label === activeFilter) && (!activeAssignee || c.assignee === activeAssignee) && (!searchTerm || String(c.title).toLowerCase().includes(searchTerm)));
    h.append(name);
    const badge = document.createElement('span');
    badge.className = 'count';
    badge.textContent = items.length;
    badge.setAttribute('aria-label', `${items.length} cards`);
    h.append(badge);
    col.appendChild(h);
    col.addEventListener('dragover', (e) => {
      e.preventDefault();
      col.classList.add('over');
    });
    col.addEventListener('dragleave', () => col.classList.remove('over'));
    col.addEventListener('drop', async (e) => {
      e.preventDefault();
      col.classList.remove('over');
      const id = e.dataTransfer.getData('text/plain');
      if (id) await api(`/api/cards/${encodeURIComponent(id)}`, 'PATCH', { column: name });
    });
    const today = todayStr();
    for (const c of items) {
      const el = document.createElement('div');
      el.className = 'card';
      if (c.dueDate && c.dueDate < today) el.classList.add('overdue');
      else if (c.dueDate === today) el.classList.add('due-today');
      el.draggable = true;
      el.addEventListener('dragstart', (e) => {
        e.dataTransfer.setData('text/plain', c.id);
        e.dataTransfer.effectAllowed = 'move';
      });
      const t = document.createElement('span');
      t.textContent = c.title;
      const del = document.createElement('button');
      del.type = 'button';
      del.className = 'delete';
      del.textContent = '×';
      del.title = 'Delete card';
      del.addEventListener('click', () => api(`/api/cards/${encodeURIComponent(c.id)}`, 'DELETE'));
      if (LABEL_COLORS[c.label]) {
        const pill = document.createElement('span');
        pill.className = 'pill';
        pill.textContent = c.label;
        pill.style.background = LABEL_COLORS[c.label];
        t.append(pill);
      }
      if (c.dueDate) {
        const due = document.createElement('span');
        due.className = 'due';
        due.textContent = 'Due ' + c.dueDate;
        t.append(due);
      }
      const actions = document.createElement('span');
      actions.className = 'actions';
      if (ASSIGNEES.includes(c.assignee)) {
        const av = document.createElement('span');
        av.className = 'avatar';
        av.textContent = initials(c.assignee);
        av.title = c.assignee;
        av.setAttribute('aria-label', 'Assigned to ' + c.assignee);
        actions.append(av);
      }
      actions.append(del);
      el.append(t, actions);
      col.appendChild(el);
    }
    board.appendChild(col);
  }
}

function toast(msg) {
  let t = document.getElementById('toast');
  if (!t) {
    t = document.createElement('div');
    t.id = 'toast';
    t.setAttribute('role', 'alert');
    document.body.appendChild(t);
  }
  t.textContent = msg;
  t.classList.add('show');
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => t.classList.remove('show'), 3500);
}

async function api(url, method, body) {
  errorEl.textContent = '';
  try {
    const res = await fetch(url, {
      method,
      headers: { 'Content-Type': 'application/json' },
      body: body ? JSON.stringify(body) : undefined,
    });
    if (!res.ok) throw new Error((await res.json()).error || 'Failed');
  } catch (err) {
    errorEl.textContent = err.message;
    toast(err.message);
  }
  await refresh();
}

async function refresh() {
  try {
    const res = await fetch('/api/cards');
    render(await res.json());
  } catch {
    errorEl.textContent = 'Failed to load cards';
  }
}

document.getElementById('add-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  errorEl.textContent = '';
  const title = document.getElementById('title');
  const column = document.getElementById('column');
  try {
    const res = await fetch('/api/cards', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ title: title.value, column: column.value, label: document.getElementById('label').value || null, dueDate: document.getElementById('due').value || null, assignee: document.getElementById('assignee').value || null }),
    });
    if (!res.ok) throw new Error((await res.json()).error || 'Failed');
    title.value = '';
    document.getElementById('due').value = '';
    await refresh();
  } catch (err) {
    errorEl.textContent = err.message;
    toast(err.message);
  }
});

renderFilter();
refresh();
