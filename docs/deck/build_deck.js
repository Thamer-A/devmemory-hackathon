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
    { big: "0 of 3", label: "restored the spec", sub: "Codex runs without memory, asked to put back colors the user chose earlier" },
    { big: "3 of 12", label: "history tasks solved", sub: "without memory, on unseen tasks that need an earlier decision" },
    { big: "11×", label: "cost of a bigger model", sub: "per success for Sonnet without memory, and it still missed the accuracy bar" },
  ],
  tagline: "Preserve everything, send only what earns its tokens.",
  pack: [
    '## Conventions (observed in code)',
    '- Tunables live in src/shared/Config.lua (51 keys)',
    '- RemoteEvents only in src/shared/Remotes.lua',
    '## What the user asked for earlier (verbatim)',
    '- "Decisions: start with 2 blades, orbit radius 7 studs"',
    '## Relevant past sessions',
    '- [session dbf18bb2] User asked: "Now the upgrade',
    '  shop ... +1 Blade (Rare, 60 coins), Sharper Blades',
    '  (Common, 30) ... Greed +25% coins (Rare, 50) ..."',
    '- [session 3e2bb0e2] User asked: "... rarity colors',
    '  Common = gray, Rare = blue, Epic = purple ..."',
    '  Outcome: "The colors live in a new Config.Ui',
    '  table in src/shared/Config.lua"',
    '## Relevant files',
    '- src/shared/Config.lua [73 lines, used by 8]',
    '- src/server/Shop.lua [164 lines]',
  ].join("\n"),
  passRate: { labels: ["C0 bare", "C1 CLAUDE.md", "C2 map only", "C3 DevMemory"], set1: [67, 72, 64, 83], set2: [79, 79, 81, 98] },
  cost: { labels: ["C0 bare", "C1 CLAUDE.md", "C2 map only", "C3 DevMemory"], values: [0.0095, 0.0106, 0.0093, 0.0076] },
  sonnetCost: "$0.092", sonnetMult: "11×",
  floor: 80,
  tokens: { labels: ["No memory", "AGENTS.md", "DevMemory"], values: [3.08, 3.41, 1.85] },
  buildStats: [
    { k: "Cost", v: ["$3.41", "$2.88", "$2.48"] },
    { k: "Playable (human)", v: ["yes", "yes", "yes"] },
  ],
  scripted: { dm: "0.61M", others: "1.06M / 1.20M" },
  crossTool: "Claude Code memory: Codex right 3/3 vs 0/3, 56% fewer tokens",
  footer: "github.com/Thamer-A/devmemory-hackathon  ·  RESULTS.md (all numbers and disclosures)  ·  bench/METHODOLOGY.md",
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
  T(s, DATA.title, { x: 0.6, y: 0.55, w: 4.4, h: 0.85, fontSize: 52, bold: true, color: TXT, valign: "middle", objectName: "Title" });
  T(s, DATA.subtitle, { x: 0.6, y: 1.45, w: 4.2, h: 0.75, fontSize: 19, color: VIO, bold: true, valign: "top", objectName: "Subtitle" });
  T(s, "A local-first memory layer for AI coding tools. It records every AI session as plain files, and before each new session it hands the model a small, sourced briefing of about 1,000 tokens: the user's earlier decisions in their own words, the files that matter, and warnings where the code has changed since. No AI is used to build the briefing.",
    { x: 0.6, y: 2.3, w: 4.2, h: 1.55, fontSize: 12.5, color: TXT, valign: "top", objectName: "Summary" });
  T(s, [{ text: "Thamer Alhussain", options: { bold: true, color: TXT, breakLine: true } }, { text: DATA.event, options: { color: MUT } }],
    { x: 0.6, y: 4.1, w: 4.2, h: 0.8, fontSize: 12, valign: "top", objectName: "Author and event" });
  shot(s, "overview", 5.05, 0.9, 4.55, 3.55, "DevMemory app overview");
  T(s, "The DevMemory desktop app: a project's memory, browsable like a notes vault", { x: 5.05, y: 4.6, w: 4.55, h: 0.35, fontSize: 10.5, color: MUT, align: "center", objectName: "Screenshot caption" });
  s.addNotes("DevMemory gives every new AI coding session a warm start by remembering the project and what the user asked for earlier, and sending only what the next task needs. The screenshot is the desktop app that browses the captured memory. Challenge 2: less compute at equal or better task success.");
}

