const pptxgen = require("pptxgenjs");
const path = require("path");
const { applyTheme } = require("C:/Users/thfal/.claude/skills/synced/76ba2e4a-4578-4861-bb39-ae2304303203_dbc3bf46-0ad5-4914-8c53-412479c87385/pptx/scripts/apply_theme.js");

// ---------- everything that might change lives here ----------
const DATA = {
  round2: "Round 2: all 8/8, no fixes. DevMemory cheapest: $0.74, 580k tok (vs 633k / 847k)",
  title: "DevMemory",
  subtitle: "Memory that lets every new AI coding session start warm",
  event: "HUMAIN–Misk Future AI Builders Hackathon · Challenge 2: Deliver AI with Less Compute",
  stats: [
    { big: "3.1M", label: "input tokens", sub: "no-memory agent building one small game over 16 sessions" },
    { big: "9", label: "prompts in a row", sub: "stuck on one bug (no-memory agent)" },
    { big: "1 of 3", label: "builds unplayable", sub: "passed static checks, crashed in Roblox Studio" },
  ],
  tagline: "Preserve everything, send only what earns its tokens.",
  pack: [
    "## Relevant past sessions",
    "- [session 68c540e0] **STALE**: edits no longer present in EnemyService.luau — verify current code",
    '  - User asked: "Raise Grunt damage from 10 to 12. Brute damage stays at 25."',
    "## Relevant files",
    "- src/shared/Config.luau — L40: Brute = { health = 200, speed = 8, damage = 25 }",
  ].join("\n"),
  passRate: { labels: ["C0 bare", "C1 CLAUDE.md", "C2 map only", "C3 DevMemory", "Sonnet bare"], values: [67, 72, 64, 86, 75] },
  cost: { labels: ["C0 bare", "C1 CLAUDE.md", "C2 map only", "C3 DevMemory"], values: [0.0099, 0.0104, 0.0094, 0.0087] },
  sonnetCost: "$0.092", sonnetMult: "11×",
  floor: 80,
  tokens: { labels: ["No memory", "AGENTS.md", "DevMemory"], values: [3.08, 3.41, 1.85] },
  buildStats: [
    { k: "Cost", v: ["$3.41", "$2.88", "$2.48"] },
    { k: "Features (of 10)", v: ["7", "9", "9"] },
  ],
  scripted: { dm: "0.61M", others: "1.06M / 1.20M" },
  footer: "Repo: DevMemory (source, benchmark, results) · RESULTS.md · bench/METHODOLOGY.md",
};

const THEME = {
  name: "DevMemory Dark", headFontFace: "Calibri", bodyFontFace: "Calibri",
  colors: { dk1: "0F1115", lt1: "EDEDED", dk2: "161A22", lt2: "9AA0AA", accent1: "8B7CF6", accent2: "38D6E8", accent3: "3DD68C", accent4: "F5A524", accent5: "5A606B", accent6: "E5484D", hlink: "38D6E8", folHlink: "8B7CF6" },
};
const BG = "0F1115", PANEL = "161A22", VIO = "8B7CF6", CY = "38D6E8", GRN = "3DD68C", WARN = "F5A524", TXT = "EDEDED", MUT = "9AA0AA", GRY = "5A606B", RED = "E5484D";

const ROOT = "C:/Users/thfal/documents/Personal_Projects/MiskXHumain_Hackathon/";
const IMG = {
  overview: [ROOT + "docs/app-screens/overview.png", 1440, 900],
  session: [ROOT + "docs/app-screens/session_note.png", 1440, 900],
  home: [ROOT + "docs/app-screens/home.png", 1440, 900],
  race: [ROOT + "results/series/blade/screens/race_devmemory_P15.jpg", 1641, 576],
  ref: [ROOT + "results/series/blade/screens/reference_bladeswarm_playtest.jpg", 1641, 576],
  agents: [ROOT + "results/series/blade/screens/agentsmd_r1_playtest.jpg", 1641, 576],
};

