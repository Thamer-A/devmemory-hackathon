"""Local read-only web UI for DevMemory (stdlib only, binds 127.0.0.1)."""
from __future__ import annotations

import json
import re
import threading
import webbrowser
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


class State:
    def __init__(self, project: Path, store: Path):
        self.project, self.store = Path(project).resolve(), Path(store)
        self.lock = threading.Lock()
        self.map = None

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
        return {"id": _sid(s), "started_at": s.get("started_at", ""), "prompt": s.get("prompt", ""),
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


def api(st: State, path: str, q: dict):
    g = lambda k, d="": (q.get(k) or [d])[0]
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
        return {"project": m["project"], "engine": m["engine"], "file_count": len(m["files"]),
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


def serve(project: Path, store: Path | None = None, port: int = 8765, open_browser: bool = True):
    project = Path(project).resolve()
    st = State(project, store or store_path(project))
    srv = ThreadingHTTPServer(("127.0.0.1", port), make_handler(st))
    url = f"http://127.0.0.1:{port}/"
    print(f"DevMemory UI: {url}  (project {project}, store {st.store})  Ctrl+C to stop", flush=True)
    if open_browser:
        threading.Timer(0.4, lambda: webbrowser.open(url)).start()
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        srv.server_close()