// ============ 2 Problem ============
{
  const s = pres.addSlide({ masterName: "CONTENT" });
  title(s, "Every AI coding session starts cold", "It re-reads the project, forgets earlier decisions, and guesses what the user meant");
  const cols = [VIO, CY, WARN];
  DATA.stats.forEach((st, i) => {
    const x = 0.5 + i * 3.05;
    panel(s, x, 1.45, 2.85, 2.2, "Stat card " + (i + 1));
    T(s, st.big, { x: x + 0.2, y: 1.55, w: 2.45, h: 0.8, fontSize: 44, bold: true, color: cols[i], valign: "middle", objectName: "Stat " + (i + 1) });
    T(s, st.label, { x: x + 0.2, y: 2.38, w: 2.45, h: 0.35, fontSize: 15, bold: true, color: TXT, objectName: "Stat label " + (i + 1) });
    T(s, st.sub, { x: x + 0.2, y: 2.75, w: 2.5, h: 0.85, fontSize: 11.5, color: MUT, valign: "top", objectName: "Stat sub " + (i + 1) });
  });
  panel(s, 0.5, 3.85, 9.0, 1.3, "Why panel");
  T(s, [
    { text: "Why this wastes compute. ", options: { bold: true, color: CY } },
    { text: "Without memory, each session either re-explores the project (tokens spent rediscovering what was already known) or guesses (wrong results, more sessions to fix them). A bigger model or a longer context window does not fix this: the missing information is not in the code at all, it lives in earlier conversations. DevMemory keeps those conversations and sends the few lines that matter.", options: { color: TXT } },
  ], { x: 0.7, y: 3.95, w: 8.6, h: 1.1, fontSize: 12.5, valign: "middle", objectName: "Why text" });
  s.addNotes("On unseen tasks whose answer depends on an earlier decision, agents without memory solved 3 of 12. Codex without memory never recovered colors a user had picked earlier. A bigger model without memory cost about 11 times more per success and still missed the accuracy bar. The information is in past conversations, not in the code.");
}

// ============ 3 Solution ============
{
  const s = pres.addSlide({ masterName: "CONTENT" });
  title(s, "How it works: scan, capture, pack, deliver");
  const steps = [
    ["1", "Scan", "Builds a project map deterministically: files, symbols, the require graph, Roblox remotes and config keys, and the project's own conventions as observed in the code. 0 AI tokens; about 150 ms on Blade Swarm.", VIO],
    ["2", "Capture", "Records every AI session through documented interfaces: Claude Code stream-json, Codex JSON events, or a project snapshot diff for any other tool. Prompts, visible replies, tool calls, edits and file hashes, as plain files.", CY],
    ["3", "Pack", "For a new request, ranks past sessions and files (BM25 plus dependency links) and assembles about 1,000 tokens: the user's earlier requirements verbatim, the session where the feature began, exact lines, and STALE flags.", GRN],
    ["4", "Deliver", "Injected automatically by a Claude Code hook, served to any MCP client by DevMemory's MCP server, or placed in any agent's prompt. The full archive never enters the prompt.", WARN],
  ];
  steps.forEach((st, i) => {
    const x = 0.5 + i * 2.3;
    panel(s, x, 1.15, 2.1, 3.35, "Step card " + st[0]);
    s.addShape(pres.ShapeType.ellipse, { x: x + 0.18, y: 1.3, w: 0.5, h: 0.5, fill: { color: st[3] }, line: { color: st[3] }, objectName: "Step circle " + st[0] });
    T(s, st[0], { x: x + 0.18, y: 1.3, w: 0.5, h: 0.5, fontSize: 18, bold: true, color: BG, align: "center", valign: "middle", objectName: "Step num " + st[0] });
    T(s, st[1], { x: x + 0.8, y: 1.3, w: 1.2, h: 0.5, fontSize: 18, bold: true, valign: "middle", objectName: "Step name " + st[0] });
    T(s, st[2], { x: x + 0.18, y: 1.95, w: 1.8, h: 2.5, fontSize: 11, color: TXT, valign: "top", objectName: "Step text " + st[0] });
    if (i < 3) T(s, "›", { x: x + 2.08, y: 2.6, w: 0.24, h: 0.5, fontSize: 24, color: MUT, align: "center", valign: "middle", objectName: "Arrow " + (i + 1) });
  });
  T(s, [{ text: "Design choices: ", options: { bold: true, color: CY } }, { text: "plain files on the developer's machine · no vector database · no AI in capture or retrieval · every item carries its source and freshness · preserve everything, send only what earns its tokens", options: { color: MUT } }],
    { x: 0.5, y: 4.62, w: 9, h: 0.5, fontSize: 11.5, valign: "middle", objectName: "Design choices" });
  s.addNotes("Four steps. A deterministic scan builds the project map with no model calls. Capture records each session through documented interfaces of whichever AI tool is used. A pack selects only what the next request needs, with sources and freshness. Delivery injects it through a hook, an MCP server or the prompt.");
}