const pres = new pptxgen();
pres.layout = "LAYOUT_16x9"; // 10 x 5.625
pres.title = "DevMemory — Challenge 2";
pres.theme = { headFontFace: THEME.headFontFace, bodyFontFace: THEME.bodyFontFace };

pres.defineSlideMaster({
  title: "CONTENT", background: { color: BG },
  objects: [],
  slideNumber: { x: 9.2, y: 5.28, w: 0.5, h: 0.25, fontFace: "Calibri", fontSize: 10, color: MUT, align: "right" },
});

// fit image inside box preserving aspect, return placement
function fit(key, x, y, w, h, opts = {}) {
  const [p, iw, ih] = IMG[key];
  const r = iw / ih;
  let W = w, H = w / r;
  if (H > h) { H = h; W = h * r; }
  return { path: p, x: x + (w - W) / 2, y: y + (h - H) / 2, w: W, h: H, ...opts };
}
function shot(s, key, x, y, w, h, name) {
  const f = fit(key, x, y, w, h);
  s.addShape(pres.ShapeType.roundRect, { x: f.x - 0.05, y: f.y - 0.05, w: f.w + 0.1, h: f.h + 0.1, rectRadius: 0.08, fill: { color: PANEL }, line: { color: GRY, width: 0.75 }, objectName: name + " frame" });
  s.addImage({ ...f, objectName: name, altText: name });
}
function title(s, t, sub) {
  s.addText(t, { x: 0.5, y: 0.3, w: 9, h: 0.65, fontFace: "Calibri", bold: true, fontSize: 32, color: TXT, margin: 0, valign: "middle", isTextBox: true, objectName: "Title" });
  if (sub) s.addText(sub, { x: 0.5, y: 0.95, w: 9, h: 0.35, fontFace: "Calibri", fontSize: 15, color: MUT, margin: 0, isTextBox: true, objectName: "Subtitle" });
}
function panel(s, x, y, w, h, name, fill = PANEL) {
  s.addShape(pres.ShapeType.roundRect, { x, y, w, h, rectRadius: 0.1, fill: { color: fill }, line: { color: "232834", width: 0.75 }, objectName: name });
}
function T(s, text, o) { s.addText(text, { fontFace: "Calibri", color: TXT, margin: 0, isTextBox: true, ...o }); }
function bullets(items, size = 15, color = TXT) {
  return items.map((t, i) => {
    if (Array.isArray(t)) return { text: t[1], options: { bullet: true, breakLine: i < items.length - 1, paraSpaceAfter: 8, color, fontSize: size, bold: false }, _lead: t[0] };
    return { text: t, options: { bullet: true, breakLine: i < items.length - 1, paraSpaceAfter: 8, color, fontSize: size } };
  });
}
function richBullets(items, size = 15) {
  const runs = [];
  items.forEach((it, i) => {
    const last = i === items.length - 1;
    runs.push({ text: it[0] + " ", options: { bullet: true, bold: true, color: CY, fontSize: size, paraSpaceAfter: 8 } });
    runs.push({ text: it[1], options: { color: TXT, fontSize: size, breakLine: !last } });
  });
  return runs;
}

function barChart(s, x, y, w, h, ttl, labels, values, hiIdx, fmt, max, extra = {}) {
  s.addChart(pres.charts.BAR, [{ name: ttl, labels, values }], {
    x, y, w, h, barDir: "col", barGapWidthPct: 45,
    chartColors: values.map((_, i) => (hiIdx.includes(i) ? VIO : GRY)),
    showTitle: true, title: ttl, titleColor: TXT, titleFontSize: 14, titleFontFace: "Calibri",
    showValue: true, dataLabelPosition: "outEnd", dataLabelColor: TXT, dataLabelFontSize: 12, dataLabelFontFace: "Calibri", dataLabelFormatCode: fmt,
    catAxisLabelColor: MUT, catAxisLabelFontSize: 11, catAxisLabelFontFace: "Calibri",
    valAxisHidden: true, valAxisLabelColor: MUT, valAxisMinVal: 0, valAxisMaxVal: max,
    valGridLine: { style: "none" }, catGridLine: { style: "none" }, showLegend: false,
    objectName: ttl, ...extra,
  });
}

