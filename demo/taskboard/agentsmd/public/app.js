const COLUMNS = ['To Do', 'In Progress', 'Done'];
let filter = '';
let assigneeFilter = '';
let search = '';
function toast(msg) {
  const t = document.createElement('div');
  t.className = 'toast';
  t.textContent = msg;
  document.body.appendChild(t);
  setTimeout(() => t.remove(), 3000);
}
async function failed(res) {
  if (res.ok) return false;
  const j = await res.json().catch(() => ({}));
  toast(j.error || 'Request failed');
  return true;
}
const board =document.getElementById('board');

async function render() {
  const cards = await (await fetch('/api/cards')).json();
  const n = new Date();
  const today = n.getFullYear() + '-' + String(n.getMonth() + 1).padStart(2, '0') + '-' + String(n.getDate()).padStart(2, '0');
  board.innerHTML = '';
  for (const name of COLUMNS) {
    const col = document.createElement('section');
    col.className = 'column';
    const h = document.createElement('h2');
    const visible = cards.filter(c => c.column === name && (!filter || c.label === filter) && (!assigneeFilter || c.assignee === assigneeFilter) && (!search || c.title.toLowerCase().includes(search.toLowerCase())));
    const hName = document.createElement('span');
    hName.textContent = name;
    const badge = document.createElement('span');
    badge.className = 'count';
    badge.textContent = visible.length;
    h.append(hName, badge);
    col.appendChild(h);
    col.addEventListener('dragover', e => { e.preventDefault(); col.classList.add('over'); });
    col.addEventListener('dragleave', () => col.classList.remove('over'));
    col.addEventListener('drop', async e => {
      e.preventDefault();
      col.classList.remove('over');
      const id = e.dataTransfer.getData('text/plain');
      if (!id) return;
      await failed(await fetch('/api/cards/' + encodeURIComponent(id), {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ column: name })
      }));
      render();
    });
    for (const c of visible) {
      const el = document.createElement('div');
      el.className = 'card';
      el.draggable = true;
      el.addEventListener('dragstart', e => e.dataTransfer.setData('text/plain', c.id));
      const t = document.createElement('span');
      t.textContent = c.title;
      const del = document.createElement('button');
      del.className = 'delete';
      del.textContent = '×';
      del.title = 'Delete card';
      del.addEventListener('click', async () => {
        await fetch('/api/cards/' + encodeURIComponent(c.id), { method: 'DELETE' });
        render();
      });
      if (c.label) {
        const pill = document.createElement('span');
        pill.className = 'pill ' + c.label.toLowerCase();
        pill.textContent = c.label;
        t.appendChild(document.createElement('br'));
        t.appendChild(pill);
      }
      if (c.dueDate) {
        const d = document.createElement('div');
        d.className = 'due';
        d.textContent = 'Due ' + c.dueDate;
        t.appendChild(d);
        if (c.dueDate < today) el.classList.add('overdue');
        else if (c.dueDate === today) el.classList.add('due-today');
      }
      if (c.assignee) {
        const av = document.createElement('span');
        av.className = 'avatar';
        av.title = c.assignee;
        av.textContent = c.assignee.split(/\s+/).map(w => w[0]).join('').toUpperCase();
        el.append(t, av, del);
      } else el.append(t, del);
      col.appendChild(el);
    }
    board.appendChild(col);
  }
}

document.getElementById('add-form').addEventListener('submit', async e => {
  e.preventDefault();
  const input = document.getElementById('title');
  const title = input.value.trim();
  if (!title) return;
  const res = await fetch('/api/cards', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ title, label: document.getElementById('label').value || null, assignee: document.getElementById('assignee').value || null, dueDate: document.getElementById('dueDate').value || null })
  });
  if (await failed(res)) return;
  input.value = '';
  document.getElementById('dueDate').value = '';
  render();
});

document.getElementById('filters').addEventListener('click', e => {
  const b = e.target.closest('button[data-filter]');
  if (!b) return;
  filter = b.dataset.filter;
  document.querySelectorAll('#filters button').forEach(x => x.classList.toggle('active', x === b));
  render();
});

document.getElementById('assignee-filters').addEventListener('click', e => {
  const b = e.target.closest('button[data-assignee]');
  if (!b) return;
  assigneeFilter = b.dataset.assignee;
  document.querySelectorAll('#assignee-filters button').forEach(x => x.classList.toggle('active', x === b));
  render();
});

document.getElementById('search').addEventListener('input', e => {
  search = e.target.value.trim();
  render();
});

document.getElementById('clear-filters').addEventListener('click', () => {
  search = '';
  filter = '';
  assigneeFilter = '';
  document.getElementById('search').value = '';
  document.querySelectorAll('#filters button').forEach(x => x.classList.toggle('active', x.dataset.filter === ''));
  document.querySelectorAll('#assignee-filters button').forEach(x => x.classList.toggle('active', x.dataset.assignee === ''));
  render();
});

render();