// ============ 4 Pack ============
{
  const s = pres.addSlide({ masterName: "CONTENT" });
  title(s, "Example: what a fresh session receives", "Blade Swarm, a Roblox game built by prompting. The real pack for one request (excerpt)");
  panel(s, 0.5, 1.45, 5.4, 3.7, "Code panel", "0B0D12");
  const lines = DATA.pack.split("\n").map((l, i, a) => {
    const hdr = l.startsWith("##");
    const user = ["rarity colors", "Common = gray", "Config.Ui", "table in src"].some((k) => l.includes(k));
    return { text: l, options: { fontFace: "Courier New", fontSize: 9.5, color: hdr ? CY : user ? GRN : TXT, bold: hdr, breakLine: i < a.length - 1, paraSpaceAfter: 5 } };
  });
  s.addText(lines, { x: 0.65, y: 1.58, w: 5.1, h: 3.45, margin: 0, valign: "top", isTextBox: true, objectName: "Pack excerpt" });
  const pts = [
    ["The request", "A brand-new session is asked: \"Add an Epic upgrade called Twin Spin... with the rarity colors we picked.\" The colors were chosen four sessions earlier.", VIO],
    ["What DevMemory found", "Both earlier conversations, word for word: the shop design (rarities, prices) and the UI session where the user picked Common gray, Rare blue, Epic purple. About 1,150 tokens, built with 0 AI tokens.", CY],
    ["What the AI did", "Claude Code read one file, added Twin Spin as an Epic upgrade in 13 seconds, and noted it \"should show up purple like the colors we picked.\" (recorded live; shown in the video)", GRN],
  ];
  pts.forEach((p, i) => {
    const y = 1.45 + i * 1.25;
    panel(s, 6.1, y, 3.4, 1.15, "Point card " + (i + 1));
    T(s, p[0], { x: 6.25, y: y + 0.08, w: 3.1, h: 0.3, fontSize: 13, bold: true, color: p[2], objectName: "Point " + (i + 1) });
    T(s, p[1], { x: 6.25, y: y + 0.38, w: 3.15, h: 0.75, fontSize: 10, color: TXT, valign: "top", objectName: "Point text " + (i + 1) });
  });
  s.addNotes("This is a real pack from the Blade Swarm build. The request refers to colors chosen in an earlier session. DevMemory brings back that session and the shop-design session verbatim, plus where the code keeps the colors. Claude Code then went straight to the right file. The other builds also got this prompt right by reading the code; the point is what DevMemory delivers, without any AI calls.");
}

