"""Local read-only web UI for DevMemory (stdlib only, binds 127.0.0.1)."""
from __future__ import annotations

import json
import os
import re
import subprocess
import threading
import webbrowser
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

from .pack import build_pack, decision_sentences, freshness, load_sessions
from .scan import convention_lines, scan
from .store import store_path

STATIC = Path(__file__).parent / "ui"
MIME = {".html": "text/html; charset=utf-8", ".css": "text/css; charset=utf-8",
        ".js": "text/javascript; charset=utf-8", ".svg": "image/svg+xml"}


def _sid(s: dict) -> str:
    return str(s.get("session_id") or s.get("_meta", ""))


REPO = Path(__file__).resolve().parent.parent
EXAMPLES = [
    {"name": "Blade Swarm (16 sessions)", "desc": "Roblox + Rojo game built over 16 captured sessions",
     "project": REPO / "demo/memory-example/blade-swarm-race",
     "store": REPO / "demo/memory-example/blade-swarm-race/.devmemory"},
    {"name": "CoinRush (benchmark fixture)", "desc": "Small Roblox benchmark project (P1)",
     "project": REPO / "bench/projects/P1/game", "store": REPO / "bench/projects/P1/devmemory"},
]
VAULT_CAP = 3 * 1024 * 1024


def recents_file() -> Path:
    base = os.environ.get("APPDATA") or str(Path.home() / ".config")
    return Path(base) / "DevMemory" / "recents.json"


def load_recents() -> list[dict]:
    try:
        d = json.loads(recents_file().read_text(encoding="utf-8"))
        return [r for r in d if isinstance(r, dict) and r.get("project")]
    except (OSError, ValueError):
        return []