// ============ 1 Title ============
{
  const s = pres.addSlide({ masterName: "CONTENT" });
  T(s, DATA.title, { x: 0.6, y: 1.0, w: 4.4, h: 0.9, fontSize: 54, bold: true, color: TXT, valign: "middle", objectName: "Title" });
  T(s, DATA.subtitle, { x: 0.6, y: 2.0, w: 4.1, h: 1.1, fontSize: 22, color: VIO, bold: true, valign: "top", objectName: "Subtitle" });
  T(s, DATA.event, { x: 0.6, y: 3.9, w: 4.1, h: 0.8, fontSize: 13, color: MUT, valign: "top", objectName: "Event" });
  shot(s, "overview", 5.0, 0.9, 4.6, 3.6, "DevMemory app overview");
  s.addNotes("DevMemory gives every new AI coding session a warm start by remembering the project and what the user asked for earlier. The screenshot is the desktop app that browses the captured memory. We target Challenge 2: less compute at equal or better task success.");
}

// ============ 2 Problem ============
{
  const s = pres.addSlide({ masterName: "CONTENT" });
  title(s, "Every AI coding session starts cold", "It re-reads the project, forgets earlier decisions, and repeats fixed bugs");
  const cols = [VIO, CY, WARN];
  DATA.stats.forEach((st, i) => {
    const x = 0.5 + i * 3.05;
    panel(s, x, 1.65, 2.85, 3.1, "Stat card " + (i + 1));
    T(s, st.big, { x: x + 0.2, y: 1.85, w: 2.45, h: 1.0, fontSize: 54, bold: true, color: cols[i], valign: "middle", objectName: "Stat " + (i + 1) });
    T(s, st.label, { x: x + 0.2, y: 2.9, w: 2.45, h: 0.4, fontSize: 18, bold: true, color: TXT, objectName: "Stat label " + (i + 1) });
    T(s, st.sub, { x: x + 0.2, y: 3.4, w: 2.45, h: 1.0, fontSize: 14, color: MUT, valign: "top", objectName: "Stat sub " + (i + 1) });
  });
  T(s, "Measured in our own runs (details on slides 6–9).", { x: 0.5, y: 4.95, w: 6, h: 0.3, fontSize: 11, color: MUT, objectName: "Source" });
  s.addNotes("Without memory, each fresh session re-explores the project and loses what was decided before. In our runs a no-memory agent used 3.1M input tokens to build one small game, spent nine prompts on a single bug, and one of three builds passed static checks but crashed in Roblox Studio.");
}

// ============ 3 Solution ============
{
  const s = pres.addSlide({ masterName: "CONTENT" });
  title(s, "Scan, capture, pack, deliver");
  const steps = [
    ["1", "Scan", "Deterministic project map. 0 LLM tokens, ~25 ms.", VIO],
    ["2", "Capture", "Every session via Claude Code's documented stream-json / hooks: prompts, tool calls, edits, file hashes.", CY],
    ["3", "Pack", "Task-specific context: original requirements verbatim, the session where a feature was first asked for, files with evidence lines, STALE flags.", GRN],
    ["4", "Deliver", "Claude Code hook or --append-system-prompt. About 1k tokens.", WARN],
  ];
  steps.forEach((st, i) => {
    const x = 0.5 + i * 2.3;
    panel(s, x, 1.2, 2.1, 3.25, "Step card " + st[0]);
    s.addShape(pres.ShapeType.ellipse, { x: x + 0.2, y: 1.5, w: 0.6, h: 0.6, fill: { color: st[3] }, line: { color: st[3] }, objectName: "Step circle " + st[0] });
    T(s, st[0], { x: x + 0.2, y: 1.5, w: 0.6, h: 0.6, fontSize: 22, bold: true, color: BG, align: "center", valign: "middle", objectName: "Step num " + st[0] });
    T(s, st[1], { x: x + 0.2, y: 2.25, w: 1.7, h: 0.4, fontSize: 20, bold: true, objectName: "Step name " + st[0] });
    T(s, st[2], { x: x + 0.2, y: 2.7, w: 1.75, h: 1.5, fontSize: 13, color: MUT, valign: "top", objectName: "Step text " + st[0] });
    if (i < 3) T(s, "›", { x: x + 2.08, y: 2.5, w: 0.24, h: 0.5, fontSize: 24, color: MUT, align: "center", valign: "middle", objectName: "Arrow " + (i + 1) });
  });
  T(s, DATA.tagline, { x: 0.5, y: 4.6, w: 9, h: 0.6, fontSize: 24, bold: true, italic: true, color: VIO, align: "center", valign: "middle", objectName: "Tagline" });
  s.addNotes("The pipeline is four steps. A deterministic scan builds a project map with no model calls, capture records each session from documented Claude Code interfaces, a pack selects only what the next task needs, and delivery injects roughly 1k tokens. The principle is to keep the full archive but send only what earns its tokens.");
}