// ============ 5 What we built ============
{
  const s = pres.addSlide({ masterName: "CONTENT" });
  title(s, "What we built");
  shot(s, "session", 0.5, 1.15, 5.1, 3.2, "DevMemory session note");
  T(s, "A captured session in the app: the user's exact request, the outcome, files touched, freshness and cost", { x: 0.5, y: 4.45, w: 5.1, h: 0.5, fontSize: 10.5, color: MUT, valign: "top", objectName: "Caption" });
  panel(s, 5.8, 1.15, 3.7, 4.0, "Built list panel");
  s.addText(richBullets([
    ["CLI:", "devmem scan, run, pack, status, hook and app. Python standard library only; installs with pip."],
    ["Desktop app:", "an Obsidian-style vault. Sessions as notes, raw records as timelines, a graph of files, sessions and decisions, and Pack Lab to preview exactly what a new session will receive."],
    ["Any AI tool:", "an MCP server (get_context_pack, list and read sessions, begin and end session), a Codex adapter, and capture for any CLI or IDE agent. Tested with Claude Code and Codex."],
    ["Benchmark harness:", "isolated headless runs, validated graders, Roblox Studio playtests through MCP, headless-Chrome web checks, reports with confidence intervals."],
  ], 10.5), { x: 5.95, y: 1.27, w: 3.45, h: 3.8, margin: 0, valign: "top", fontFace: "Calibri", isTextBox: true, objectName: "Built list" });
  s.addNotes("A CLI drives scanning, capture and packs; a desktop app shows the memory as a vault with a graph and Pack Lab; an MCP server and adapters let any AI tool use and add to the memory; and a benchmark harness with validated graders and automated playtests produced the numbers in this deck.");
}

// ============ 6 How we tested ============
{
  const s = pres.addSlide({ masterName: "CONTENT" });
  title(s, "How we tested");
  panel(s, 0.5, 1.15, 4.4, 4.0, "Fixed benchmark panel");
  T(s, "A  Fixed benchmark (unseen tasks)", { x: 0.7, y: 1.25, w: 4.0, h: 0.35, fontSize: 15, bold: true, color: VIO, objectName: "Col A head" });
  s.addText(richBullets([
    ["Setups:", "C0 bare session; C1 hand-written CLAUDE.md (the simple alternative); C2 DevMemory's map only; C3 full DevMemory. Same model (Claude Haiku 5.5), same isolated settings, 3 repeats."],
    ["Tasks:", "8 dev tasks for tuning. 28 held-out tasks in two sets, on a Roblox game and a Python app, written by a separate agent and hash-frozen before any run. Types: code, history, stale, unrelated."],
    ["Graders:", "automatic and validated: the unmodified project must fail, a reference solution must pass."],
    ["Metric:", "cost per successful task (all runs' cost / passes), counted only for setups above an 80% accuracy floor; 95% confidence intervals."],
  ], 10.5), { x: 0.7, y: 1.68, w: 4.0, h: 3.4, margin: 0, valign: "top", fontFace: "Calibri", isTextBox: true, objectName: "Col A list" });
  panel(s, 5.1, 1.15, 4.4, 4.0, "Multi-session panel");
  T(s, "B  Real builds over many sessions", { x: 5.3, y: 1.25, w: 4.0, h: 0.35, fontSize: 15, bold: true, color: CY, objectName: "Col B head" });
  s.addText(richBullets([
    ["Roblox:", "the Blade Swarm game built three ways (no memory, a self-maintained AGENTS.md, DevMemory), 16 fresh sessions each, automated Studio playtest after every prompt, human playtest at the end."],
    ["Next prompt:", "chosen by a fixed rule: a bug report from failed checks, otherwise the next feature."],
    ["Web app:", "a team task board raced the same way (8 features, API and headless-Chrome checks), two rounds."],
    ["Across tools:", "memory recorded in Claude Code handed to Codex; isolated runs, 3 per variant."],
  ], 10.5), { x: 5.3, y: 1.68, w: 4.0, h: 3.4, margin: 0, valign: "top", fontFace: "Calibri", isTextBox: true, objectName: "Col B list" });
  s.addNotes("Two kinds of evaluation. The fixed benchmark compares four setups on 28 held-out tasks frozen before any run, with validated graders and cost per success at an 80% floor. The multi-session builds test whether memory helps over a whole project: a Roblox game, a web app, and a cross-tool test with Codex. All methods and disclosures are in RESULTS.md and bench/METHODOLOGY.md.");
}

