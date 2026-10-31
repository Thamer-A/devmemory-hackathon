// DevMemory UI - vanilla JS, no dependencies.
const $ = (s, r = document) => r.querySelector(s);
const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const fmt = (n) => Number(n || 0).toLocaleString("en-US");
const short = (s, n) => { s = String(s || "").replace(/\s+/g, " ").trim(); return s.length > n ? s.slice(0, n - 1) + "…" : s; };
const api = async (path, method = "GET") => {
  const r = await fetch(path, { method });
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(j.error || r.status);
  return j;
};
const post = (path) => api(path, "POST");
function toast(msg, kind = "err") {
  const t = document.createElement("div");
  t.className = "toast " + kind; t.textContent = msg;
  $("#toasts").appendChild(t);
  setTimeout(() => t.classList.add("out"), 3800); setTimeout(() => t.remove(), 4300);
}
const spinner = (msg = "Loading") => `<div class="spin-wrap"><div class="spin"></div><span>${esc(msg)}…</span></div>`;
const human = (n) => (n < 1024 ? n + " B" : n < 1048576 ? (n / 1024).toFixed(1) + " KB" : (n / 1048576).toFixed(1) + " MB");
const FLAB = { fresh: "fresh", "partly-stale": "partly stale", stale: "stale", "context-changed": "context changed" };
const TOOL_ICO = { Read: "▤", Edit: "✎", Write: "✚", Grep: "⌕", Glob: "✱", Bash: "❯", Task: "◈" };

const S = { ov: null, files: [], sessions: [], decisions: [], vault: null, tabs: [], active: null, treeOpen: new Set(["src"]), vOpen: new Set(), secOpen: { "Memory vault": true, Project: true, Files: true, Sessions: true, Decisions: true }, filter: "", cache: {}, loaded: false };
const sidx = {};      // session id -> 1-based index
const cget = (p) => (S.cache[p] ||= api(p).catch((e) => { delete S.cache[p]; throw e; }));

// ---------- boot ----------
async function loadProject() {
  [S.ov, S.files, S.sessions, S.decisions, S.vault] = await Promise.all([
    api("/api/overview"), api("/api/files").then((x) => x.files), api("/api/sessions").then((x) => x.sessions), api("/api/decisions").then((x) => x.decisions), api("/api/vault")]);
  S.cache = {}; S.tabs = []; S.active = null; S.filter = ""; $("#filter").value = "";
  for (const k of Object.keys(sidx)) delete sidx[k];
  S.sessions.forEach((s, i) => (sidx[s.id] = i + 1));
  S.loaded = true;
  $("#proj-name").textContent = S.ov.dir_name + " · " + S.ov.engine;
  document.title = "DevMemory — " + S.ov.dir_name;
  updateStatus();
}
async function boot() {
  const params = new URLSearchParams(location.search);
  let st = {};
  try { st = await api("/api/state"); } catch (e) { toast(e.message); }
  if (!st.project) { renderVault(); return showHome(); }
  try { await loadProject(); } catch (e) {
    toast("Cannot load project: " + e.message);
    $("#view").innerHTML = `<div class="page"><h1>Cannot load project</h1><p class="muted">${esc(e.message)}</p></div>`;
    return showHome();
  }
  renderVault();
  const open = params.get("open");
  if (params.get("task")) packState.task = params.get("task"); // ?open=pack&task=... builds that pack on load
  if (open === "pack" && packState.task) setTimeout(() => { const b = $("#p-go"); if (b) b.click(); }, 300);
  if (open && open !== "overview") { const i = open.indexOf(":"); i < 0 ? openTab(open, "") : openTab(open.slice(0, i), open.slice(i + 1)); }
  else openTab("overview", "");
  if (params.get("home")) showHome();
}

function updateStatus() {
  const ov = S.ov;
  $("#st-left").textContent = `${ov.file_count} files · ${ov.session_count} sessions · scanned ${String(ov.scanned_at || "").replace("T", " ").slice(0, 16)}`;
  $("#st-right").textContent = `local-first · read-only · ${ov.store}`;
}

// ---------- sidebar ----------
function itemHtml(cls, ico, text, sub, attrs, dot) {
  return `<div class="item ${cls}" ${attrs}>${dot ? `<span class="dot ${dot}"></span>` : `<span class="ico">${ico}</span>`}<span class="t">${esc(text)}</span>${sub ? `<span class="sub">${esc(sub)}</span>` : ""}</div>`;
}
const keyOf = (type, id) => type + ":" + id;
function isActive(type, id) { return S.active === keyOf(type, id) ? "active" : ""; }

function buildTree(files) {
  const root = { dirs: {}, files: [] };
  for (const f of files) {
    const parts = f.path.split("/");
    let n = root;
    parts.slice(0, -1).forEach((p) => { n = n.dirs[p] ||= { dirs: {}, files: [] }; });
    n.files.push(f);
  }
  return root;
}
function renderTree(node, prefix, filtering) {
  let h = "";
  for (const d of Object.keys(node.dirs).sort()) {
    const path = prefix ? prefix + "/" + d : d;
    const open = filtering || S.treeOpen.has(path);
    h += `<div><div class="item" data-dir="${esc(path)}"><span class="caret ${open ? "open" : ""}">▶</span><span class="t">${esc(d)}</span></div>`;
    if (open) h += `<div class="kids">${renderTree(node.dirs[d], path, filtering)}</div>`;
    h += "</div>";
  }
  for (const f of node.files.sort((a, b) => a.path.localeCompare(b.path)))
    h += itemHtml(isActive("file", f.path), "●", f.path.split("/").pop(), "", `data-open="file" data-id="${esc(f.path)}" title="${esc(f.path)}"`).replace('class="ico"', `class="ico lang-${esc(f.lang)}"`);
  return h;
}
function secHead(name, n) {
  return `<div class="sec-h" data-sec="${name}"><span class="caret ${S.secOpen[name] ? "open" : ""}">▶</span>${name}${n != null ? `<span class="n">${n}</span>` : ""}</div>`;
}
// ---- memory vault tree (real files in the store dir) ----
const VICO = { md: ["¶", "vi-md"], json: ["{ }", "vi-json"], jsonl: ["≋", "vi-jsonl"], other: ["▫", "vi-other"] };
function vkind(name) { return name.endsWith(".jsonl") ? "jsonl" : name.endsWith(".json") ? "json" : /\.(md|markdown)$/i.test(name) ? "md" : "other"; }
function vcount(nodes) { return nodes.reduce((n, x) => n + (x.type === "dir" ? vcount(x.children) : 1), 0); }
function renderVTree(nodes, q, depth) {
  let h = "";
  for (const n of nodes) {
    if (n.type === "dir") {
      const kids = q ? n.children.filter(function f(c) { return c.type === "dir" ? c.children.some(f) : c.path.toLowerCase().includes(q); }) : n.children;
      if (q && !kids.length) continue;
      const open = !!q || S.vOpen.has(n.path);
      h += `<div><div class="item vrow" data-vdir="${esc(n.path)}"><span class="caret ${open ? "open" : ""}">▶</span><span class="ico vi-dir">▣</span><span class="t">${esc(n.name)}</span><span class="sub">${vcount(n.children)}</span></div>`;
      if (open) h += `<div class="kids">${renderVTree(kids, q, depth + 1)}</div>`;
      h += "</div>";
    } else {
      if (q && !n.path.toLowerCase().includes(q)) continue;
      const [g, c] = VICO[vkind(n.name)];
      h += `<div class="item vrow ${isActive("vault", n.path)}" data-open="vault" data-id="${esc(n.path)}" title="${esc(n.path)}"><span class="ico ${c}">${g}</span><span class="t">${(() => { const k = n.name.indexOf(".", 1); return k > 0 && n.name.length > 20 ? `<span class="stem">${esc(n.name.slice(0, k))}</span><span class="ext">${esc(n.name.slice(k))}</span>` : esc(n.name); })()}</span><span class="sub">${human(n.size)}</span></div>`;
    }
  }
  return h;
}
function renderVault() {
  if (!S.loaded) { $("#vault").innerHTML = '<div class="empty" style="padding:14px">No project open.</div>'; return; }
  const q = S.filter.toLowerCase();
  const files = q ? S.files.filter((f) => f.path.toLowerCase().includes(q)) : S.files;
  let h = secHead("Memory vault");
  if (S.secOpen["Memory vault"]) h += `<div class="vroot" title="${esc(S.vault.path)}"><span class="ico vi-dir">◈</span>${esc(S.vault.root)}</div>` + (S.vault.tree.length ? renderVTree(S.vault.tree, q, 0) : '<div class="empty">Store is empty. Rescan to create it.</div>');
  h += secHead("Project");
  if (S.secOpen.Project) h += itemHtml(isActive("overview", ""), "▦", "Overview", "", 'data-open="overview" data-id=""') +
    itemHtml(isActive("conventions", ""), "☰", "Conventions", S.ov.conventions.length, 'data-open="conventions" data-id=""') +
    itemHtml(isActive("map", ""), "▤", "Project map", "", 'data-open="map" data-id=""') +
    itemHtml(isActive("graph", ""), "✵", "Graph view", "G", 'data-open="graph" data-id=""') +
    itemHtml(isActive("pack", ""), "⚙", "Pack Lab", "", 'data-open="pack" data-id=""');
  h += secHead("Files", files.length);
  if (S.secOpen.Files) h += renderTree(buildTree(files), "", !!q);
  const ss = q ? S.sessions.filter((s) => (s.prompt || "").toLowerCase().includes(q)) : S.sessions;
  h += secHead("Sessions", ss.length);
  if (S.secOpen.Sessions) h += ss.map((s) => itemHtml(isActive("session", s.id), "", `S${sidx[s.id]} ${short(s.prompt, 40)}`, (s.started_at || "").slice(5, 10), `data-open="session" data-id="${esc(s.id)}" title="${esc(short(s.prompt, 200))}"`, s.freshness)).join("");
  const ds = q ? S.decisions.filter((d) => d.text.toLowerCase().includes(q)) : S.decisions;
  h += secHead("Decisions", ds.length);
  if (S.secOpen.Decisions) h += ds.map((d) => itemHtml(isActive("decision", d.id), "◆", short(d.text, 44), "", `data-open="decision" data-id="${esc(d.id)}" title="${esc(d.text)}"`)).join("");
  const v = $("#vault"), top = v.scrollTop;
  v.innerHTML = h;
  v.scrollTop = top;
}
$("#vault").addEventListener("click", (e) => {
  const sec = e.target.closest("[data-sec]");
  if (sec) { S.secOpen[sec.dataset.sec] = !S.secOpen[sec.dataset.sec]; return renderVault(); }
  const vd = e.target.closest("[data-vdir]");
  if (vd) { const p = vd.dataset.vdir; S.vOpen.has(p) ? S.vOpen.delete(p) : S.vOpen.add(p); return renderVault(); }
  const dir = e.target.closest("[data-dir]");
  if (dir) { const p = dir.dataset.dir; S.treeOpen.has(p) ? S.treeOpen.delete(p) : S.treeOpen.add(p); return renderVault(); }
  const it = e.target.closest("[data-open]");
  if (it) openTab(it.dataset.open, it.dataset.id);
});
$("#filter").addEventListener("input", (e) => { S.filter = e.target.value.trim(); renderVault(); });
document.addEventListener("click", (e) => {
  const it = e.target.closest("[data-open]");
  if (it && !it.closest("#vault")) openTab(it.dataset.open, it.dataset.id || "");
});
$("#rescan").onclick = async () => {
  const b = $("#rescan"); b.textContent = "Scanning...";
  try {
    S.files = (await api("/api/files?rescan=1")).files; S.cache = {};
    [S.ov, S.vault] = await Promise.all([api("/api/overview"), api("/api/vault")]); renderVault(); updateStatus(); render(); toast("Rescan complete", "ok");
  } catch (e) { toast("Rescan failed: " + e.message); }
  b.textContent = "Rescan";
};