def add_recent(project: Path, store: Path, name: str) -> None:
    rs = [r for r in load_recents() if r.get("project") != str(project) or r.get("store") != str(store)]
    rs.insert(0, {"project": str(project), "store": str(store), "name": name,
                  "last_opened": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")})
    try:
        f = recents_file()
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(json.dumps(rs[:12], indent=1), encoding="utf-8")
    except OSError:
        pass


def pick_dialog(kind: str) -> str:
    """Native folder dialog (tkinter) in a fresh thread with its own Tk root."""
    res: list[str] = []

    def run():
        try:
            import tkinter
            from tkinter import filedialog
            root = tkinter.Tk()
            root.withdraw()
            root.attributes("-topmost", True)
            root.update()
            res.append(filedialog.askdirectory(
                parent=root, title="Select project folder" if kind == "project" else "Select memory store folder",
                mustexist=True) or "")
            root.destroy()
        except Exception as e:  # no display / no tk
            res.append("")
            print("pick failed:", e, flush=True)
    t = threading.Thread(target=run)
    t.start()
    t.join(300)
    return str(Path(res[0])) if res and res[0] else ""


class State:
    def __init__(self, project: Path | None, store: Path | None):
        self.lock = threading.Lock()
        self.set(project, store)

    def set(self, project, store):
        self.project = Path(project).resolve() if project else None
        self.store = Path(store).resolve() if store else None
        self.map = None

    def name(self) -> str:
        return self.project.name if self.project else ""

    def in_roots(self, p: Path) -> bool:
        p = p.resolve()
        for root in (self.project, self.store):
            if root and (p == root or root in p.parents):
                return True
        return False

    def get_map(self, rescan: bool = False) -> dict:
        with self.lock:
            p = self.store / "index" / "map.json"
            if rescan or self.map is None:
                if rescan or not p.exists():
                    self.map = scan(self.project, self.store)
                else:
                    self.map = json.loads(p.read_text(encoding="utf-8"))
            return self.map

    def sessions(self) -> list[dict]:
        ss = load_sessions(self.store)
        ss.sort(key=lambda s: s.get("started_at", ""))
        return ss

    def session_view(self, s: dict) -> dict:
        fr = freshness(s, self.project)
        return {"id": _sid(s), "meta_file": s.get("_meta", ""), "raw_record": s.get("raw_record", ""),
                "started_at": s.get("started_at", ""), "prompt": s.get("prompt", ""),
                "usage": s.get("usage") or {}, "files_edited": s.get("files_edited", []),
                "files_read": s.get("files_read", []), "freshness": fr["status"]}

    def decisions(self) -> list[dict]:
        out, seen = [], set()
        for s in self.sessions():
            for sent in decision_sentences(s.get("prompt", "")):
                if sent in seen:
                    continue
                seen.add(sent)
                out.append({"id": f"d{len(out) + 1}", "text": sent, "session": _sid(s),
                            "started_at": s.get("started_at", "")})
        return out


def _tree_files(m: dict) -> list[dict]:
    return [{"path": rel, "lang": i.get("lang"), "module": i.get("module"), "lines": i.get("lines"),
             "kind": i.get("kind")} for rel, i in sorted(m["files"].items())]


def _vault_tree(d: Path, root: Path) -> list[dict]:
    out = []
    try:
        entries = sorted(d.iterdir(), key=lambda p: (p.is_file(), p.name.lower()))
    except OSError:
        return out
    for p in entries:
        rel = p.relative_to(root).as_posix()
        if p.is_dir():
            out.append({"name": p.name, "path": rel, "type": "dir", "children": _vault_tree(p, root)})
        else:
            try:
                size = p.stat().st_size
            except OSError:
                size = 0
            out.append({"name": p.name, "path": rel, "type": "file", "size": size})
    return out


def _resolve_in(base: Path, rel: str) -> Path | None:
    if not rel or "\x00" in rel:
        return None
    p = Path(rel)
    if p.is_absolute() or ".." in p.parts:
        return None
    fp = (base / p).resolve()
    if fp != base.resolve() and base.resolve() not in fp.parents:
        return None
    return fp


def home_info(st: State) -> dict:
    def ex(e):
        return {"name": e["name"], "desc": e["desc"], "project": str(e["project"]), "store": str(e["store"]),
                "exists": Path(e["store"]).exists()}
    rec = [r for r in load_recents() if Path(r["project"]).exists()]
    return {"current": {"project": str(st.project) if st.project else None, "store": str(st.store) if st.store else None,
                        "name": st.name()},
            "recents": rec, "examples": [ex(e) for e in EXAMPLES]}


def api_post(st: State, path: str, q: dict):
    g = lambda k, d="": (q.get(k) or [d])[0]
    if path == "/api/pick":
        kind = g("kind", "project")
        p = pick_dialog(kind)
        return {"path": p, "cancelled": not p}
    if path == "/api/open":
        pr, sr = g("project"), g("store")
        if not pr:
            return 400, {"error": "project required"}
        project = Path(pr)
        if not project.is_dir():
            return 400, {"error": f"not a folder: {pr}"}
        store = Path(sr) if sr else project / ".devmemory"
        if not store.is_dir() and not sr:
            pass
        has_map = (store / "index" / "map.json").is_file()
        if not has_map and g("scan") != "1":
            return {"needs_scan": True, "project": str(project.resolve()), "store": str(store)}
        with st.lock:
            st.set(project, store)
        if not has_map:
            scan(st.project, st.store)
        st.get_map()
        add_recent(st.project, st.store, st.project.name)
        return {"ok": True, "name": st.name(), "scanned": not has_map}
    if path == "/api/reveal":
        rel = g("path")
        cands = []
        if rel and Path(rel).is_absolute():
            cands = [Path(rel)]
        else:
            for base in (st.store, st.project):
                if base and (c := _resolve_in(base, rel)):
                    cands.append(c)
        cands = [c for c in cands if c.exists() and st.in_roots(c)]
        if not cands or (rel and ".." in Path(rel).parts):
            return 400, {"error": "path outside project/store"}
        if g("dry") != "1" and os.name == "nt":
            subprocess.Popen(["explorer", "/select," + str(cands[0]).replace("/", "\\")])
        return {"ok": True, "path": str(cands[0])}
    return 404, {"error": "unknown endpoint"}


def api(st: State, path: str, q: dict):
    g = lambda k, d="": (q.get(k) or [d])[0]
    if path == "/api/home":
        return home_info(st)
    if path == "/api/state":
        return {"project": str(st.project) if st.project else None, "name": st.name()}
    if st.project is None:
        return 409, {"error": "no project open"}
    if path == "/api/vault":
        if not st.store.is_dir():
            return {"root": st.store.name, "path": str(st.store), "tree": []}
        return {"root": st.store.name, "path": str(st.store), "tree": _vault_tree(st.store, st.store)}
    if path == "/api/vault/file":
        fp = _resolve_in(st.store, g("path"))
        if fp is None or not fp.is_file():
            return 404, {"error": "not found in store"}
        size = fp.stat().st_size
        if size > VAULT_CAP:
            return 413, {"error": f"file too large ({size} bytes, cap {VAULT_CAP})", "size": size}
        return {"path": fp.relative_to(st.store.resolve()).as_posix(), "size": size, "abs": str(fp),
                "content": fp.read_text(encoding="utf-8", errors="replace")}
    if path == "/api/overview":
        m = st.get_map()
        ss = st.sessions()
        fresh = {}
        tin = tout = tcache = 0
        cost = 0.0
        for s in ss:
            f = freshness(s, st.project)["status"]
            fresh[f] = fresh.get(f, 0) + 1
            u = s.get("usage") or {}
            tin += u.get("input_tokens") or 0
            tout += u.get("output_tokens") or 0
            tcache += (u.get("cache_read_tokens") or 0) + (u.get("cache_creation_tokens") or 0)
            cost += u.get("cost_usd_list") or 0
        return {"project": m["project"], "dir_name": st.name(), "engine": m["engine"], "file_count": len(m["files"]),
                "session_count": len(ss), "freshness": fresh, "tokens": {"input": tin, "output": tout, "cache": tcache},
                "cost_usd": round(cost, 4), "conventions": convention_lines(m), "rojo": m.get("rojo", {}),
                "scanned_at": m.get("scanned_at"), "store": str(st.store), "project_path": str(st.project),
                "decision_count": len(st.decisions()),
                "per_session": [{"id": _sid(s), "started_at": s.get("started_at", ""),
                                 "input": (s.get("usage") or {}).get("input_tokens") or 0,
                                 "output": (s.get("usage") or {}).get("output_tokens") or 0,
                                 "cache": ((s.get("usage") or {}).get("cache_read_tokens") or 0)
                                 + ((s.get("usage") or {}).get("cache_creation_tokens") or 0)} for s in ss]}
    if path == "/api/files":
        m = st.get_map(rescan=g("rescan") == "1")
        return {"files": _tree_files(m), "scanned_at": m.get("scanned_at")}
    if path == "/api/file":
        rel = g("path")
        m = st.get_map()
        if rel not in m["files"] or ".." in Path(rel).parts or Path(rel).is_absolute():
            return 404, {"error": "not in map"}
        fp = (st.project / rel).resolve()
        if st.project not in fp.parents or not fp.is_file():
            return 404, {"error": "not found"}
        touched = []
        for s in st.sessions():
            role = "edited" if rel in s.get("files_edited", []) else "read" if rel in s.get("files_read", []) else None
            if role:
                touched.append({**st.session_view(s), "role": role, "prompt": s.get("prompt", "")[:140]})
        deps = m["files"][rel].get("deps", [])
        by_module = {i["module"]: r for r, i in m["files"].items()}
        requires = sorted({by_module[d.split(".")[-1]] for d in deps if d.split(".")[-1] in by_module} - {rel})
        return {"path": rel, "content": fp.read_text(encoding="utf-8", errors="replace"), "entry": m["files"][rel],
                "used_by": m.get("used_by", {}).get(rel, []), "requires": requires, "sessions": touched}
    if path == "/api/sessions":
        return {"sessions": [{**st.session_view(s), "prompt": s.get("prompt", "")[:200]} for s in st.sessions()]}
    if path == "/api/session":
        sid = g("id")
        for s in st.sessions():
            if _sid(s) == sid or _sid(s).startswith(sid) and sid:
                meta = {k: v for k, v in s.items()}
                return {"meta": meta, "freshness": freshness(s, st.project), "id": _sid(s)}
        return 404, {"error": "unknown session"}
    if path == "/api/decisions":
        return {"decisions": st.decisions()}
    if path == "/api/graph":
        m = st.get_map()
        nodes, edges, ids = [], [], set()
        by_module = {i["module"]: r for r, i in m["files"].items()}
        used = m.get("used_by", {})
        for rel, i in m["files"].items():
            if i.get("lang") == "text" and not rel.endswith(".md"):
                continue
            ids.add("file:" + rel)
            nodes.append({"id": "file:" + rel, "type": "file", "label": Path(rel).name.split(".")[0],
                          "size": 4 + min(10, len(used.get(rel, [])) * 1.5), "status": i.get("lang", "")})
        for rel, i in m["files"].items():
            if "file:" + rel not in ids:
                continue
            for d in i.get("deps", []):
                t = by_module.get(d.split(".")[-1])
                if t and t != rel and "file:" + t in ids:
                    edges.append({"source": "file:" + rel, "target": "file:" + t, "kind": "requires"})
        for s in st.sessions():
            sid = "session:" + _sid(s)
            fr = freshness(s, st.project)["status"]
            nodes.append({"id": sid, "type": "session", "label": (s.get("prompt") or "session")[:28],
                          "size": 7, "status": fr})
            for f in s.get("files_edited", []):
                if "file:" + f in ids:
                    edges.append({"source": sid, "target": "file:" + f, "kind": "edited"})
            for f in s.get("files_read", []):
                if "file:" + f in ids and f not in s.get("files_edited", []):
                    edges.append({"source": sid, "target": "file:" + f, "kind": "read"})
        for d in st.decisions():
            nodes.append({"id": "decision:" + d["id"], "type": "decision", "label": d["text"][:30], "size": 5, "status": ""})
            edges.append({"source": "session:" + d["session"], "target": "decision:" + d["id"], "kind": "states"})
        for n, line in enumerate(convention_lines(m)):
            cid = f"convention:c{n + 1}"
            nodes.append({"id": cid, "type": "convention", "label": re.sub(r"[`]", "", line)[:30], "size": 5, "status": ""})
            for f in re.findall(r"[\w./-]+\.(?:luau|lua|py|js|ts|json)", line):
                if "file:" + f in ids:
                    edges.append({"source": cid, "target": "file:" + f, "kind": "states"})
        return {"nodes": nodes, "edges": edges}
    if path == "/api/pack":
        task = g("task").strip()
        if not task:
            return 400, {"error": "task required"}
        try:
            budget = max(100, min(20000, int(g("budget", "1500"))))
        except ValueError:
            budget = 1500
        mode = g("mode", "full")
        if mode not in ("full", "static", "nofresh"):
            mode = "full"
        text, info = build_pack(st.project, st.store, task, budget=budget, mode=mode)
        m = st.get_map()
        sess = {_sid(s): s for s in st.sessions()}
        for it in info["sessions"]:
            s = sess.get(str(it["session"]))
            if s:
                it["prompt"] = (s.get("prompt") or "")[:160]
                it["started_at"] = s.get("started_at", "")
        info["file_details"] = [{"path": f, "lines": m["files"].get(f, {}).get("lines"),
                                 "module": m["files"].get(f, {}).get("module")} for f in info["files"]]
        return {"markdown": text, "info": {k: v for k, v in info.items()}, "budget": budget}
    return 404, {"error": "unknown endpoint"}


def make_handler(st: State):
    class H(BaseHTTPRequestHandler):
        def log_message(self, *a):
            pass

        def _send(self, code, body: bytes, ctype):
            self.send_response(code)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)

        def do_POST(self):
            u = urlparse(self.path)
            try:
                res = api_post(st, u.path, parse_qs(u.query))
                code, data = res if isinstance(res, tuple) else (200, res)
                self._send(code, json.dumps(data).encode("utf-8"), "application/json; charset=utf-8")
            except (BrokenPipeError, ConnectionResetError):
                pass
            except Exception as e:
                try:
                    self._send(500, json.dumps({"error": str(e)}).encode(), "application/json")
                except Exception:
                    pass

        def do_GET(self):
            u = urlparse(self.path)
            try:
                if u.path.startswith("/api/"):
                    res = api(st, u.path, parse_qs(u.query))
                    code, data = res if isinstance(res, tuple) else (200, res)
                    return self._send(code, json.dumps(data).encode("utf-8"), "application/json; charset=utf-8")
                name = "index.html" if u.path in ("/", "") else u.path.lstrip("/")
                fp = (STATIC / name).resolve()
                if STATIC.resolve() not in fp.parents or not fp.is_file():
                    return self._send(404, b"not found", "text/plain")
                return self._send(200, fp.read_bytes(), MIME.get(fp.suffix, "application/octet-stream"))
            except (BrokenPipeError, ConnectionResetError):
                pass
            except Exception as e:  # keep the demo alive
                try:
                    self._send(500, json.dumps({"error": str(e)}).encode(), "application/json")
                except Exception:
                    pass
    return H


def make_server(project: Path | None, store: Path | None = None, port: int = 8765):
    """Build (but do not start) the server; port 0 picks a free port. Returns (server, state)."""
    if project is not None:
        project = Path(project).resolve()
        store = store or store_path(project)
        if (Path(store) / "index" / "map.json").is_file():
            add_recent(project, Path(store).resolve(), project.name)
    st = State(project, store)
    return ThreadingHTTPServer(("127.0.0.1", port), make_handler(st)), st


def serve(project: Path | None, store: Path | None = None, port: int = 8765, open_browser: bool = True):
    srv, st = make_server(project, store, port)
    port = srv.server_address[1]
    url = f"http://127.0.0.1:{port}/"
    print(f"DevMemory UI: {url}  (project {st.project}, store {st.store})  Ctrl+C to stop", flush=True)
    if open_browser:
        threading.Timer(0.4, lambda: webbrowser.open(url)).start()
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        srv.server_close()