// ============ 7 Held-out results ============
{
  const s = pres.addSlide({ masterName: "CONTENT" });
  title(s, "Unseen tasks: only DevMemory clears 80%");
  s.addChart(pres.charts.BAR, [
    { name: "Set 1 (12 tasks)", labels: DATA.passRate.labels, values: DATA.passRate.set1 },
    { name: "Set 2 (16 tasks)", labels: DATA.passRate.labels, values: DATA.passRate.set2 },
  ], {
    x: 0.4, y: 1.1, w: 5.0, h: 3.5, barDir: "col", barGapWidthPct: 40, chartColors: [GRY, VIO],
    showTitle: true, title: "Pass rate on held-out tasks (%)", titleColor: TXT, titleFontSize: 13, titleFontFace: "Calibri",
    showValue: true, dataLabelPosition: "outEnd", dataLabelColor: TXT, dataLabelFontSize: 11, dataLabelFontFace: "Calibri", dataLabelFormatCode: "0",
    catAxisLabelColor: MUT, catAxisLabelFontSize: 11, catAxisLabelFontFace: "Calibri",
    valAxisHidden: true, valAxisMinVal: 0, valAxisMaxVal: 110, valGridLine: { style: "none" }, catGridLine: { style: "none" },
    showLegend: true, legendPos: "b", legendColor: MUT, legendFontSize: 11, legendFontFace: "Calibri", objectName: "Pass rate chart",
  });
  T(s, `Accuracy floor ${DATA.floor}%. Set 1 shown with the shipped code (DevMemory scored 86% when the set was frozen).`, { x: 0.5, y: 4.7, w: 4.9, h: 0.45, fontSize: 10.5, color: WARN, valign: "top", objectName: "Floor note" });
  barChart(s, 5.5, 1.1, 4.1, 1.95, "Cost per successful task, set 2 (US$)", DATA.cost.labels, DATA.cost.values, [3], "$0.0000", 0.013, { dataLabelFontSize: 9.5, titleFontSize: 12 });
  panel(s, 5.6, 3.15, 3.9, 2.0, "Reading panel");
  s.addText(richBullets([
    ["Accuracy:", "DevMemory 83% and 98%; the others 64–81%."],
    ["Cost:", "lowest per success on set 2, $0.0076 vs $0.0093–0.0106."],
    ["Where it comes from:", "history tasks, 12/12 vs 3–4/12. Code, stale and unrelated tasks were similar for all."],
    ["Bigger model:", "Sonnet without memory, $0.092 per success (11× more) at 75%."],
  ], 10), { x: 5.75, y: 3.25, w: 3.65, h: 1.85, margin: 0, valign: "top", fontFace: "Calibri", isTextBox: true, objectName: "Reading list" });
  s.addNotes("Two held-out sets, 28 tasks, written by a separate agent and frozen before any run. DevMemory is the only setup above the 80% floor on both: 83% on set 1 with the shipped code and 98% on set 2, against 64 to 81% for the others. It is the cheapest per success on set 2. The gap comes from history tasks, where the answer lives in an earlier session. A bigger model without memory costs about 11 times more per success.");
}