// ---------- tabs ----------
function titleOf(type, id) {
  switch (type) {
    case "overview": return "Overview";
    case "conventions": return "Conventions";
    case "map": return "Project map";
    case "graph": return "Graph view";
    case "pack": return "Pack Lab";
    case "file": return id.split("/").pop();
    case "session": return `Session S${sidx[id] || "?"}`;
    case "vault": {
      const m = id.match(/^sessions\/(.+?)(\.meta\.json|\.jsonl)$/), s = m && S.sessions.find((x) => (x.meta_file || "").startsWith(m[1] + "."));
      if (s) return `S${sidx[s.id]} ${m[2] === ".jsonl" ? "raw" : "note"}`;
      return id.split("/").pop();
    }
    case "decision": return "Decision " + id.replace("d", "#");
    case "convention": return "Convention " + id.replace("c", "#");
  }
  return id;
}
function openTab(type, id) {
  id = id || "";
  if (!S.loaded) return;
  const key = keyOf(type, id);
  if (type === "vault") { const p = id.split("/"); for (let i = 1; i < p.length; i++) S.vOpen.add(p.slice(0, i).join("/")); }
  if (!S.tabs.find((t) => t.key === key)) S.tabs.push({ key, type, id });
  S.active = key;
  renderTabs(); renderVault(); render();
}
function closeTab(key) {
  const i = S.tabs.findIndex((t) => t.key === key);
  if (i < 0) return;
  S.tabs.splice(i, 1);
  if (S.active === key) S.active = S.tabs.length ? S.tabs[Math.min(i, S.tabs.length - 1)].key : null;
  if (!S.tabs.length) return openTab("overview", "");
  renderTabs(); renderVault(); render();
}
function renderTabs() {
  $("#tabs").innerHTML = S.tabs.map((t) => `<div class="tab ${t.key === S.active ? "active" : ""}" data-key="${esc(t.key)}"><span class="t">${esc(titleOf(t.type, t.id))}</span><span class="x" data-close="${esc(t.key)}">×</span></div>`).join("");
  const a = $(".tab.active"); if (a) a.scrollIntoView({ block: "nearest", inline: "nearest" });
}
$("#tabs").addEventListener("click", (e) => {
  const x = e.target.closest("[data-close]");
  if (x) return closeTab(x.dataset.close);
  const t = e.target.closest(".tab");
  if (t) { S.active = t.dataset.key; renderTabs(); renderVault(); render(); }
});
$("#tabs").addEventListener("auxclick", (e) => { const t = e.target.closest(".tab"); if (t && e.button === 1) closeTab(t.dataset.key); });

// ---------- render dispatch ----------
let graphCtl = null;
async function render() {
  const tab = S.tabs.find((t) => t.key === S.active);
  if (!tab) return;
  if (graphCtl) { graphCtl.stop(); graphCtl = null; }
  const v = $("#view");
  const my = S.active;
  const spin = setTimeout(() => { if (S.active === my) v.innerHTML = spinner(); }, 140);
  try {
    const R = { overview: vOverview, conventions: vConventions, map: vMap, file: vFile, session: vSession, decision: vDecision, convention: vConvention, graph: vGraph, pack: vPack, vault: vVault }[tab.type];
    if (!R) throw new Error("Unknown view: " + tab.type);
    const out = await R(v, tab.id);
    clearTimeout(spin);
    if (S.active !== my) return;
    setSide(out || { linked: [], props: [] });
  } catch (e) {
    clearTimeout(spin);
    if (S.active !== my) return;
    v.innerHTML = `<div class="page"><h1>Cannot open this item</h1><p class="muted">${esc(e.message)}</p></div>`;
    toast(e.message);
    setSide({ linked: [], props: [] });
  }
}
function linkItem(type, id, label, sub, dot) {
  return itemHtml("", type === "file" ? "●" : type === "decision" ? "◆" : "☰", label, sub || "", `data-open="${type}" data-id="${esc(id)}" title="${esc(label)}"`, dot);
}
function setSide({ linked, props }) {
  $("#linked").innerHTML = linked.length ? linked.join("") : '<div class="empty">No links</div>';
  $("#props").innerHTML = props.map(([k, v]) => `<span class="k">${esc(k)}</span><span class="v">${v}</span>`).join("") || '<div class="empty">None</div>';
}
const tag = (st) => `<span class="tag ${esc(st)}">${esc(FLAB[st] || st)}</span>`;
const fileChip = (f) => `<span class="chip file" data-open="file" data-id="${esc(f)}">${esc(f.split("/").pop())}</span>`;
const sessChip = (s) => `<span class="chip" data-open="session" data-id="${esc(s.id)}"><span class="dot ${esc(s.freshness)}"></span>S${sidx[s.id]} ${esc(short(s.prompt, 38))}</span>`;
const sessLinks = (ids) => ids.map((id) => { const s = S.sessions.find((x) => x.id === id); return s ? linkItem("session", s.id, `S${sidx[id]} ${short(s.prompt, 30)}`, "", s.freshness) : ""; });

