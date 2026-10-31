// Reference solution used ONLY to validate the probe (positive control). Never shown to agents.
const http = require("http");
const fs = require("fs");
const path = require("path");

const PORT = process.env.PORT || 3000;
const DATA = path.join(__dirname, "data", "board.json");
const COLUMNS = ["To Do", "In Progress", "Done"];
const WIP = 3;

function load() {
  try { return JSON.parse(fs.readFileSync(DATA, "utf8")); } catch { return []; }
}
function save(cards) {
  fs.mkdirSync(path.dirname(DATA), { recursive: true });
  fs.writeFileSync(DATA, JSON.stringify(cards, null, 2));
}
function send(res, code, body, type = "application/json") {
  res.writeHead(code, { "Content-Type": type });
  res.end(type === "application/json" ? JSON.stringify(body) : body);
}
function body(req) {
  return new Promise((resolve) => {
    let s = "";
    req.on("data", (c) => (s += c));
    req.on("end", () => { try { resolve(JSON.parse(s || "{}")); } catch { resolve({}); } });
  });
}

http.createServer(async (req, res) => {
  const url = new URL(req.url, "http://x");
  const cards = load();
  if (url.pathname === "/api/cards" && req.method === "GET") return send(res, 200, cards);
  if (url.pathname === "/api/cards" && req.method === "POST") {
    const b = await body(req);
    const column = COLUMNS.includes(b.column) ? b.column : "To Do";
    if (column === "In Progress" && cards.filter((c) => c.column === "In Progress").length >= WIP) return send(res, 409, { error: "WIP limit" });
    const card = { id: Date.now() + Math.floor(Math.random() * 1000), title: b.title, column, label: b.label, dueDate: b.dueDate, assignee: b.assignee };
    cards.push(card); save(cards); return send(res, 201, card);
  }
  const m = url.pathname.match(/^\/api\/cards\/(\d+)$/);
  if (m) {
    const card = cards.find((c) => String(c.id) === m[1]);
    if (!card) return send(res, 404, { error: "not found" });
    if (req.method === "DELETE") { save(cards.filter((c) => c !== card)); return send(res, 204, ""); }
    if (req.method === "PATCH") {
      const b = await body(req);
      if (b.column === "In Progress" && card.column !== "In Progress" && cards.filter((c) => c.column === "In Progress").length >= WIP) return send(res, 409, { error: "WIP limit" });
      Object.assign(card, b); save(cards); return send(res, 200, card);
    }
  }
  const file = path.join(__dirname, "public", url.pathname === "/" ? "index.html" : url.pathname);
  if (file.startsWith(path.join(__dirname, "public")) && fs.existsSync(file)) {
    const type = file.endsWith(".html") ? "text/html" : file.endsWith(".css") ? "text/css" : "text/javascript";
    return send(res, 200, fs.readFileSync(file), type);
  }
  send(res, 404, { error: "not found" });
}).listen(PORT);