// ============ 8 Multi-session ============
{
  const s = pres.addSlide({ masterName: "CONTENT" });
  title(s, "Building a real game: about half the tokens");
  barChart(s, 0.4, 1.05, 4.6, 2.55, "Input tokens, Blade Swarm (millions, 16 sessions)", DATA.tokens.labels, DATA.tokens.values, [2], "0.00", 4.2, { dataLabelFontSize: 12, titleFontSize: 12 });
  const hdr = ["", "None", "AGENTS.md", "DevMemory"].map((t, i) => ({ text: t, options: { bold: true, color: i === 3 ? VIO : MUT, fontSize: 11, fill: { color: PANEL }, align: i ? "center" : "left" } }));
  const rows = [hdr].concat(DATA.buildStats.map((r) => [{ text: r.k, options: { color: TXT, fontSize: 11, fill: { color: PANEL } } }].concat(r.v.map((v, i) => ({ text: v, options: { color: i === 2 ? VIO : TXT, bold: i === 2, fontSize: 12, align: "center", fill: { color: PANEL } } })))));
  s.addTable(rows, { x: 0.5, y: 3.7, w: 4.5, colW: [1.6, 0.8, 1.05, 1.05], rowH: 0.28, border: { type: "solid", color: "232834", pt: 0.75 }, fontFace: "Calibri", objectName: "Build stats table" });
  T(s, "Same prompts for all three; one run per setup (a case study, not a statistic).", { x: 0.5, y: 4.75, w: 4.5, h: 0.4, fontSize: 10, color: MUT, valign: "top", objectName: "Table note" });
  shot(s, "race", 5.3, 1.1, 4.2, 1.45, "Game built with DevMemory-assisted sessions");
  panel(s, 5.3, 2.7, 4.2, 2.45, "Race text panel");
  s.addText(richBullets([
    ["What happened:", "each feature was built in a fresh session. DevMemory used 1.85M input tokens vs 3.08M (no memory) and 3.41M (an AGENTS.md the agent kept itself), at the lowest cost. All three final games are playable."],
    ["Scripted 8-prompt build:", `DevMemory ${DATA.scripted.dm} tokens vs ${DATA.scripted.others}; the AGENTS.md build crashed on start in Studio.`],
    ["Caveat:", "the automated playtest was flaky and sent fix prompts for phantom bugs to every setup, so read the gap as indicative."],
  ], 10), { x: 5.45, y: 2.8, w: 3.95, h: 2.3, margin: 0, valign: "top", fontFace: "Calibri", isTextBox: true, objectName: "Race text" });
  s.addNotes("Over 16 sessions building Blade Swarm, DevMemory used 1.85M input tokens versus 3.08M with no memory and 3.41M with a self-maintained AGENTS.md, at the lowest cost. A human playtest found all three games playable. The automated playtest was flaky and triggered phantom-bug fixes in every setup, so the gap is indicative. In the scripted 8-prompt build, DevMemory used 0.61M tokens against 1.06M and 1.20M.");
}

// ============ 9 What failed ============
{
  const s = pres.addSlide({ masterName: "CONTENT" });
  title(s, "What failed, and what we changed");
  panel(s, 0.5, 1.1, 4.5, 2.25, "Round 1 loss panel");
  T(s, "Web-app race, round 1: DevMemory lost", { x: 0.7, y: 1.18, w: 4.1, h: 0.32, fontSize: 14, bold: true, color: RED, objectName: "Loss head" });
  T(s, "It built 3 of 8 features while the others built 8 of 8. A bug report never repeated the label colors, and the pack did not carry the session where the user had specified them. Fix: origin lineage (always include the session where a feature began) and verbatim requirement memory (keep the user's concrete values: colors, numbers, API paths).", { x: 0.7, y: 1.52, w: 4.1, h: 1.8, fontSize: 11, color: TXT, valign: "top", objectName: "Loss text" });
  panel(s, 0.5, 3.45, 4.5, 0.75, "Round 2 panel");
  T(s, [{ text: "Re-test: ", options: { bold: true, color: WARN } }, { text: DATA.round2, options: { color: TXT } }], { x: 0.7, y: 3.5, w: 4.1, h: 0.65, fontSize: 11, valign: "middle", objectName: "Round 2" });
  T(s, [{ text: "Also: ", options: { bold: true, color: CY } }, { text: "on the set-1 Python project the hand-written file matched DevMemory (20 vs 19 of 24); on set 2 DevMemory led there (23 vs 17). The retrieval fix cost 3 points on set 1 (86% to 83%).", options: { color: TXT } }], { x: 0.5, y: 4.3, w: 4.5, h: 0.85, fontSize: 10.5, valign: "top", objectName: "Python note" });
  shot(s, "agents", 5.25, 1.1, 4.25, 1.5, "AGENTS.md build, broken");
  T(s, "Scripted 8-prompt race: the AGENTS.md build passed every static check, yet crashed on start (WAVE 0, no blades). Code checks alone are not enough.", { x: 5.25, y: 2.68, w: 4.25, h: 0.6, fontSize: 10.5, color: TXT, valign: "top", objectName: "Agents caption" });
  panel(s, 5.25, 3.35, 4.25, 1.8, "Limitations panel");
  T(s, "Limitations (all disclosed in RESULTS.md)", { x: 5.4, y: 3.42, w: 4.0, h: 0.28, fontSize: 12, bold: true, color: WARN, objectName: "Limits head" });
  s.addText(bullets(["Benchmark projects are synthetic and small", "One run per setup in the multi-session builds", "The Roblox race's automated playtest was flaky (checked by a human at the end)", "Pack sizes are estimates (characters / 4); costs are API list-price equivalents"], 10), { x: 5.4, y: 3.75, w: 4.0, h: 1.35, margin: 0, valign: "top", fontFace: "Calibri", isTextBox: true, objectName: "Limits list" });
  s.addNotes("We report the loss. In web race round 1 DevMemory built 3 of 8 features because the pack missed the session where the user specified label colors; origin lineage and verbatim requirement memory fixed it, and round 2 was the re-test. Limitations are stated up front and detailed in RESULTS.md.");
}