// ============ 4 Pack ============
{
  const s = pres.addSlide({ masterName: "CONTENT" });
  title(s, "What a context pack looks like", "Real excerpt from a Roblox benchmark project");
  panel(s, 0.5, 1.45, 5.5, 3.4, "Code panel", "0B0D12");
  const lines = DATA.pack.split("\n").map((l, i, a) => {
    const hdr = l.startsWith("##");
    const stale = l.includes("STALE");
    const user = l.trim().startsWith("- ") && l.startsWith("  ");
    return { text: l, options: { fontFace: "Courier New", fontSize: 11, color: hdr ? CY : stale ? WARN : user ? GRN : TXT, bold: hdr, breakLine: i < a.length - 1, paraSpaceAfter: 6 } };
  });
  s.addText(lines, { x: 0.7, y: 1.6, w: 5.1, h: 3.1, margin: 0, valign: "top", isTextBox: true, objectName: "Pack excerpt" });
  const pts = [["Deterministic & local.", "Plain files, no vector DB, no LLM in the loop."], ["Line-level freshness.", "Memory is checked against the current code."], ["Verbatim requirements.", "The user's words are never paraphrased."]];
  pts.forEach((p, i) => {
    const y = 1.45 + i * 1.18;
    panel(s, 6.25, y, 3.25, 1.05, "Point card " + (i + 1));
    T(s, p[0], { x: 6.45, y: y + 0.12, w: 2.9, h: 0.35, fontSize: 16, bold: true, color: i === 0 ? VIO : i === 1 ? CY : GRN, objectName: "Point " + (i + 1) });
    T(s, p[1], { x: 6.45, y: y + 0.5, w: 2.9, h: 0.5, fontSize: 13, color: MUT, valign: "top", objectName: "Point text " + (i + 1) });
  });
  s.addNotes("This is a real pack excerpt. The first entry is flagged STALE because the edits from that earlier session are no longer in the file, so the agent knows to verify. The user's original sentence is carried verbatim, and everything is plain files with no vector database or model in the retrieval loop.");
}

// ============ 5 What we built ============
{
  const s = pres.addSlide({ masterName: "CONTENT" });
  title(s, "What we built");
  shot(s, "session", 0.5, 1.2, 5.3, 3.3, "DevMemory session note");
  T(s, "Obsidian-style memory vault: sessions, prompts, edits, freshness, graph", { x: 0.5, y: 4.6, w: 5.3, h: 0.5, fontSize: 12, color: MUT, objectName: "Caption" });
  panel(s, 6.05, 1.2, 3.45, 3.9, "Built list panel");
  s.addText(richBullets([
    ["CLI:", "scan / run / pack / status / hook / app"],
    ["Desktop app:", "browse the memory vault"],
    ["Roblox Studio MCP:", "automated playtests"],
    ["Benchmark harness:", "runner, graders, reports, regrade"],
  ], 15), { x: 6.25, y: 1.4, w: 3.05, h: 3.5, margin: 0, valign: "top", fontFace: "Calibri", isTextBox: true, objectName: "Built list" });
  s.addNotes("Four pieces were built. A CLI drives scan, run, pack, status, hook and app; a desktop app shows the memory as an Obsidian-style vault; a Roblox Studio MCP integration runs automated playtests; and a benchmark harness with graders and regrading produces the numbers in this deck.");
}