// ---------- overview ----------
function barChart(data, key, color, label) {
  const W = 420, H = 150, pad = 24, max = Math.max(1, ...data.map((d) => d[key]));
  const bw = Math.min(46, (W - pad * 2) / Math.max(1, data.length) - 8);
  let g = "";
  data.forEach((d, i) => {
    const x = pad + i * ((W - pad * 2) / data.length) + 4, h = Math.max(2, (d[key] / max) * (H - 44)), y = H - 22 - h;
    g += `<g><rect x="${x}" y="${H - 22}" width="${bw}" height="0" rx="3" fill="${color}"><animate attributeName="height" from="0" to="${h}" dur=".5s" fill="freeze"/><animate attributeName="y" from="${H - 22}" to="${y}" dur=".5s" fill="freeze"/><title>S${i + 1}: ${fmt(d[key])}</title></rect>
      <text x="${x + bw / 2}" y="${y - 4}" text-anchor="middle">${d[key] >= 1000 ? (d[key] / 1000).toFixed(d[key] >= 100000 ? 0 : 1) + "k" : d[key]}</text><text x="${x + bw / 2}" y="${H - 8}" text-anchor="middle">S${i + 1}</text></g>`;
  });
  return `<div class="panel"><div class="muted" style="margin-bottom:4px">${label}</div><svg class="bars" viewBox="0 0 ${W} ${H}" width="100%">${g}</svg></div>`;
}
async function vOverview(v) {
  const ov = S.ov, fr = ov.freshness, stale = (fr.stale || 0) + (fr["partly-stale"] || 0);
  const total = Math.max(1, ov.session_count);
  const fb = ["fresh", "partly-stale", "stale", "context-changed"].filter((k) => fr[k]).map((k) =>
    `<div style="display:flex;align-items:center;gap:10px;margin:6px 0"><span class="dot ${k}"></span><span style="width:110px">${FLAB[k]}</span><div class="meter" style="flex:1"><i style="width:${(fr[k] / total) * 100}%"></i></div><b>${fr[k]}</b></div>`).join("");
  v.innerHTML = `<div class="page"><h1>${esc(ov.project)}</h1><div class="sub-h"><span class="tag fresh" style="color:var(--cyan);border-color:#38d6e855;background:#38d6e814">${esc(ov.engine)}</span><span>Deterministic index, 0 LLM tokens. Scanned ${esc(String(ov.scanned_at || "").replace("T", " ").slice(0, 19))} UTC</span></div>
  <div class="cards">
    <div class="card"><div class="lbl">Files indexed</div><div class="val c">${fmt(ov.file_count)}</div></div>
    <div class="card"><div class="lbl">Sessions</div><div class="val v">${fmt(ov.session_count)}</div><div class="note">${ov.decision_count} decisions</div></div>
    <div class="card"><div class="lbl">Captured tokens</div><div class="val">${fmt(ov.tokens.input + ov.tokens.output)}</div><div class="note">in+out; ${fmt(ov.tokens.cache)} cached</div></div>
    <div class="card"><div class="lbl">Cost (list)</div><div class="val g">$${ov.cost_usd.toFixed(3)}</div></div>
    <div class="card"><div class="lbl">Stale memories</div><div class="val ${stale ? "a" : "g"}">${stale}</div><div class="note">of ${ov.session_count} sessions</div></div>
  </div>
  <h2>Tokens per session</h2>
  <div class="row2">${barChart(ov.per_session, "output", "#8b7cf6", "Output tokens")}${barChart(ov.per_session.map((d) => ({ ...d, ctx: d.input + d.cache })), "ctx", "#38d6e8", "Context tokens (input + cache)")}</div>
  <div class="row2"><div><h2>Freshness</h2><div class="panel">${fb || '<span class="muted">No sessions captured yet</span>'}</div></div>
  <div><h2>Rojo mapping</h2><div class="panel">${Object.keys(ov.rojo).length ? Object.entries(ov.rojo).map(([k, x]) => `<div style="padding:2px 0"><code>${esc(k)}</code> <span class="dim">→</span> ${esc(x)}</div>`).join("") : '<span class="muted">None</span>'}</div></div></div>
  <h2>Conventions observed</h2><div class="panel"><ul class="plain">${ov.conventions.map((c, i) => `<li data-open="convention" data-id="c${i + 1}" style="cursor:pointer">${md(c)}</li>`).join("") || '<li class="muted">None observed</li>'}</ul></div>
  </div>`;
  return { linked: [linkItem("graph", "", "Graph view")], props: [["Project", esc(ov.project)], ["Engine", esc(ov.engine)], ["Path", esc(ov.project_path)], ["Store", esc(ov.store)], ["Files", ov.file_count], ["Sessions", ov.session_count]] };
}
const md = (s) => esc(s).replace(/`([^`]+)`/g, "<code>$1</code>");

async function vConventions(v) {
  v.innerHTML = `<div class="page"><h1>Conventions</h1><div class="sub-h">Observed in code by the scanner, not inferred by a model.</div><div class="panel"><ul class="plain">${S.ov.conventions.map((c, i) => `<li data-open="convention" data-id="c${i + 1}" style="cursor:pointer">${md(c)}</li>`).join("") || '<li class="muted">None</li>'}</ul></div></div>`;
  return { linked: [], props: [["Count", S.ov.conventions.length], ["Source", "scan.py"]] };
}
async function vMap(v) {
  const ov = S.ov, by = {};
  S.files.forEach((f) => { const d = f.path.includes("/") ? f.path.split("/").slice(0, 2).join("/") : "."; (by[d] ||= []).push(f); });
  v.innerHTML = `<div class="page"><h1>Project map</h1><div class="sub-h">${ov.file_count} files grouped by folder. Also written to <code>PROJECT.md</code> in the store.</div>` +
    Object.keys(by).sort().map((d) => `<h2>${esc(d)} <span class="dim">(${by[d].length})</span></h2><div class="panel">${by[d].map((f) => `<div class="item" data-open="file" data-id="${esc(f.path)}"><span class="ico lang-${esc(f.lang)}">●</span><span class="t">${esc(f.path)}</span><span class="sub">${f.lines} lines</span></div>`).join("")}</div>`).join("") + "</div>";
  return { linked: [], props: [["Files", ov.file_count], ["Scanned", esc(ov.scanned_at)]] };
}

// ---------- file view ----------
const KW = {
  lua: "and break do else elseif end false for function goto if in local nil not or repeat return then true until while continue export type typeof",
  python: "and as assert async await break class continue def del elif else except False finally for from global if import in is lambda None nonlocal not or pass raise return True try while with yield self",
  js: "async await break case catch class const continue default delete do else export extends false finally for from function if import in instanceof let new null of return static super switch this throw true try typeof undefined var void while yield interface type enum implements",
};
function langFam(l) { return l === "luau" || l === "lua" ? "lua" : l === "python" ? "python" : l === "js" || l === "ts" ? "js" : null; }
function highlight(text, lang) {
  const fam = langFam(lang);
  const lines = [""];
  const push = (cls, s) => {
    const parts = s.split("\n");
    parts.forEach((p, i) => { if (i) lines.push(""); if (p) lines[lines.length - 1] += cls ? `<span class="${cls}">${esc(p)}</span>` : esc(p); });
  };
  if (!fam) { push("", text); return lines; }
  const kw = new Set(KW[fam].split(" "));
  const com = fam === "lua" ? "--\\[\\[[\\s\\S]*?\\]\\]|--\\[=\\[[\\s\\S]*?\\]=\\]|--[^\\n]*" : fam === "python" ? "#[^\\n]*" : "\\/\\/[^\\n]*|\\/\\*[\\s\\S]*?\\*\\/";
  const str = fam === "python" ? `"""[\\s\\S]*?"""|'''[\\s\\S]*?'''|"(?:\\\\.|[^"\\\\\\n])*"|'(?:\\\\.|[^'\\\\\\n])*'` : fam === "lua" ? `\\[\\[[\\s\\S]*?\\]\\]|"(?:\\\\.|[^"\\\\\\n])*"|'(?:\\\\.|[^'\\\\\\n])*'|\`(?:\\\\.|[^\`\\\\\\n])*\`` : `"(?:\\\\.|[^"\\\\\\n])*"|'(?:\\\\.|[^'\\\\\\n])*'|\`(?:\\\\.|[^\`\\\\])*\``;
  let re;
  try { re = new RegExp(`(${com})|(${str})|(\\b0x[0-9a-fA-F]+\\b|\\b\\d+(?:\\.\\d+)?\\b)|([A-Za-z_][A-Za-z0-9_]*)`, "g"); } catch (e) { push("", text); return lines; }
  let last = 0, m;
  // group indexes shift because of backrefs in alternations; find them by role instead
  while ((m = re.exec(text))) {
    if (m.index > last) push("", text.slice(last, m.index));
    const tok = m[0];
    let cls = "";
    if (fam === "lua" ? tok.startsWith("--") : fam === "python" ? tok.startsWith("#") : tok.startsWith("//") || tok.startsWith("/*")) cls = "tk-c";
    else if (/^["'`]/.test(tok) || /^\[=*\[/.test(tok)) cls = "tk-s";
    else if (/^\d/.test(tok)) cls = "tk-n";
    else if (kw.has(tok)) cls = "tk-k";
    else if (text[re.lastIndex] === "(" ) cls = "tk-f";
    push(cls, tok);
    last = re.lastIndex;
    if (m[0].length === 0) re.lastIndex++;
  }
  if (last < text.length) push("", text.slice(last));
  return lines;
}
async function vFile(v, path) {
  const d = await cget("/api/file?path=" + encodeURIComponent(path));
  const e = d.entry, hl = highlight(d.content, e.lang);
  const rem = (e.remotes_defined || []).map((r) => `<span class="chip plain">${esc(r)}</span>`).join("");
  const remU = Object.entries(e.remotes_used || {}).map(([k, x]) => `<span class="chip plain">${esc(k)} <span class="dim">${esc(x.join("/"))}</span></span>`).join("");
  v.innerHTML = `<div class="page"><h1>${esc(path.split("/").pop())}</h1><div class="sub-h mono">${esc(path)}</div>
   <div class="panel" style="margin-bottom:14px"><div class="props" style="grid-template-columns:100px 1fr;padding:0">
   <span class="k">Module</span><span class="v">${esc(e.module)} ${e.kind ? `<span class="dim">(${esc(e.kind)})</span>` : ""}</span>
   <span class="k">Symbols</span><span class="v">${(e.symbols || []).map((s) => `<code>${esc(s)}</code>`).join(" ") || '<span class="dim">none</span>'}</span>
   ${rem ? `<span class="k">Defines remotes</span><span class="v">${rem}</span>` : ""}${remU ? `<span class="k">Uses remotes</span><span class="v">${remU}</span>` : ""}
   <span class="k">Requires</span><span class="v">${d.requires.map(fileChip).join("") || '<span class="dim">nothing</span>'}</span>
   <span class="k">Used by</span><span class="v">${d.used_by.map(fileChip).join("") || '<span class="dim">no one</span>'}</span>
   <span class="k">Sessions</span><span class="v">${d.sessions.map((s) => sessChip(s) ).join("") || '<span class="dim">no captured session touched this file</span>'}</span></div></div>
   <div class="codebox"><pre>${hl.map((l, i) => `<div class="ln"><span class="n">${i + 1}</span><span class="c">${l || " "}</span></div>`).join("")}</pre></div></div>`;
  return {
    linked: [...d.requires.map((f) => linkItem("file", f, f.split("/").pop(), "requires")), ...d.used_by.map((f) => linkItem("file", f, f.split("/").pop(), "used by")),
      ...d.sessions.map((s) => linkItem("session", s.id, `S${sidx[s.id]} ${short(s.prompt, 26)}`, s.role, s.freshness))],
    props: [["Language", esc(e.lang)], ["Lines", e.lines], ["Bytes", fmt(e.bytes)], ["Hash", `<code>${esc(e.hash)}</code>`], ["Symbols", (e.symbols || []).length], ["Used by", d.used_by.length]],
  };
}

// ---------- session view ----------
function diffHtml(old, nw) {
  const cut = (s) => { const l = String(s || "").split("\n"); return l.length > 10 ? [...l.slice(0, 10), `… (${l.length - 10} more lines)`] : l; };
  return `<div class="diff">${old ? cut(old).map((l) => `<div class="del">- ${esc(l)}</div>`).join("") : ""}${nw ? cut(nw).map((l) => `<div class="add">+ ${esc(l)}</div>`).join("") : ""}</div>`;
}
async function vSession(v, id) {
  const d = await cget("/api/session?id=" + encodeURIComponent(id));
  const m = d.meta, f = d.freshness, u = m.usage || {};
  const calls = m.tool_calls || [], say = m.assistant_text || [];
  const items = [...calls.map((t) => ({ line: t.line, kind: "tool", t })), ...say.map((a) => ({ line: a.line, kind: "say", a }))].sort((a, b) => (a.line || 0) - (b.line || 0));
  const tl = items.map((it) => {
    if (it.kind === "say") return `<div class="tl assistant"><span class="ico">●</span><div class="head"><span class="muted">Assistant said</span></div><div class="say">${esc(short(it.a.text, 420))}</div></div>`;
    const t = it.t, tgt = t.file ? fileChip(t.file) : "";
    return `<div class="tl ${esc(t.tool)}"><span class="ico">${TOOL_ICO[t.tool] || "▪"}</span><div class="head"><span class="tool">${esc(t.tool)}</span>${tgt}${t.pattern ? `<code>${esc(short(t.pattern, 80))}</code>` : ""}<span class="dim mono" style="margin-left:auto">L${t.line ?? ""}</span></div>
      ${t.command ? `<div class="cmd">${esc(short(t.command, 400))}</div>` : ""}${t.tool === "Edit" ? diffHtml(t.old, t.new) : t.tool === "Write" && t.new ? diffHtml("", t.new) : ""}</div>`;
  }).join("");
  const why = f.status === "fresh" ? "Everything this session changed is still present in the current code." :
    f.status === "context-changed" ? `Files it read have changed since: ${f.read_files_changed.map(fileChip).join("")}` :
    `Edits no longer present in: ${f.edits_gone_from.map(fileChip).join("") || "(unknown)"}${f.edits_present_in.length ? ` <span class="dim">still intact in</span> ${f.edits_present_in.map(fileChip).join("")}` : ""}`;
  v.innerHTML = `<div class="page"><h1>Session S${sidx[d.id]}</h1><div class="sub-h">${tag(f.status)}<span>${esc(m.started_at)}</span><span class="dim">·</span><span>${esc(m.model || "")}</span>${m.script_id ? `<span class="dim">· ${esc(m.script_id)}</span>` : ""}</div>
   <div class="banner ${esc(f.status)}"><span class="dot ${esc(f.status)}" style="margin-top:7px"></span><div><b>${esc(FLAB[f.status] || f.status)}.</b> ${why}</div></div>
   <h2>You asked</h2><div class="quote">${esc(m.prompt || "")}</div>
   <h2>Outcome <span class="dim" style="text-transform:none;letter-spacing:0">(assistant-visible text)</span></h2><div class="outcome">${esc(m.result_text || "(none)")}</div>
   <h2>Usage</h2><div class="cards">
     <div class="card"><div class="lbl">Output</div><div class="val v">${fmt(u.output_tokens)}</div></div><div class="card"><div class="lbl">Input</div><div class="val">${fmt(u.input_tokens)}</div></div>
     <div class="card"><div class="lbl">Cache read</div><div class="val c">${fmt(u.cache_read_tokens)}</div></div><div class="card"><div class="lbl">Turns</div><div class="val">${fmt(u.num_turns)}</div><div class="note">${((u.duration_ms || 0) / 1000).toFixed(1)}s</div></div>
     <div class="card"><div class="lbl">Cost (list)</div><div class="val g">$${(u.cost_usd_list || 0).toFixed(4)}</div></div></div>
   <h2>Timeline <span class="dim">(${calls.length} tool calls)</span></h2><div class="timeline">${tl || '<span class="muted">No tool calls recorded</span>'}</div>
   ${(m.errors || []).length ? `<h2>Errors</h2><div class="panel">${m.errors.map((x) => `<div class="mono" style="color:var(--red)">${esc(short(typeof x === "string" ? x : JSON.stringify(x), 300))}</div>`).join("")}</div>` : ""}
   <h2>Source</h2><div class="panel">Raw record: <code>sessions/${esc(m.raw_record || "")}</code> <span class="dim">(full stream kept in the store, never loaded into routine prompts)</span></div></div>`;
  const rel = S.decisions.filter((x) => x.session === d.id);
  return {
    linked: [...(m.files_edited || []).map((x) => linkItem("file", x, x.split("/").pop(), "edited")), ...(m.files_read || []).filter((x) => !(m.files_edited || []).includes(x)).map((x) => linkItem("file", x, x.split("/").pop(), "read")), ...rel.map((x) => linkItem("decision", x.id, short(x.text, 34)))],
    props: [["Session", `<code>${esc(String(d.id).slice(0, 8))}</code>`], ["Status", tag(f.status)], ["Model", esc(m.model || "-")], ["Provider", esc(m.provider || "-")], ["Capture", esc(m.capture_method || "-")], ["Files read", (m.files_read || []).length], ["Files edited", (m.files_edited || []).length]],
  };
}

// ---------- decisions / conventions ----------
async function vDecision(v, id) {
  const d = S.decisions.find((x) => x.id === id);
  if (!d) throw new Error("Unknown decision");
  const s = S.sessions.find((x) => x.id === d.session);
  v.innerHTML = `<div class="page"><h1>Decision ${esc(id.replace("d", "#"))}</h1><div class="sub-h">Standing rule stated by the user. Their own words, extracted deterministically.</div>
   <div class="quote">${esc(d.text)}</div><h2>Backlinks</h2><div class="panel">Stated in ${s ? sessChip(s) : ""}<div class="dim" style="margin-top:6px">${esc(d.started_at)}</div></div></div>`;
  return { linked: s ? [linkItem("session", s.id, `S${sidx[s.id]} ${short(s.prompt, 30)}`, "", s.freshness)] : [], props: [["Type", "decision"], ["Observed", "user prompt"], ["Session", s ? "S" + sidx[s.id] : "-"], ["Date", esc((d.started_at || "").slice(0, 10))]] };
}
async function vConvention(v, id) {
  const line = S.ov.conventions[Number(id.slice(1)) - 1];
  if (!line) throw new Error("Unknown convention");
  const paths = [...line.matchAll(/[\w./-]+\.(?:luau|lua|py|js|ts|json)|[\w./-]+\//g)].map((m) => m[0]);
  const files = S.files.filter((f) => paths.some((p) => f.path === p || (p.endsWith("/") && f.path.startsWith(p)))).slice(0, 12);
  v.innerHTML = `<div class="page"><h1>Convention ${esc(id.replace("c", "#"))}</h1><div class="sub-h">Observed in code by the scanner. Evidence below.</div><div class="note-body">${md(line)}</div>
   <h2>Evidence files</h2><div class="panel">${files.map((f) => fileChip(f.path)).join("") || '<span class="muted">No single file (project-wide observation)</span>'}</div></div>`;
  return { linked: files.map((f) => linkItem("file", f.path, f.path.split("/").pop())), props: [["Type", "convention"], ["Source", "scan.py (observed)"], ["Evidence files", files.length]] };
}

// ---------- pack lab ----------
const packState = { task: "", budget: 1500, mode: "full", res: null };
async function vPack(v) {
  v.innerHTML = `<div class="page"><h1>Pack Lab</h1><div class="sub-h">Build the exact context a fresh session would receive for a task: zero LLM tokens, every item sourced.</div>
  <textarea class="big" id="p-task" placeholder="What do you want to do next?">${esc(packState.task)}</textarea>
  <div class="ctrls"><label>Budget <input type="range" id="p-budget" min="300" max="4000" step="100" value="${packState.budget}"> <b id="p-bv">${packState.budget}</b> tokens</label>
  <label>Mode <select id="p-mode">${["full", "static", "nofresh"].map((m) => `<option ${m === packState.mode ? "selected" : ""}>${m}</option>`).join("")}</select></label>
  <button class="btn" id="p-go">Build pack</button><span class="dim" id="p-st"></span></div><div id="p-out"></div></div>`;
  const out = $("#p-out");
  $("#p-budget").oninput = (e) => { packState.budget = +e.target.value; $("#p-bv").textContent = e.target.value; };
  $("#p-mode").onchange = (e) => (packState.mode = e.target.value);
  $("#p-task").oninput = (e) => (packState.task = e.target.value);
  $("#p-task").addEventListener("keydown", (e) => { if ((e.ctrlKey || e.metaKey) && e.key === "Enter") $("#p-go").click(); });
  const show = () => {
    const r = packState.res; if (!r) return;
    const i = r.info, pct = Math.min(100, (i.tokens_est / r.budget) * 100);
    out.innerHTML = `<h2>Token meter</h2><div class="panel"><div style="display:flex;justify-content:space-between"><span><b>${fmt(i.tokens_est)}</b> est. tokens</span><span class="dim">budget ${fmt(r.budget)} · ${i.items} items · mode ${esc(i.mode)}</span></div><div class="meter ${i.tokens_est > r.budget ? "over" : ""}"><i style="width:0" data-w="${pct}"></i></div><div class="dim" style="font-size:12px">Estimate (chars/4 style), not provider-billed tokens.</div></div>
     <h2>Included</h2>${i.file_details.map((f) => `<div class="pcard"><div style="display:flex;gap:8px;align-items:center"><span class="dim">FILE</span>${fileChip(f.path)}<span class="dim">${f.lines || "?"} lines</span></div><div class="why">module ${esc(f.module || "")} · ranked by BM25 over path, symbols, remotes and content</div></div>`).join("")}
     ${i.sessions.map((s) => `<div class="pcard"><div style="display:flex;gap:8px;align-items:center;flex-wrap:wrap"><span class="dim">SESSION</span>${sidx[s.session] ? `<span class="chip" data-open="session" data-id="${esc(s.session)}">S${sidx[s.session]}</span>` : ""}${s.freshness ? tag(s.freshness) : '<span class="dim">freshness not checked</span>'}<span class="dim">score ${s.score}</span></div><div class="why">${esc(short(s.prompt, 150))}</div><div class="why">matched: ${(s.matched || []).map((t) => `<code>${esc(t)}</code>`).join(" ")}</div></div>`).join("")}
     ${i.decisions ? `<div class="pcard"><span class="dim">DECISIONS</span> ${i.decisions} standing decision(s) from past prompts included</div>` : ""}
     ${!i.items ? '<div class="empty">Nothing relevant retrieved. Only the map header and conventions are included.</div>' : ""}
     <h2>Raw markdown <button class="btn ghost" id="p-copy" style="margin-left:10px;padding:2px 12px">Copy</button></h2><div class="md" id="p-md"></div>`;
    $("#p-md").textContent = r.markdown;
    requestAnimationFrame(() => requestAnimationFrame(() => { const b = out.querySelector(".meter i"); if (b) b.style.width = b.dataset.w + "%"; }));
    $("#p-copy").onclick = async () => { try { await navigator.clipboard.writeText(r.markdown); } catch { const t = document.createElement("textarea"); t.value = r.markdown; document.body.appendChild(t); t.select(); document.execCommand("copy"); t.remove(); } $("#p-copy").textContent = "Copied"; setTimeout(() => ($("#p-copy") && ($("#p-copy").textContent = "Copy")), 1400); };
  };
  $("#p-go").onclick = async () => {
    if (!packState.task.trim()) { $("#p-st").textContent = "Enter a task first."; return; }
    $("#p-st").textContent = "Building...";
    try {
      packState.res = await api(`/api/pack?task=${encodeURIComponent(packState.task)}&budget=${packState.budget}&mode=${packState.mode}`);
      $("#p-st").textContent = ""; show();
    } catch (e) { $("#p-st").textContent = "Error: " + e.message; }
  };
  show();
  return { linked: [], props: [["Mode", packState.mode], ["Budget", packState.budget]] };
}

// ---------- graph ----------
const GCOL = { file: "#38d6e8", session: "#8b7cf6", decision: "#f08cc8", convention: "#7ee08f" };
const graphFilter = { file: true, session: true, decision: true, convention: true };
async function vGraph(v) {
  const g = await cget("/api/graph");
  v.innerHTML = `<div id="graphwrap"><canvas></canvas><div class="glegend">${Object.keys(GCOL).map((t) => `<label><input type="checkbox" data-t="${t}" ${graphFilter[t] ? "checked" : ""}><i style="background:${GCOL[t]}"></i>${t}s</label>`).join("")}<label style="margin-top:4px"><span class="ring"></span>stale / partly stale session</label></div><div class="ghint">Drag nodes · scroll to zoom · drag background to pan · click to open</div><div class="gtip hidden"></div></div>`;
  const wrap = $("#graphwrap");
  graphCtl = makeGraph(wrap, g);
  wrap.querySelectorAll("input[data-t]").forEach((c) => (c.onchange = () => { graphFilter[c.dataset.t] = c.checked; graphCtl.refilter(); }));
  return { linked: [], props: [["Nodes", g.nodes.length], ["Edges", g.edges.length], ["Files", g.nodes.filter((n) => n.type === "file").length], ["Sessions", g.nodes.filter((n) => n.type === "session").length]] };
}
function makeGraph(wrap, data) {
  const cv = wrap.querySelector("canvas"), ctx = cv.getContext("2d"), tip = wrap.querySelector(".gtip");
  const nodes = data.nodes.map((n, i) => ({ ...n, x: Math.cos(i * 2.4) * (60 + i * 3), y: Math.sin(i * 2.4) * (60 + i * 3), vx: 0, vy: 0, deg: 0 }));
  const byId = Object.fromEntries(nodes.map((n) => [n.id, n]));
  const edges = data.edges.filter((e) => byId[e.source] && byId[e.target]).map((e) => ({ a: byId[e.source], b: byId[e.target], kind: e.kind }));
  edges.forEach((e) => { e.a.deg++; e.b.deg++; });
  const nbr = {}; edges.forEach((e) => { (nbr[e.a.id] ||= new Set()).add(e.b.id); (nbr[e.b.id] ||= new Set()).add(e.a.id); });
  let vis = nodes, ves = edges, alpha = 1, raf = 0, W = 0, H = 0, hover = null, drag = null, pan = null, moved = false;
  const T = { k: 1, x: 0, y: 0 };
  let dpr = window.devicePixelRatio || 1;
  const resize = () => { const r = wrap.getBoundingClientRect(); W = r.width; H = r.height; cv.width = W * dpr; cv.height = H * dpr; if (!T.init) { T.x = W / 2; T.y = H / 2; T.init = true; } alpha = Math.max(alpha, 0.3); };
  const refilter = () => { vis = nodes.filter((n) => graphFilter[n.type]); const s = new Set(vis); ves = edges.filter((e) => s.has(e.a) && s.has(e.b)); alpha = 1; };
  const rad = (n) => 3 + n.size * 0.55;
  function tick() {
    const N = vis.length;
    for (let i = 0; i < N; i++) {
      const a = vis[i];
      for (let j = i + 1; j < N; j++) {
        const b = vis[j]; let dx = a.x - b.x, dy = a.y - b.y, d2 = dx * dx + dy * dy;
        if (d2 > 90000) continue;
        if (d2 < 1) { dx = Math.random() - 0.5; dy = Math.random() - 0.5; d2 = 1; }
        const f = (1500 * alpha) / d2, d = Math.sqrt(d2);
        a.vx += (dx / d) * f; a.vy += (dy / d) * f; b.vx -= (dx / d) * f; b.vy -= (dy / d) * f;
      }
    }
    for (const e of ves) {
      const dx = e.b.x - e.a.x, dy = e.b.y - e.a.y, d = Math.sqrt(dx * dx + dy * dy) || 1, L = e.kind === "requires" ? 70 : 100;
      const f = (d - L) * 0.02 * alpha, fx = (dx / d) * f, fy = (dy / d) * f;
      e.a.vx += fx; e.a.vy += fy; e.b.vx -= fx; e.b.vy -= fy;
    }
    for (const n of vis) {
      n.vx -= n.x * 0.004 * alpha * 2; n.vy -= n.y * 0.004 * alpha * 2;
      if (n === drag) { n.vx = n.vy = 0; continue; }
      n.vx *= 0.82; n.vy *= 0.82; n.x += n.vx; n.y += n.vy;
    }
    alpha *= 0.985;
  }
  const hot = (n) => !hover || n === hover || (nbr[hover.id] && nbr[hover.id].has(n.id));
  function draw() {
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0); ctx.clearRect(0, 0, W, H);
    ctx.translate(T.x, T.y); ctx.scale(T.k, T.k);
    for (const e of ves) {
      const on = !hover || e.a === hover || e.b === hover;
      ctx.strokeStyle = on ? (hover ? "rgba(139,124,246,.85)" : e.kind === "requires" ? "rgba(56,214,232,.30)" : e.kind === "edited" ? "rgba(139,124,246,.38)" : "rgba(135,145,163,.16)") : "rgba(135,145,163,.05)";
      ctx.lineWidth = (on && hover ? 1.6 : e.kind === "edited" ? 1.2 : 0.8) / T.k;
      ctx.beginPath(); ctx.moveTo(e.a.x, e.a.y); ctx.lineTo(e.b.x, e.b.y); ctx.stroke();
    }
    for (const n of vis) {
      const r = rad(n), on = hot(n);
      ctx.globalAlpha = on ? 1 : 0.15;
      ctx.beginPath(); ctx.arc(n.x, n.y, r, 0, 7);
      ctx.fillStyle = GCOL[n.type]; if (on && (n === hover || n.type === "session")) { ctx.shadowColor = GCOL[n.type]; ctx.shadowBlur = n === hover ? 18 : 8; }
      ctx.fill(); ctx.shadowBlur = 0;
      if (n.type === "session" && (n.status === "stale" || n.status === "partly-stale")) { ctx.lineWidth = 2.2 / T.k; ctx.strokeStyle = n.status === "stale" ? "#f06a6a" : "#f5b942"; ctx.beginPath(); ctx.arc(n.x, n.y, r + 3, 0, 7); ctx.stroke(); }
      if (n === hover) { ctx.lineWidth = 2 / T.k; ctx.strokeStyle = "#fff"; ctx.beginPath(); ctx.arc(n.x, n.y, r + 1.5, 0, 7); ctx.stroke(); }
      if ((T.k > 0.8 && (n.type !== "file" || n.deg > 2)) || T.k > 1.5 || n === hover || (hover && on)) {
        ctx.fillStyle = on ? "#d7dce5" : "#555d6b"; ctx.font = `${11 / Math.max(T.k, 0.7)}px Inter, system-ui, sans-serif`; ctx.textAlign = "center";
        ctx.fillText(n.label, n.x, n.y + r + 12 / Math.max(T.k, 0.7));
      }
    }
    ctx.globalAlpha = 1;
  }
  function loop() { if (alpha > 0.02 || drag) tick(); draw(); raf = requestAnimationFrame(loop); }
  const toW = (ev) => { const r = cv.getBoundingClientRect(); return [(ev.clientX - r.left - T.x) / T.k, (ev.clientY - r.top - T.y) / T.k]; };
  const pick = (ev) => { const [x, y] = toW(ev); let best = null, bd = 1e9; for (const n of vis) { const d = Math.hypot(n.x - x, n.y - y); if (d < rad(n) + 4 / T.k && d < bd) { best = n; bd = d; } } return best; };
  const onDown = (ev) => { moved = false; const n = pick(ev); if (n) { drag = n; alpha = Math.max(alpha, 0.4); } else pan = { x: ev.clientX - T.x, y: ev.clientY - T.y }; cv.style.cursor = "grabbing"; };
  const onMove = (ev) => {
    if (drag) { [drag.x, drag.y] = toW(ev); moved = true; alpha = Math.max(alpha, 0.25); return; }
    if (pan) { T.x = ev.clientX - pan.x; T.y = ev.clientY - pan.y; moved = true; return; }
    const n = pick(ev); hover = n; cv.style.cursor = n ? "pointer" : "grab";
    if (n) { tip.classList.remove("hidden"); tip.textContent = `${n.type}: ${n.label}${n.type === "session" ? " (" + n.status + ")" : ""}`; const r = wrap.getBoundingClientRect(); tip.style.left = ev.clientX - r.left + 14 + "px"; tip.style.top = ev.clientY - r.top + 14 + "px"; } else tip.classList.add("hidden");
  };
  const onUp = () => {
    if (drag && !moved) openNode(drag);
    drag = null; pan = null; cv.style.cursor = hover ? "pointer" : "grab";
  };
  const openNode = (n) => { const [t, ...rest] = n.id.split(":"); const id = rest.join(":"); openTab(t === "file" ? "file" : t, t === "decision" || t === "convention" ? id : id); };
  const onWheel = (ev) => { ev.preventDefault(); const r = cv.getBoundingClientRect(), mx = ev.clientX - r.left, my = ev.clientY - r.top, k = Math.min(4, Math.max(0.2, T.k * Math.exp(-ev.deltaY * 0.0012))); T.x = mx - ((mx - T.x) / T.k) * k; T.y = my - ((my - T.y) / T.k) * k; T.k = k; };
  cv.addEventListener("mousedown", onDown); window.addEventListener("mousemove", onMove); window.addEventListener("mouseup", onUp); cv.addEventListener("wheel", onWheel, { passive: false });
  const ro = new ResizeObserver(resize); ro.observe(wrap); resize(); refilter(); loop();
  return {
    refilter,
    stop() { cancelAnimationFrame(raf); ro.disconnect(); window.removeEventListener("mousemove", onMove); window.removeEventListener("mouseup", onUp); },
  };
}

// ---------- markdown renderer + wikilinks ----------
const vflat = () => { const o = []; (function w(ns) { ns.forEach((n) => (n.type === "dir" ? w(n.children) : o.push(n))); })(S.vault ? S.vault.tree : []); return o; };
const baseNoExt = (p) => p.split("/").pop().replace(/\.(md|json|jsonl)$/i, "").replace(/\.meta$/, "");
function resolveLink(raw) {
  const n = String(raw).split("#")[0].trim();
  if (!n) return null;
  const lo = n.toLowerCase(), lne = lo.replace(/\.md$/, ""), vf = vflat();
  let m = vf.find((f) => f.path.toLowerCase() === lo || f.path.toLowerCase().replace(/\.md$/, "") === lne);
  if (m) return ["vault", m.path];
  if ((m = S.files.find((f) => f.path === n))) return ["file", m.path];
  const sm = n.match(/^S(\d+)$/i);
  const sess = (sm && S.sessions[+sm[1] - 1]) || S.sessions.find((s) => (n.length >= 6 && s.id.startsWith(n)) || (s.meta_file || "").replace(/\.meta\.json$/, "") === n);
  if (sess) return ["vault", "sessions/" + sess.meta_file];
  const dm = n.match(/^(?:d|decision\s*#?)(\d+)$/i);
  if (dm && S.decisions.find((d) => d.id === "d" + dm[1])) return ["decision", "d" + dm[1]];
  if ((m = vf.find((f) => f.name.toLowerCase() === lo || baseNoExt(f.path).toLowerCase() === lne))) return ["vault", m.path];
  const fm = S.files.filter((f) => f.path.split("/").pop().toLowerCase() === lo || f.path.split("/").pop().toLowerCase().replace(/\.[^.]+$/, "") === lne);
  if (fm.length === 1) return ["file", fm[0].path];
  return null;
}
function wikiHtml(name, label) {
  const r = resolveLink(name);
  return r ? `<a class="wl" data-open="${r[0]}" data-id="${esc(r[1])}" title="${esc(r[1])}">${esc(label)}</a>` : `<span class="wl dead" title="No matching note for [[${esc(name)}]]">${esc(label)}</span>`;
}
function mdInline(s) {
  const hold = [], keep = (h) => "\u0001" + (hold.push(h) - 1) + "\u0001";
  s = s.replace(/`([^`]+)`/g, (_, c) => keep(S.files.some((f) => f.path === c) ? `<code class="fl">${wikiHtml(c, c)}</code>` : `<code>${esc(c)}</code>`));
  s = s.replace(/\[\[([^\]\n]+?)\]\]/g, (_, inner) => { const [n, l] = inner.split("|"); return keep(wikiHtml(n.trim(), (l || n).trim())); });
  s = s.replace(/\[([^\]\n]+)\]\(([^)\s]+)\)/g, (_, t, u) => {
    if (/^https?:/i.test(u)) return keep(`<a href="${esc(u)}" target="_blank" rel="noopener">${esc(t)}</a>`);
    if (/^(javascript|data|vbscript):/i.test(u)) return keep(esc(t));
    return keep(wikiHtml(decodeURIComponent(u.replace(/^\.?\//, "")), t));
  });
  s = esc(s);
  s = s.replace(/\*\*([^*\n]+)\*\*|__([^_\n]+)__/g, (_, a, b) => `<strong>${a || b}</strong>`);
  s = s.replace(/(^|[^*\w])\*([^*\n]+)\*(?!\*)/g, "$1<em>$2</em>").replace(/(^|[^_\w])_([^_\n]+)_(?![_\w])/g, "$1<em>$2</em>");
  s = s.replace(/~~([^~\n]+)~~/g, "<del>$1</del>");
  s = s.replace(/(^|[\s(])(https?:\/\/[^\s<]*[^\s<.,;:!?)])/g, '$1<a href="$2" target="_blank" rel="noopener">$2</a>');
  return s.replace(/\u0001(\d+)\u0001/g, (_, i) => hold[+i]);
}
function mdList(items) {
  let h = "", st = [];
  for (const it of items) {
    const t = it.ord ? "ol" : "ul", task = it.text.match(/^\[([ xX])\]\s+(.*)$/);
    const body = task ? `<input type="checkbox" disabled ${task[1] !== " " ? "checked" : ""}> ${mdInline(task[2])}` : mdInline(it.text);
    const top = st[st.length - 1];
    if (!top || it.ind > top.ind) { h += `<${t}><li>${body}`; st.push({ ind: it.ind, t }); }
    else {
      while (st.length > 1 && it.ind < st[st.length - 1].ind) { h += `</li></${st.pop().t}>`; }
      h += `</li><li>${body}`;
    }
  }
  while (st.length) h += `</li></${st.pop().t}>`;
  return h;
}
function renderMd(src) {
  const L = String(src).replace(/\r\n/g, "\n").split("\n");
  let i = 0, out = "", fm = "";
  if (L[0] === "---") { const e = L.indexOf("---", 1); if (e > 0) { fm = propsBlock(L.slice(1, e).map((l) => { const k = l.indexOf(":"); return k > 0 ? [l.slice(0, k).trim(), esc(l.slice(k + 1).trim())] : [l, ""]; })); i = e + 1; } }
  const isBlock = (l) => /^(```|#{1,6}\s|>\s?|\s*([-*+]|\d+[.)])\s+)/.test(l) || /^\s*([-*_])(\s*\1){2,}\s*$/.test(l);
  const sep = /^\s*\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?\s*$/;
  while (i < L.length) {
    const l = L[i];
    if (!l.trim()) { i++; continue; }
    let m;
    if (/^```/.test(l)) {
      const lang = l.slice(3).trim(), buf = []; i++;
      while (i < L.length && !/^```/.test(L[i])) buf.push(L[i++]);
      i++;
      out += `<pre class="mcode"${lang ? ` data-lang="${esc(lang)}"` : ""}><code>${esc(buf.join("\n"))}</code></pre>`;
    } else if ((m = l.match(/^(#{1,6})\s+(.*?)\s*#*$/))) { out += `<h${m[1].length}>${mdInline(m[2])}</h${m[1].length}>`; i++; }
    else if (/^\s*([-*_])(\s*\1){2,}\s*$/.test(l)) { out += "<hr>"; i++; }
    else if (/^>\s?/.test(l)) { const buf = []; while (i < L.length && /^>\s?/.test(L[i])) buf.push(L[i++].replace(/^>\s?/, "")); out += `<blockquote>${renderMd(buf.join("\n"))}</blockquote>`; }
    else if (l.includes("|") && i + 1 < L.length && sep.test(L[i + 1]) && L[i + 1].includes("-")) {
      const cells = (r) => r.trim().replace(/^\|/, "").replace(/\|$/, "").split("|").map((c) => c.trim());
      const head = cells(l); i += 2; const rows = [];
      while (i < L.length && L[i].trim() && L[i].includes("|")) rows.push(cells(L[i++]));
      out += `<div class="tbl"><table><thead><tr>${head.map((c) => `<th>${mdInline(c)}</th>`).join("")}</tr></thead><tbody>${rows.map((r) => `<tr>${head.map((_, k) => `<td>${mdInline(r[k] || "")}</td>`).join("")}</tr>`).join("")}</tbody></table></div>`;
    } else if (/^\s*([-*+]|\d+[.)])\s+/.test(l)) {
      const items = [];
      while (i < L.length) {
        const mm = L[i].match(/^(\s*)([-*+]|\d+[.)])\s+(.*)$/);
        if (mm) { items.push({ ind: mm[1].replace(/\t/g, "    ").length, ord: /\d/.test(mm[2]), text: mm[3] }); i++; }
        else if (L[i].trim() && /^\s+\S/.test(L[i]) && items.length) { items[items.length - 1].text += " " + L[i].trim(); i++; }
        else break;
      }
      out += mdList(items);
    } else {
      const buf = [l]; i++;
      while (i < L.length && L[i].trim() && !isBlock(L[i]) && !(L[i].includes("|") && i + 1 < L.length && sep.test(L[i + 1]))) buf.push(L[i++]);
      out += `<p>${mdInline(buf.join("\n")).replace(/\n/g, " ")}</p>`;
    }
  }
  return fm + out;
}
function propsBlock(rows) {
  return `<div class="fm"><div class="fm-h">Properties</div><div class="fm-g">${rows.filter((r) => r && r[1] !== "" && r[1] != null).map(([k, v]) => `<span class="k">${esc(k)}</span><span class="v">${v}</span>`).join("")}</div></div>`;
}

// ---------- JSON tree ----------
function jt(v, key, depth) {
  const k = key != null ? `<span class="jk">${esc(key)}</span><span class="jp">: </span>` : "";
  if (v === null) return `<div class="jl">${k}<span class="jb">null</span></div>`;
  if (typeof v === "string") return `<div class="jl">${k}<span class="js">"${esc(v.length > 700 ? v.slice(0, 700) + `… (+${v.length - 700} chars)` : v)}"</span></div>`;
  if (typeof v === "number") return `<div class="jl">${k}<span class="jn">${v}</span></div>`;
  if (typeof v === "boolean") return `<div class="jl">${k}<span class="jb">${v}</span></div>`;
  const arr = Array.isArray(v), ent = arr ? v.map((x, i) => [i, x]) : Object.entries(v), [o, c] = arr ? ["[", "]"] : ["{", "}"];
  if (!ent.length) return `<div class="jl">${k}<span class="jp">${o}${c}</span></div>`;
  const shown = ent.slice(0, 300);
  return `<details class="jd" ${depth < 2 ? "open" : ""}><summary>${k}<span class="jp">${o}</span><span class="jc"> ${ent.length} ${arr ? "items" : "keys"}</span></summary><div class="jkids">${shown.map(([kk, x]) => jt(x, arr ? null : kk, depth + 1)).join("")}${ent.length > 300 ? `<div class="jl jc">… ${ent.length - 300} more</div>` : ""}</div><div class="jl jp">${c}</div></details>`;
}

// ---------- vault note viewer ----------
S.vmode = {};
function crumbs(path) {
  const parts = [S.vault.root, ...path.split("/")];
  return `<div class="crumbs">${parts.map((p, i) => `<span class="${i === parts.length - 1 ? "cur" : ""}">${esc(p)}</span>`).join('<i>›</i>')}</div>`;
}
function noteBar(path, d, modes) {
  const cur = S.vmode[path] || modes[0][0];
  return `<div class="notebar">${crumbs(path)}<div class="nb-actions">${modes.length > 1 ? `<div class="seg">${modes.map(([k, lab]) => `<button class="${k === cur ? "on" : ""}" data-act="mode" data-path="${esc(path)}" data-mode="${k}">${lab}</button>`).join("")}</div>` : ""}
    <button class="btn ghost sm" data-act="reveal" data-path="${esc(path)}" title="Show in Windows Explorer">Reveal in Explorer</button>
    <button class="btn ghost sm" data-act="copy" data-path="${esc(d.abs)}">Copy path</button></div></div>`;
}
const sessByMeta = (path) => { const f = path.replace(/^sessions\//, ""); return S.sessions.find((s) => s.meta_file === f); };
const sessByRaw = (path) => { const f = path.replace(/^sessions\//, ""); return S.sessions.find((s) => s.raw_record === f); };

async function vVault(v, path) {
  const d = await cget("/api/vault/file?path=" + encodeURIComponent(path));
  const kind = vkind(path), name = path.split("/").pop();
  const fileProps = [["Name", esc(name)], ["Size", human(d.size)], ["Type", kind === "md" ? "Markdown note" : kind === "jsonl" ? "stream-json record" : kind === "json" ? "JSON" : "text"]];
  let side = { linked: [], props: fileProps };
  if (kind === "md") {
    const links = new Map();
    for (const m of d.content.matchAll(/\[\[([^\]\n|]+?)(?:\|[^\]\n]*)?\]\]/g)) { const r = resolveLink(m[1].trim()); if (r) links.set(r.join(":"), r); }
    const mode = S.vmode[path] || "note";
    v.innerHTML = `<div class="page wide">${noteBar(path, d, [["note", "Rendered"], ["raw", "Source"]])}${mode === "raw" ? `<pre class="rawbox">${esc(d.content)}</pre>` : `<div class="mdbody">${renderMd(d.content)}</div>`}</div>`;
    side.linked = [...links.values()].map(([t, id]) => linkItem(t, id, t === "vault" ? id.split("/").pop() : t === "file" ? id.split("/").pop() : id, "links to"));
    side.props.push(["Wikilinks", links.size], ["Lines", d.content.split("\n").length]);
  } else if (kind === "json" && /\.meta\.json$/.test(name) && /^sessions\//.test(path)) {
    let m; try { m = JSON.parse(d.content); } catch (e) { m = null; }
    if (!m) { v.innerHTML = `<div class="page wide">${noteBar(path, d, [["raw", "Raw JSON"]])}<pre class="rawbox">${esc(d.content)}</pre></div>`; return side; }
    const s = sessByMeta(path), mode = S.vmode[path] || "note";
    const sv = s ? await cget("/api/session?id=" + encodeURIComponent(s.id)) : null;
    const note = mode === "raw" ? `<div class="jtree">${jt(m, null, 0)}</div>` : sessionNote(m, s, sv);
    v.innerHTML = `<div class="page wide">${noteBar(path, d, [["note", "Note"], ["raw", "Raw JSON"]])}${note}</div>`;
    const ed = m.files_edited || [], rd = (m.files_read || []).filter((x) => !ed.includes(x));
    const decs = s ? S.decisions.filter((x) => x.session === s.id) : [];
    side.linked = [...ed.map((x) => linkItem("file", x, x.split("/").pop(), "edited")), ...rd.map((x) => linkItem("file", x, x.split("/").pop(), "read")),
      ...decs.map((x) => linkItem("decision", x.id, short(x.text, 34), "decision")),
      ...(m.raw_record ? [linkItem("vault", "sessions/" + m.raw_record, m.raw_record, "raw record")] : []),
      ...(s ? [linkItem("session", s.id, `S${sidx[s.id]} session view`, "", s.freshness)] : [])];
    const u = m.usage || {};
    side.props = [["Session", `<code>${esc(String(m.session_id || "").slice(0, 8))}</code>`], ["Started", esc(m.started_at || "-")], ["Model", esc(m.model || "-")], ["Status", sv ? tag(sv.freshness.status) : "-"],
      ["Output tok", fmt(u.output_tokens)], ["Cost", "$" + (u.cost_usd_list || 0).toFixed(4)], ["Files edited", ed.length], ["Files read", rd.length], ["Size", human(d.size)]];
  } else if (kind === "json") {
    let j; try { j = JSON.parse(d.content); } catch (e) { j = undefined; }
    const mode = S.vmode[path] || (j === undefined ? "raw" : "tree");
    v.innerHTML = `<div class="page wide">${noteBar(path, d, j === undefined ? [["raw", "Raw"]] : [["tree", "Tree"], ["raw", "Raw"]])}${mode === "raw" ? `<pre class="rawbox">${esc(d.content)}</pre>` : `<div class="jtree">${jt(j, null, 0)}</div>`}</div>`;
    if (j && typeof j === "object") side.props.push([Array.isArray(j) ? "Items" : "Top-level keys", Object.keys(j).length]);
    if (j && j.files && path === "index/map.json") side.props.push(["Files indexed", Object.keys(j.files).length], ["Engine", esc(j.engine || "")]);
  } else if (kind === "jsonl") {
    const mode = S.vmode[path] || "timeline", s = sessByRaw(path);
    const sv = s ? await cget("/api/session?id=" + encodeURIComponent(s.id)) : null;
    v.innerHTML = `<div class="page wide">${noteBar(path, d, [["timeline", "Timeline"], ["raw", "Raw"]])}${mode === "raw" ? rawLines(d.content) : jsonlTimeline(d.content, sv ? sv.meta.prompt : "")}</div>`;
    side.linked = s ? [linkItem("vault", "sessions/" + s.meta_file, s.meta_file, "session note"), linkItem("session", s.id, `S${sidx[s.id]} session view`, "", s.freshness)] : [];
    side.props.push(["Events", d.content.split("\n").filter(Boolean).length]);
  } else {
    v.innerHTML = `<div class="page wide">${noteBar(path, d, [["raw", "Text"]])}<pre class="rawbox">${esc(d.content)}</pre></div>`;
  }
  return side;
}

function sessionNote(m, s, sv) {
  const u = m.usage || {}, idx = s ? sidx[s.id] : null, calls = m.tool_calls || [];
  const ed = m.files_edited || [], rd = (m.files_read || []).filter((x) => !ed.includes(x));
  const status = sv ? sv.freshness.status : null;
  const props = propsBlock([
    ["session_id", `<code>${esc(m.session_id || "")}</code>`], ["started", esc(m.started_at || "")], ["model", esc(m.model || "")], ["provider", esc(m.provider || "")],
    ["capture", esc(m.capture_method || "")], ["tokens", `${fmt(u.input_tokens)} in · ${fmt(u.output_tokens)} out · ${fmt(u.cache_read_tokens)} cache read · ${fmt(u.cache_creation_tokens)} cache write`],
    ["cost_usd_list", u.cost_usd_list != null ? "$" + u.cost_usd_list.toFixed(4) : ""], ["turns", u.num_turns != null ? `${u.num_turns} · ${((u.duration_ms || 0) / 1000).toFixed(1)}s` : ""],
    ["freshness", status ? tag(status) : ""], ["raw_record", m.raw_record ? wikiHtml("sessions/" + m.raw_record, m.raw_record) : ""],
    ["step", esc(m.race_step || m.script_id || "")]]);
  const fl = (arr, role) => arr.map((f) => `<li>${wikiHtml(f, f)} <span class="dim">${role}</span></li>`).join("");
  const edits = calls.filter((t) => t.tool === "Edit" || t.tool === "Write");
  const tl = calls.slice(0, 250).map((t) => {
    const tgt = t.file ? wikiHtml(t.file, t.file.split("/").pop()) : "";
    const extra = t.command ? `<code>${esc(short(t.command, 140))}</code>` : t.pattern ? `<code>${esc(short(t.pattern, 80))}</code>` : "";
    return `<li class="tli"><span class="tl-ico ${esc(t.tool)}">${TOOL_ICO[t.tool] || "▪"}</span><b>${esc(t.tool)}</b> ${tgt} ${extra}<span class="dim ln">L${t.line ?? ""}</span></li>`;
  }).join("") + (calls.length > 250 ? `<li class="dim">… ${calls.length - 250} more</li>` : "");
  return `<div class="mdbody"><h1 class="ntitle">${idx ? `Session S${idx}` : "Session"}</h1>${props}
   <h2>Prompt</h2><div class="quote">${esc(m.prompt || "(empty)")}</div>
   <h2>Outcome</h2>${m.result_text ? renderMd(m.result_text) : '<p class="dim">(no result text)</p>'}
   <h2>Files touched</h2>${ed.length || rd.length ? `<ul>${fl(ed, "edited")}${fl(rd, "read")}</ul>` : '<p class="dim">No files recorded.</p>'}
   <h2>Tool timeline</h2>${calls.length ? `<ul class="tlist">${tl}</ul>` : '<p class="dim">No tool calls recorded.</p>'}
   <h2>Edits</h2>${edits.length ? edits.slice(0, 60).map((t) => `<h3>${t.file ? wikiHtml(t.file, t.file) : esc(t.tool)} <span class="dim">${esc(t.tool)} · L${t.line ?? ""}</span></h3>${t.tool === "Edit" ? diffHtml(t.old, t.new) : diffHtml("", t.new)}`).join("") : '<p class="dim">No edits.</p>'}
   ${(m.errors || []).length ? `<h2>Errors</h2><ul>${m.errors.map((x) => `<li class="errli">${esc(short(typeof x === "string" ? x : x.error || JSON.stringify(x), 300))}</li>`).join("")}</ul>` : ""}</div>`;
}

function rawLines(text) {
  const ls = text.split("\n").filter(Boolean), cap = 600;
  return `<div class="codebox raw"><pre>${ls.slice(0, cap).map((l, i) => `<div class="ln"><span class="n">${i + 1}</span><span class="c" style="white-space:pre-wrap;word-break:break-all">${esc(l.length > 3000 ? l.slice(0, 3000) + `… (+${l.length - 3000} chars)` : l)}</span></div>`).join("")}</pre></div>${ls.length > cap ? `<p class="dim">Showing first ${cap} of ${ls.length} lines.</p>` : ""}`;
}
function keyInputs(inp) {
  const keys = ["file_path", "path", "command", "pattern", "description", "url", "prompt", "old_string", "new_string", "content"];
  const rows = [];
  for (const k of keys) if (inp && inp[k] != null) rows.push(`<span class="dim">${k}</span> ${k === "old_string" || k === "new_string" || k === "content" ? `<span class="dim">(${String(inp[k]).length} chars)</span>` : `<code>${esc(short(inp[k], 220))}</code>`}`);
  return rows.slice(0, 5).join('<span class="sepdot">·</span>');
}
function resultBlock(c) {
  const t = Array.isArray(c) ? c.map((x) => x.text || JSON.stringify(x)).join("\n") : typeof c === "string" ? c : JSON.stringify(c, null, 1);
  const head = t.slice(0, 420);
  return `<pre class="tres">${esc(head)}${t.length > 420 ? "…" : ""}</pre>${t.length > 420 ? `<details class="more"><summary>Show all (${fmt(t.length)} chars)</summary><pre class="tres">${esc(t.length > 30000 ? t.slice(0, 30000) + "\n… truncated" : t)}</pre></details>` : ""}`;
}
function jsonlTimeline(text, prompt) {
  const ls = text.split("\n").filter(Boolean), names = {};
  let hidden = 0, h = "", n = 0;
  const ev = (cls, ico, head, body) => { n++; h += `<div class="tl ${cls}"><span class="ico">${ico}</span><div class="head">${head}</div>${body || ""}</div>`; };
  if (prompt) ev("user", "U", '<span class="tool">User prompt</span><span class="dim">from session note</span>', `<div class="quote">${esc(prompt)}</div>`);
  ls.forEach((line, li) => {
    let e; try { e = JSON.parse(line); } catch (x) { hidden++; return; }
    const L = `<span class="dim mono" style="margin-left:auto">L${li + 1}</span>`;
    if (e.type === "system" && e.subtype === "init") ev("sys", "⚙", `<span class="tool">System init</span><span class="muted">${esc(e.model || "")}</span><span class="dim">${(e.tools || []).length} tools · ${esc(e.permissionMode || "")}</span>${L}`, `<div class="cmd">${esc(e.cwd || "")}</div>`);
    else if (e.type === "system" && e.subtype && e.subtype !== "thinking_tokens") ev("warn", "!", `<span class="tool">${esc(e.subtype.replace(/_/g, " "))}</span>${L}`, `<div class="cmd">${esc(short(JSON.stringify(Object.fromEntries(Object.entries(e).filter(([k]) => !["type", "subtype", "uuid", "session_id"].includes(k)))), 360))}</div>`);
    else if (e.type === "assistant" && e.message) {
      for (const b of e.message.content || []) {
        if (b.type === "text" && b.text) ev("assistant", "●", `<span class="tool">Assistant</span><span class="dim">visible text</span>${L}`, `<div class="atext mdbody">${renderMd(b.text)}</div>`);
        else if (b.type === "tool_use") { names[b.id] = b.name; ev(b.name, TOOL_ICO[b.name] || "▪", `<span class="tool">${esc(b.name)}</span>${L}`, `<div class="kin">${keyInputs(b.input)}</div>`); }
        else if (b.type === "thinking") { if (b.thinking) ev("think", "…", `<span class="tool">Thinking</span><span class="dim">provider-emitted summary</span>${L}`, `<details class="more"><summary>Show</summary><pre class="tres">${esc(b.thinking)}</pre></details>`); else hidden++; }
      }
    } else if (e.type === "user" && e.message) {
      const c = e.message.content;
      if (typeof c === "string") ev("user", "U", `<span class="tool">User</span>${L}`, `<div class="quote">${esc(c)}</div>`);
      else for (const b of c || []) {
        if (b.type === "tool_result") ev("res" + (b.is_error ? " err" : ""), "↵", `<span class="tool">Result</span><span class="muted">${esc(names[b.tool_use_id] || "")}</span>${b.is_error ? '<span class="tag stale">error</span>' : ""}${L}`, resultBlock(b.content));
        else if (b.type === "text") ev("user", "U", `<span class="tool">User</span>${L}`, `<div class="quote">${esc(b.text)}</div>`);
      }
    } else if (e.type === "result") {
      const u = e.usage || {};
      ev("done", "✓", `<span class="tool">Result</span><span class="tag ${e.is_error ? "stale" : "fresh"}">${esc(e.subtype || "")}</span>${L}`,
        `<div class="cards sm"><div class="card"><div class="lbl">Cost</div><div class="val g">$${(e.total_cost_usd || 0).toFixed(4)}</div></div><div class="card"><div class="lbl">Output</div><div class="val v">${fmt(u.output_tokens)}</div></div><div class="card"><div class="lbl">Input</div><div class="val">${fmt(u.input_tokens)}</div></div><div class="card"><div class="lbl">Cache read</div><div class="val c">${fmt(u.cache_read_input_tokens)}</div></div><div class="card"><div class="lbl">Turns</div><div class="val">${fmt(e.num_turns)}</div><div class="note">${((e.duration_ms || 0) / 1000).toFixed(1)}s</div></div></div>${e.result ? `<div class="atext mdbody" style="margin-top:8px">${renderMd(e.result)}</div>` : ""}`);
    }
    // tool-agnostic records (devmem/generic.py): any AI tool, captured by snapshot diff
    else if (e.type === "prompt") ev("user", "U", `<span class="tool">User prompt</span>${L}`, `<div class="quote">${esc(e.text || "")}</div>`);
    else if (e.type === "command") ev("Bash", "$", `<span class="tool">Launched</span>${L}`, `<div class="cmd">${esc((e.argv || []).join(" "))}</div>`);
    else if (e.type === "output") ev("res", "↵", `<span class="tool">Tool output</span><span class="dim">stdout/stderr</span>${L}`, resultBlock(e.text || ""));
    else if (e.type === "final_message") ev("assistant", "●", `<span class="tool">Final message</span><span class="dim">${esc(e.source || "")}</span>${L}`, `<div class="atext mdbody">${renderMd(e.text || "")}</div>`);
    else if (e.type === "file_changes") ev("Edit", "✎", `<span class="tool">Observed file changes</span><span class="muted">${(e.files || []).length} files</span><span class="dim">snapshot diff</span>${L}`, e.unified_diff ? resultBlock(e.unified_diff) : '<div class="dim">no changes</div>');
    else if (e.type === "tool_event" && e.event) {
      const x = e.event, it = x.item || {};
      if (it.type === "agent_message" && it.text) ev("assistant", "●", `<span class="tool">Assistant</span><span class="dim">visible text</span>${L}`, `<div class="atext mdbody">${renderMd(it.text)}</div>`);
      else if (it.type === "command_execution" && x.type === "item.completed") ev("Bash", "$", `<span class="tool">Command</span>${it.exit_code ? '<span class="tag stale">exit ' + esc(String(it.exit_code)) + "</span>" : ""}${L}`, `<div class="cmd">${esc(it.command || "")}</div>${it.aggregated_output ? resultBlock(it.aggregated_output) : ""}`);
      else if (it.type === "file_change" && x.type === "item.completed") ev("Edit", "✎", `<span class="tool">File change</span>${L}`, `<div class="kin">${esc((it.changes || []).map((c) => (c.kind || "") + " " + (c.path || "")).join(", "))}</div>`);
      else if (it.type === "error" || x.type === "error" || x.type === "turn.failed") ev("warn", "!", `<span class="tool">Error</span>${L}`, `<div class="cmd">${esc(it.message || x.message || (x.error && x.error.message) || "")}</div>`);
      else if (x.type === "turn.completed" && x.usage) ev("done", "✓", `<span class="tool">Turn completed</span>${L}`, `<div class="cards sm"><div class="card"><div class="lbl">Input</div><div class="val">${fmt(x.usage.input_tokens)}</div></div><div class="card"><div class="lbl">Cached input</div><div class="val c">${fmt(x.usage.cached_input_tokens)}</div></div><div class="card"><div class="lbl">Output</div><div class="val v">${fmt(x.usage.output_tokens)}</div></div></div>`);
      else hidden++;
    } else hidden++;
  });
  return `<div class="timeline evs">${h || '<span class="muted">No events.</span>'}</div><p class="dim" style="margin-top:14px">${n} events shown${hidden ? `, ${hidden} housekeeping records hidden (rate limits, thinking-token counters, empty thinking blocks)` : ""}. Reasoning content is shown only when the provider exposed it.</p>`;
}

// ---------- actions, home, dialogs ----------
function copyText(t) {
  return navigator.clipboard ? navigator.clipboard.writeText(t) : Promise.reject();
}
document.addEventListener("click", async (e) => {
  const a = e.target.closest("[data-act]");
  if (!a) return;
  const act = a.dataset.act;
  if (act === "mode") { S.vmode[a.dataset.path] = a.dataset.mode; render(); }
  else if (act === "reveal") {
    try { await post("/api/reveal?path=" + encodeURIComponent(a.dataset.path)); toast("Opened in Explorer", "ok"); } catch (x) { toast("Reveal failed: " + x.message); }
  } else if (act === "copy") {
    const t = a.dataset.path;
    try { await copyText(t); } catch { const ta = document.createElement("textarea"); ta.value = t; document.body.appendChild(ta); ta.select(); document.execCommand("copy"); ta.remove(); }
    toast("Path copied", "ok");
  } else if (act === "switch") showHome();
});
$(".brand").addEventListener("click", () => showHome());

function ask(title, body, ok = "OK", cancel = "Cancel") {
  return new Promise((res) => {
    const d = $("#dlg");
    d.innerHTML = `<div class="dlg-box"><h3>${esc(title)}</h3><p>${body}</p><div class="dlg-b"><button class="btn ghost" id="dlg-no">${esc(cancel)}</button><button class="btn" id="dlg-ok">${esc(ok)}</button></div></div>`;
    d.classList.remove("hidden");
    const done = (v) => { d.classList.add("hidden"); res(v); };
    $("#dlg-ok").onclick = () => done(true); $("#dlg-no").onclick = () => done(false); $("#dlg-ok").focus();
  });
}
const ago = (iso) => {
  const s = (Date.now() - Date.parse(iso)) / 1000;
  if (!(s >= 0)) return "";
  return s < 90 ? "just now" : s < 5400 ? Math.round(s / 60) + " min ago" : s < 129600 ? Math.round(s / 3600) + " h ago" : Math.round(s / 86400) + " days ago";
};
async function openProject(project, store) {
  const h = $("#home");
  h.classList.add("busy");
  try {
    let q = `/api/open?project=${encodeURIComponent(project)}${store ? "&store=" + encodeURIComponent(store) : ""}`;
    let r = await post(q);
    if (r.needs_scan) {
      if (!(await ask("No memory store yet", `No memory store found for <code>${esc(r.project)}</code>.<br>Scan the project now to build one? This is deterministic and uses 0 LLM tokens.`, "Scan project"))) return;
      r = await post(q + "&scan=1");
    }
    S.loaded = false; packState.res = null;
    await loadProject();
    $("#home").classList.add("hidden");
    renderVault(); renderTabs(); openTab("overview", "");
    if (r.scanned) toast("Project scanned and store created", "ok");
  } catch (e) { toast("Cannot open project: " + e.message); }
  finally { h.classList.remove("busy"); }
}
async function pickProject() {
  const r = await post("/api/pick?kind=project");
  if (r.path) openProject(r.path, "");
}
async function pickStore() {
  const r = await post("/api/pick?kind=store");
  if (!r.path) return;
  const norm = r.path.replace(/\\/g, "/").replace(/\/$/, "");
  if (norm.split("/").pop() === ".devmemory") return openProject(norm.split("/").slice(0, -1).join("/"), r.path);
  if (!(await ask("Which project?", `Store <code>${esc(r.path)}</code> is not inside its project. Pick the project folder it belongs to.`, "Choose project folder"))) return;
  const p = await post("/api/pick?kind=project");
  if (p.path) openProject(p.path, r.path);
}
async function showHome() {
  const h = $("#home");
  h.classList.remove("hidden");
  if (!h.firstChild) h.innerHTML = spinner();
  document.title = "DevMemory";
  let d;
  try { d = await api("/api/home"); } catch (e) { toast(e.message); return; }
  const card = (r, ex) => `<div class="hcard ${ex ? "ex" : ""}" data-proj="${esc(r.project)}" data-store="${esc(r.store)}" tabindex="0"><div class="hc-t">${esc(r.name)}</div><div class="hc-d">${esc(r.desc || r.project)}</div>${ex ? `<div class="hc-p mono">${esc(r.project)}</div>` : `<div class="hc-p mono">${esc(r.store)}</div><div class="hc-a">${esc(ago(r.last_opened))}</div>`}</div>`;
  const cur = d.current.project;
  h.innerHTML = `<div class="home-in"><div class="home-hero"><span class="logo big"></span><h1>DevMemory</h1><p>Local-first, project-aware memory for AI-assisted development.<br>Browse what was captured, exactly as it sits on disk.</p>
    <div class="home-btns"><button class="btn lg" id="h-proj">Open project folder…</button><button class="btn ghost lg" id="h-store">Open memory store…</button></div>
    ${cur ? `<button class="linkbtn" id="h-back">← Back to ${esc(d.current.name)}</button>` : ""}</div>
    <div class="home-cols"><div><h2>Recent projects</h2>${d.recents.length ? `<div class="hlist">${d.recents.map((r) => card({ ...r, desc: r.project }, false)).join("")}</div>` : '<div class="hempty">Nothing opened yet. Open a project folder or try an example.</div>'}</div>
    <div><h2>Examples</h2><div class="hlist">${d.examples.filter((x) => x.exists).map((x) => card(x, true)).join("") || '<div class="hempty">Examples not found on disk.</div>'}</div></div></div></div>`;
  $("#h-proj").onclick = pickProject; $("#h-store").onclick = pickStore;
  if ($("#h-back")) $("#h-back").onclick = () => { h.classList.add("hidden"); document.title = "DevMemory — " + S.ov.dir_name; };
}
$("#home").addEventListener("click", (e) => { const c = e.target.closest("[data-proj]"); if (c) openProject(c.dataset.proj, c.dataset.store); });
$("#home").addEventListener("keydown", (e) => { const c = e.target.closest("[data-proj]"); if (c && e.key === "Enter") openProject(c.dataset.proj, c.dataset.store); });

// ---------- quick switcher ----------
const qs = { open: false, sel: 0, res: [] };
function fuzzy(q, s) {
  q = q.toLowerCase(); s = s.toLowerCase();
  if (!q) return 1;
  let i = 0, score = 0, last = -2;
  for (let j = 0; j < s.length && i < q.length; j++) if (s[j] === q[i]) { score += j === last + 1 ? 3 : 1; if (j === 0 || "/._- ".includes(s[j - 1])) score += 2; last = j; i++; }
  return i === q.length ? score - s.length * 0.01 : 0;
}
function qsItems() {
  return [
    ...vflat().filter((f) => !/^sessions\//.test(f.path) || /\.meta\.json$/.test(f.path)).map((f) => ({ type: "vault", id: f.path, label: f.path })),
    ...S.files.map((f) => ({ type: "file", id: f.path, label: f.path })),
    ...S.sessions.map((s) => ({ type: "session", id: s.id, label: `S${sidx[s.id]} ${short(s.prompt, 80)}` })),
    ...S.decisions.map((d) => ({ type: "decision", id: d.id, label: short(d.text, 90) })),
    ...S.ov.conventions.map((c, i) => ({ type: "convention", id: "c" + (i + 1), label: short(c.replace(/`/g, ""), 90) })),
    { type: "graph", id: "", label: "Graph view" }, { type: "pack", id: "", label: "Pack Lab" }, { type: "overview", id: "", label: "Overview" },
  ];
}
function qsRender() {
  const q = $("#qs-input").value.trim();
  qs.res = qsItems().map((it) => ({ it, sc: fuzzy(q, it.label) })).filter((x) => x.sc > 0).sort((a, b) => b.sc - a.sc).slice(0, 40).map((x) => x.it);
  qs.sel = Math.min(qs.sel, Math.max(0, qs.res.length - 1));
  $("#qs-list").innerHTML = qs.res.map((r, i) => `<div class="item ${i === qs.sel ? "sel" : ""}" data-i="${i}"><span class="typ">${r.type}</span><span class="t">${esc(r.label)}</span></div>`).join("") || '<div class="empty" style="padding:12px">No matches</div>';
  const s = $("#qs-list .sel"); if (s) s.scrollIntoView({ block: "nearest" });
}
function qsToggle(on) {
  qs.open = on; $("#qs").classList.toggle("hidden", !on);
  if (on) { $("#qs-input").value = ""; qs.sel = 0; qsRender(); $("#qs-input").focus(); }
}
function qsGo(i) { const r = qs.res[i]; if (!r) return; qsToggle(false); openTab(r.type, r.id); }
$("#qs-input").addEventListener("input", () => { qs.sel = 0; qsRender(); });
$("#qs-list").addEventListener("click", (e) => { const it = e.target.closest("[data-i]"); if (it) qsGo(+it.dataset.i); });
$("#qs").addEventListener("mousedown", (e) => { if (e.target.id === "qs") qsToggle(false); });
$("#qs-btn").onclick = () => qsToggle(true);

document.addEventListener("keydown", (e) => {
  if (e.key === "Escape" && !$("#dlg").classList.contains("hidden")) { $("#dlg-no") && $("#dlg-no").click(); return; }
  if (e.key === "Escape" && S.loaded && !qs.open && !$("#home").classList.contains("hidden")) { $("#h-back") && $("#h-back").click(); return; }
  if (!$("#home").classList.contains("hidden")) return;
  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "k") { e.preventDefault(); return qsToggle(!qs.open); }
  if (qs.open) {
    if (e.key === "Escape") qsToggle(false);
    else if (e.key === "ArrowDown") { e.preventDefault(); qs.sel = Math.min(qs.res.length - 1, qs.sel + 1); qsRender(); }
    else if (e.key === "ArrowUp") { e.preventDefault(); qs.sel = Math.max(0, qs.sel - 1); qsRender(); }
    else if (e.key === "Enter") { e.preventDefault(); qsGo(qs.sel); }
    return;
  }
  const tg = e.target.tagName;
  if (tg === "INPUT" || tg === "TEXTAREA" || tg === "SELECT" || e.ctrlKey || e.metaKey || e.altKey) return;
  if (e.key.toLowerCase() === "g") openTab("graph", "");
  else if (e.key === "w" && S.active) closeTab(S.active);
});

boot();