// ============ 10 Conclusion ============
{
  const s = pres.addSlide({ masterName: "CONTENT" });
  title(s, "Less compute, same or better results");
  const tk = [
    ["Cheaper model + memory", "beat a bigger model without it: 83% vs 75% on the same tasks, at about a tenth of the cost per success", VIO],
    ["~Half the tokens", "over a real multi-session game build, with all three results playable", CY],
    ["Works across tools", DATA.crossTool, WARN],
    ["The user's own words", "are what make memory useful: requirements kept verbatim, never paraphrased", GRN],
  ];
  tk.forEach((t, i) => {
    const x = 0.5 + i * 2.29;
    panel(s, x, 1.1, 2.13, 1.75, "Takeaway card " + (i + 1));
    T(s, t[0], { x: x + 0.15, y: 1.18, w: 1.85, h: 0.6, fontSize: 15, bold: true, color: t[2], valign: "middle", objectName: "Takeaway " + (i + 1) });
    T(s, t[1], { x: x + 0.15, y: 1.82, w: 1.85, h: 1.0, fontSize: 10.5, color: TXT, valign: "top", objectName: "Takeaway text " + (i + 1) });
  });
  T(s, "Next", { x: 0.5, y: 3.0, w: 2, h: 0.32, fontSize: 16, bold: true, color: TXT, objectName: "Next head" });
  s.addText(richBullets([
    ["Install:", "a one-command Claude Code plugin."],
    ["More tools:", "test the MCP server in Cursor and VS Code."],
    ["Game dev:", "a Roblox Studio playtest gate in the loop, then more engines."],
    ["Scale:", "larger, real (non-synthetic) projects and more repeats."],
  ], 11), { x: 0.5, y: 3.35, w: 5.0, h: 1.6, margin: 0, valign: "top", fontFace: "Calibri", isTextBox: true, objectName: "Next list" });
  shot(s, "ref", 5.8, 3.05, 3.7, 1.5, "Blade Swarm showcase game");
  T(s, DATA.footer, { x: 0.5, y: 5.05, w: 8.6, h: 0.3, fontSize: 10.5, color: MUT, objectName: "Footer" });
  s.addNotes("Four takeaways: a cheaper model with memory beat a bigger model without it; memory roughly halved tokens over a real multi-session build; memory recorded in one tool helped another; and keeping the user's own words is what makes memory useful. Next: a one-command install, more MCP clients, a Studio playtest gate, and larger real projects.");
}

(async () => {
  const out = path.join(__dirname, "DevMemory.pptx");
  await pres.writeFile({ fileName: out });
  await applyTheme(out, THEME);
  console.log("wrote", out);
})();