// ============ 6 How we tested ============
{
  const s = pres.addSlide({ masterName: "CONTENT" });
  title(s, "How we tested");
  panel(s, 0.5, 1.2, 4.4, 3.95, "Fixed benchmark panel");
  T(s, "A  Fixed benchmark", { x: 0.7, y: 1.32, w: 4.0, h: 0.4, fontSize: 18, bold: true, color: VIO, objectName: "Col A head" });
  s.addText(richBullets([
    ["Conditions:", "C0 bare, C1 hand-written CLAUDE.md (the simple alternative), C2 map only, C3 full DevMemory; plus Sonnet without memory"],
    ["Tasks:", "8 dev tasks for tuning; 12 held-out on 2 projects (Roblox + Python), written by a separate agent, hash-frozen before tuning"],
    ["Graders:", "validated: unmodified project fails, reference passes"],
    ["Metric:", "cost per successful task at an 80% accuracy floor"],
  ], 12.5), { x: 0.7, y: 1.8, w: 4.0, h: 3.3, margin: 0, valign: "top", fontFace: "Calibri", isTextBox: true, objectName: "Col A list" });
  panel(s, 5.1, 1.2, 4.4, 3.95, "Multi-session panel");
  T(s, "B  Multi-session builds", { x: 5.3, y: 1.32, w: 4.0, h: 0.4, fontSize: 18, bold: true, color: CY, objectName: "Col B head" });
  s.addText(richBullets([
    ["Setup:", "8–16 fresh sessions building a game or web app from prompts"],
    ["Check:", "automated playtest after every prompt (Roblox Studio MCP / headless Chrome)"],
    ["Next prompt:", "chosen by a fixed rule: bug report from failed checks, else next feature"],
  ], 12.5), { x: 5.3, y: 1.8, w: 4.0, h: 3.3, margin: 0, valign: "top", fontFace: "Calibri", isTextBox: true, objectName: "Col B list" });
  s.addNotes("We ran two kinds of evaluation. The fixed benchmark compares four conditions and a bigger model on 12 held-out tasks frozen before tuning, with validated graders and cost per success at an 80% floor. The multi-session builds test whether memory helps over a whole project, with an automated playtest after every prompt and a fixed rule choosing the next prompt.");
}

// ============ 7 Held-out results ============
{
  const s = pres.addSlide({ masterName: "CONTENT" });
  title(s, "Held-out results: only C3 clears the 80% floor");
  barChart(s, 0.4, 1.25, 5.0, 3.5, "Pass rate on 12 unseen tasks (%)", DATA.passRate.labels, DATA.passRate.values, [3], "0", 100);
  // floor annotation
  T(s, `Accuracy floor: ${DATA.floor}%. Only C3 DevMemory (86%) is above it.`, { x: 0.5, y: 4.8, w: 4.8, h: 0.3, fontSize: 13, color: WARN, objectName: "Floor note" });
  barChart(s, 5.5, 1.25, 4.1, 2.7, "Cost per successful task (US$, list price)", DATA.cost.labels, DATA.cost.values, [3], "$0.0000", 0.013, { dataLabelFontSize: 10 });
  panel(s, 5.6, 4.05, 3.9, 1.05, "Sonnet callout");
  T(s, [{ text: "Sonnet without memory: " + DATA.sonnetCost, options: { bold: true, color: WARN, fontSize: 15, breakLine: true } }, { text: DATA.sonnetMult + " more per success, and still under the floor (75%)", options: { color: MUT, fontSize: 12 } }], { x: 5.8, y: 4.12, w: 3.6, h: 0.9, valign: "middle", objectName: "Sonnet callout text" });
  s.addNotes("On 12 unseen tasks, full DevMemory passes 86%, the only condition above the 80% accuracy floor, and it is also the cheapest per successful task. Sonnet without memory reaches 75% at $0.092 per success, about 11 times more. Memory on a cheaper model beat a bigger model without it.");
}

// ============ 8 Multi-session ============
{
  const s = pres.addSlide({ masterName: "CONTENT" });
  title(s, "Multi-session builds: about half the tokens");
  barChart(s, 0.4, 1.2, 4.6, 2.6, "Input tokens, same game (M, 16 sessions)", DATA.tokens.labels, DATA.tokens.values, [2], "0.00", 4.2, { dataLabelFontSize: 12 });
  // table
  const hdr = ["", "None", "AGENTS.md", "DevMemory"].map((t, i) => ({ text: t, options: { bold: true, color: i === 3 ? VIO : MUT, fontSize: 12, fill: { color: PANEL }, align: i ? "center" : "left" } }));
  const rows = [hdr].concat(DATA.buildStats.map((r) => [{ text: r.k, options: { color: TXT, fontSize: 12, fill: { color: PANEL } } }].concat(r.v.map((v, i) => ({ text: v, options: { color: i === 2 ? VIO : TXT, bold: i === 2, fontSize: 13, align: "center", fill: { color: PANEL } } })))));
  s.addTable(rows, { x: 0.5, y: 3.9, w: 4.5, colW: [1.5, 0.8, 1.1, 1.1], rowH: 0.3, border: { type: "solid", color: "232834", pt: 0.75 }, fontFace: "Calibri", objectName: "Build stats table" });
  T(s, [{ text: "Scripted 8-prompt build", options: { bold: true, color: CY, fontSize: 14, breakLine: true } }, { text: `DevMemory ${DATA.scripted.dm} tokens vs ${DATA.scripted.others}. The AGENTS.md build crashed in Studio.`, options: { color: MUT, fontSize: 12 } }], { x: 5.3, y: 1.25, w: 4.2, h: 1.0, valign: "top", objectName: "Scripted note" });
  shot(s, "race", 5.3, 2.4, 4.2, 1.6, "Game built with DevMemory-assisted sessions");
  T(s, "Game built by DevMemory-assisted sessions (graveyard arena)", { x: 5.3, y: 4.15, w: 4.2, h: 0.4, fontSize: 11, color: MUT, objectName: "Caption" });
  s.addNotes("Over 16 adaptive sessions building the same game, DevMemory used 1.85M input tokens versus 3.08M with no memory and 3.41M with a hand-written AGENTS.md, at the lowest cost and with 9 of 10 roadmap features. In the scripted 8-prompt build it used 0.61M tokens against 1.06M and 1.20M, and the AGENTS.md build crashed in Studio.");
}

// ============ 9 What failed ============
{
  const s = pres.addSlide({ masterName: "CONTENT" });
  title(s, "What failed, and what we changed");
  panel(s, 0.5, 1.2, 4.5, 2.05, "Round 1 loss panel");
  T(s, "Web-app race, round 1: we lost", { x: 0.7, y: 1.3, w: 4.1, h: 0.35, fontSize: 16, bold: true, color: RED, objectName: "Loss head" });
  T(s, "DevMemory 3/8 features vs 8/8. The bug report never repeated the label colors, and the pack did not carry the session where the user specified them. Fix: origin lineage + verbatim requirement memory.", { x: 0.7, y: 1.7, w: 4.1, h: 1.5, fontSize: 14, color: TXT, valign: "top", objectName: "Loss text" });
  panel(s, 0.5, 3.4, 4.5, 0.85, "Round 2 panel");
  T(s, [{ text: "Status: ", options: { bold: true, color: WARN } }, { text: DATA.round2, options: { color: TXT } }], { x: 0.7, y: 3.45, w: 4.1, h: 0.75, fontSize: 13, valign: "middle", objectName: "Round 2" });
  T(s, [{ text: "Also: ", options: { bold: true, color: CY } }, { text: "On the Python held-out project the hand-written file matched DevMemory (20 vs 19 of 24).", options: { color: TXT } }], { x: 0.5, y: 4.4, w: 4.5, h: 0.75, fontSize: 12.5, valign: "top", objectName: "Python note" });
  shot(s, "agents", 5.25, 1.2, 4.25, 1.55, "AGENTS.md build, broken");
  T(s, "AGENTS.md build passed every static check, yet shows WAVE 0 and no blades. The playtest gate matters.", { x: 5.25, y: 2.85, w: 4.25, h: 0.7, fontSize: 12.5, color: TXT, valign: "top", objectName: "Agents caption" });
  panel(s, 5.25, 3.65, 4.25, 1.5, "Limitations panel");
  T(s, "Limitations (all disclosed in RESULTS.md)", { x: 5.45, y: 3.72, w: 3.9, h: 0.3, fontSize: 13, bold: true, color: WARN, objectName: "Limits head" });
  s.addText(bullets(["Synthetic projects", "One run per multi-session condition", "Playtest protocol revised during the race"], 12), { x: 5.45, y: 4.05, w: 3.9, h: 1.0, margin: 0, valign: "top", fontFace: "Calibri", isTextBox: true, objectName: "Limits list" });
  s.addNotes("We report the loss. In the web-app race round 1 DevMemory built 3 of 8 features against 8 of 8 because the pack missed the session where the user specified label colors; we fixed it with origin lineage and verbatim requirement memory, and round 2 is the re-test. The AGENTS.md build shows why a playtest gate matters, and the limitations are stated up front.");
}

// ============ 10 Conclusion ============
{
  const s = pres.addSlide({ masterName: "CONTENT" });
  title(s, "Less compute, same or better results");
  const tk = [
    ["Cheaper model + memory", "beat a bigger model without it", VIO],
    ["~Half the tokens", "over multi-session work", CY],
    ["The user's own words", "are what make memory useful", GRN],
  ];
  tk.forEach((t, i) => {
    const x = 0.5 + i * 3.05;
    panel(s, x, 1.2, 2.85, 1.55, "Takeaway card " + (i + 1));
    T(s, t[0], { x: x + 0.2, y: 1.3, w: 2.45, h: 0.7, fontSize: 20, bold: true, color: t[2], valign: "middle", objectName: "Takeaway " + (i + 1) });
    T(s, t[1], { x: x + 0.2, y: 2.05, w: 2.45, h: 0.6, fontSize: 14, color: TXT, valign: "top", objectName: "Takeaway text " + (i + 1) });
  });
  T(s, "Next", { x: 0.5, y: 3.0, w: 2, h: 0.35, fontSize: 18, bold: true, color: TXT, objectName: "Next head" });
  s.addText(bullets(["Claude Code plugin: one-command install", "Hook-based capture for interactive sessions", "Studio playtest gate in the loop", "More engines"], 14), { x: 0.5, y: 3.4, w: 5.0, h: 1.5, margin: 0, valign: "top", fontFace: "Calibri", isTextBox: true, objectName: "Next list" });
  shot(s, "ref", 5.8, 3.0, 3.7, 1.5, "Blade Swarm showcase game");
  T(s, DATA.footer, { x: 0.5, y: 5.05, w: 8.6, h: 0.3, fontSize: 11, color: MUT, objectName: "Footer" });
  s.addNotes("Three takeaways: a cheaper model with memory beat a bigger model without it, memory roughly halved tokens over multi-session work, and preserving the user's own words is what makes memory useful. Next steps are a one-command Claude Code plugin, hook-based capture for interactive sessions, a Studio playtest gate in the loop, and more engines.");
}

(async () => {
  const out = path.join(__dirname, "DevMemory.pptx");
  await pres.writeFile({ fileName: out });
  await applyTheme(out, THEME);
  console.log("wrote", out);
})();
