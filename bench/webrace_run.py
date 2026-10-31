"""Fully automated adaptive race for a web app (no human, no Studio in the loop).

  python -m bench.webrace_run init --race taskboard
  python -m bench.webrace_run loop --race taskboard          # runs until every condition is done
  python -m bench.webrace_run status --race taskboard

Per round: one fresh headless Claude Code session per active condition (in parallel), then each app
is copied to a temp dir, started with `node server.js`, and probed through its HTTP API and headless
Chrome (rendered DOM + screenshot). Next prompt = bug report built from failed checks (+ server
stderr lines), else the next roadmap feature. Same rule for every condition.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO))
from bench.run import RESULTS, RUN_ROOT, git, rmtree_force  # noqa: E402
from devmem.capture import record_session  # noqa: E402
from devmem.claude_cli import run_claude  # noqa: E402
from devmem.pack import build_pack  # noqa: E402
from devmem.scan import scan  # noqa: E402

CONDS = ["none", "agentsmd", "devmemory"]
PORTS = {"none": 3101, "agentsmd": 3102, "devmemory": 3103}
TAG = "r1"
# round 2+: let agents run their own server/tests (headless mode cannot ask for approval); same for all
ALLOWED = {"r1": None}
DEFAULT_ALLOWED = ["Bash(node:*)", "Bash(curl:*)"]
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"


def paths(race, cond, tag=None):
    root = RUN_ROOT / f"webrace_{race}_{cond}_{tag or TAG}"
    return root, root / "project", root / "devmemory", root / "state.json"


def spec_of(race):
    return json.loads((REPO / "bench" / "webrace" / race / "race.json").read_text(encoding="utf-8"))


def required(spec, features):
    req = list(spec["always_required"])
    for f in spec["roadmap"][:features]:
        req += [c for c in f["requires"] if c not in req]
    return req


# ---------------------------------------------------------------- probe
def http(method, url, body=None, timeout=5):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            raw = r.read().decode("utf-8", "replace")
            return r.status, raw
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace")
    except Exception as e:  # connection refused, timeout
        return 0, repr(e)


def jload(s):
    try:
        return json.loads(s)
    except Exception:
        return None


def cards_of(base):
    st, raw = http("GET", base + "/api/cards")
    v = jload(raw)
    if isinstance(v, dict):  # tolerate {cards:[...]}
        v = v.get("cards") or v.get("data")
    return v if isinstance(v, list) else None


def start_server(work, port):
    env = {**os.environ, "PORT": str(port)}
    log = open(work / "_server.log", "w", encoding="utf-8")
    p = subprocess.Popen(["node", "server.js"], cwd=work, env=env, stdout=log, stderr=subprocess.STDOUT)
    base = f"http://127.0.0.1:{port}"
    for _ in range(40):
        time.sleep(0.25)
        if p.poll() is not None:
            break
        st, _ = http("GET", base + "/", timeout=1)
        if st == 200:
            return p, base, True
    return p, base, False


def stop_server(p):
    if p and p.poll() is None:
        p.terminate()
        try:
            p.wait(5)
        except Exception:
            p.kill()


def assets_text(base):
    st, html = http("GET", base + "/")
    text = html if st == 200 else ""
    for ref in re.findall(r'(?:src|href)=["\']([^"\']+\.(?:js|css))["\']', html or ""):
        if ref.startswith("http"):
            continue
        s, body = http("GET", base + "/" + ref.lstrip("./").lstrip("/"))
        if s == 200:
            text += "\n" + body
    return text


def dom_and_shot(base, shot):
    common = [CHROME, "--headless=new", "--disable-gpu", "--no-first-run", "--virtual-time-budget=5000",
              f"--user-data-dir={tempfile.mkdtemp(prefix='chr-')}"]
    try:
        dom = subprocess.run(common + ["--dump-dom", base + "/"], capture_output=True, text=True,
                             encoding="utf-8", errors="replace", timeout=40).stdout
    except Exception:
        dom = ""
    try:
        shot.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(common + [f"--screenshot={shot}", "--window-size=1280,800", base + "/"],
                       capture_output=True, timeout=40)
    except Exception:
        pass
    return dom


def probe(project, port, shot):
    work = Path(tempfile.mkdtemp(prefix="webprobe-")) / "app"
    shutil.copytree(project, work, ignore=shutil.ignore_patterns(".git", "data", "node_modules", ".devmemory"))
    c, errors = {}, []
    p, base, up = start_server(work, port)
    c["server_starts"] = up
    if not up:
        stop_server(p)
        errors = (work / "_server.log").read_text(encoding="utf-8", errors="replace").strip().splitlines()[-6:]
        return {k: False for k in ["server_starts", "columns_render", "cards_api", "card_renders", "persistence",
                                    "move_api", "delete_api", "labels", "due_dates", "dark_theme", "assignees",
                                    "wip_limit", "search"]}, errors
    try:
        st, raw = http("POST", base + "/api/cards", {"title": "Probe card A", "column": "To Do"})
        a = jload(raw) if st in (200, 201) else None
        a = a.get("card", a) if isinstance(a, dict) else None
        lst = cards_of(base) or []
        c["cards_api"] = bool(a and a.get("id") is not None and any(x.get("title") == "Probe card A" for x in lst))
        aid = a.get("id") if a else None
        # labels / due / assignee round trips
        yday = (date.today() - timedelta(days=1)).isoformat()
        st, raw = http("POST", base + "/api/cards", {"title": "Probe labeled", "column": "To Do", "label": "Bug",
                                                      "dueDate": yday, "assignee": "Alice"})
        lst = cards_of(base) or []
        lab = next((x for x in lst if x.get("title") == "Probe labeled"), {})
        assets = assets_text(base)
        low = assets.lower()
        c["labels"] = lab.get("label") == "Bug" and "#e5484d" in low
        c["due_dates"] = lab.get("dueDate") == yday and "duedate" in low
        c["dark_theme"] = "#0f1115" in low and "#8b7cf6" in low
        dom = dom_and_shot(base, shot)
        text = re.sub(r"<[^>]+>", " ", dom)
        c["columns_render"] = all(s in text for s in ("To Do", "In Progress", "Done"))
        c["card_renders"] = "Probe card A" in text
        c["assignees"] = lab.get("assignee") == "Alice" and (re.search(r"\bAL\b|\bA\b", text) is not None or "Alice" in text)
        c["search"] = bool(re.search(r'<input[^>]+(type="search"|placeholder="[^"]*search)', dom, re.I)) and "clear filters" in text.lower()
        # move / delete
        if aid is not None:
            http("PATCH", f"{base}/api/cards/{aid}", {"column": "Done"})
            lst = cards_of(base) or []
            c["move_api"] = any(x.get("id") == aid and x.get("column") == "Done" for x in lst)
        else:
            c["move_api"] = False
        st, raw = http("POST", base + "/api/cards", {"title": "Probe delete me", "column": "To Do"})
        d = jload(raw)
        d = d.get("card", d) if isinstance(d, dict) else None
        if d and d.get("id") is not None:
            http("DELETE", f"{base}/api/cards/{d['id']}")
            c["delete_api"] = not any(x.get("title") == "Probe delete me" for x in (cards_of(base) or []))
        else:
            c["delete_api"] = False
        # WIP limit: fill In Progress to 3, the 4th must be rejected with 409
        codes = []
        for i in range(4):
            st, _ = http("POST", base + "/api/cards", {"title": f"Probe wip {i}", "column": "In Progress"})
            codes.append(st)
        c["wip_limit"] = codes[3] == 409 and all(s in (200, 201) for s in codes[:3])
        # persistence across restart
        stop_server(p)
        p, base, up2 = start_server(work, port)
        c["persistence"] = up2 and any(x.get("title") == "Probe card A" for x in (cards_of(base) or []))
    finally:
        stop_server(p)
        log = (work / "_server.log").read_text(encoding="utf-8", errors="replace")
        errors = [l for l in log.splitlines() if re.search(r"error|exception|unhandled", l, re.I)][:5]
    return c, errors


# ---------------------------------------------------------------- loop
def bug_prompt(spec, failed, errors):
    lines = ["I tested the app. Problems:"] + [f"- {spec['bug_text'][f]}" for f in failed]
    if errors:
        lines.append("The server terminal shows:")
        lines += [f"    {e[:200]}" for e in errors[:4]]
    lines.append("Please fix these before adding anything new.")
    return "\n".join(lines)


def init(race):
    spec = spec_of(race)
    for cond in CONDS:
        root, work, store, sp = paths(race, cond)
        rmtree_force(root)
        work.mkdir(parents=True)
        (work / "README.md").write_text("# Team Task Board\n\nWeb app. Run: `node server.js` (PORT env).\n", encoding="utf-8")
        if cond == "agentsmd":
            (work / "AGENTS.md").write_text(spec["agents_md"], encoding="utf-8")
            (work / "CLAUDE.md").write_text("@AGENTS.md\n", encoding="utf-8")
        git(work, "init", "-q")
        git(work, "config", "core.autocrlf", "false")
        git(work, "add", "-A")
        git(work, "-c", "user.name=bench", "-c", "user.email=bench@local", "commit", "-q", "-m", "scaffold")
        sp.write_text(json.dumps({"prompts": 0, "features": 0, "last_failed": None, "last_errors": [],
                                  "done": False, "history": []}, indent=1), encoding="utf-8")
    print("initialized", race)


def session(race, cond, spec):
    root, work, store, sp = paths(race, cond)
    st = json.loads(sp.read_text(encoding="utf-8"))
    if st["done"]:
        return None
    if st["prompts"] >= spec["max_prompts"]:
        st["done"] = True
        sp.write_text(json.dumps(st, indent=1), encoding="utf-8")
        return None
    failed = st["last_failed"] or []
    if failed:
        kind, prompt = "fix", bug_prompt(spec, failed, st["last_errors"])
        step = f"P{st['prompts'] + 1}-fix"
    elif st["features"] < len(spec["roadmap"]):
        f = spec["roadmap"][st["features"]]
        kind, prompt, step = "feature", f["prompt"], f"P{st['prompts'] + 1}-{f['id']}"
        st["features"] += 1
    else:
        st["done"] = True
        sp.write_text(json.dumps(st, indent=1), encoding="utf-8")
        return None
    raw_dir = RESULTS / "raw" / f"webrace_{race}_{cond}_{TAG}"
    raw_dir.mkdir(parents=True, exist_ok=True)
    pack_text, info = None, {}
    if cond == "devmemory":
        scan(work, store)
        pack_text, info = build_pack(work, store, prompt, budget=2000, mode="full")
        (raw_dir / f"{step}.pack.md").write_text(pack_text, encoding="utf-8")
    started = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    raw = raw_dir / f"{step}.jsonl"
    m = run_claude(prompt, work, raw, model=spec["model"], max_turns=spec["max_turns"],
                   append_system_prompt=pack_text, timeout_s=spec["timeout_s"],
                   allowed_tools=ALLOWED.get(TAG, DEFAULT_ALLOWED))
    if cond == "devmemory":
        record_session(work, raw, prompt, started, store=store, extra={"race_step": step})
    git(work, "add", "-A")
    stat = git(work, "diff", "--cached", "--shortstat").strip()
    git(work, "-c", "user.name=bench", "-c", "user.email=bench@local", "commit", "-q", "-m", step)
    st["prompts"] += 1
    st["history"].append({"step": step, "kind": kind, "cost": m.get("cost_usd_list"), "tok": m.get("total_input_tokens")})
    sp.write_text(json.dumps(st, indent=1), encoding="utf-8")
    row = {"type": "session", "race": race, "condition": cond, "tag": TAG, "step": step, "kind": kind, "prompt": prompt, "ts": started,
           "diffstat": stat, "pack_tokens_est": info.get("tokens_est", 0),
           **{k: m.get(k) for k in ("exit_code", "num_turns", "cost_usd_list", "wall_s", "input_tokens", "output_tokens",
                                    "cache_read_tokens", "cache_creation_tokens", "total_input_tokens", "tool_calls",
                                    "files_read_unique", "rate_limit")}}
    with open(RESULTS / f"webrace_{race}.jsonl", "a", encoding="utf-8") as f:
        f.write(json.dumps(row) + "\n")
    return step


def playtest(race, cond, spec, step):
    root, work, store, sp = paths(race, cond)
    st = json.loads(sp.read_text(encoding="utf-8"))
    shot = RESULTS / "raw" / f"webrace_{race}_{cond}_{TAG}" / f"{step}.png"
    checks, errors = probe(work, PORTS[cond], shot)
    req = required(spec, st["features"])
    failed = [k for k in req if not checks.get(k)]
    st["last_failed"], st["last_errors"] = failed, errors
    st["history"][-1]["failed"] = failed
    if not failed and st["features"] >= len(spec["roadmap"]):
        st["done"] = True
    sp.write_text(json.dumps(st, indent=1), encoding="utf-8")
    with open(RESULTS / f"webrace_{race}.jsonl", "a", encoding="utf-8") as f:
        f.write(json.dumps({"type": "playtest", "race": race, "condition": cond, "tag": TAG, "step": step, "required": req,
                            "failed": failed, "checks": checks, "errors": errors[:5]}) + "\n")
    print(f"{cond} {step}: failed={failed}", flush=True)


def loop(race):
    spec = spec_of(race)
    while True:
        with ThreadPoolExecutor(max_workers=3) as ex:
            steps = dict(zip(CONDS, ex.map(lambda c: session(race, c, spec), CONDS)))
        active = {c: s for c, s in steps.items() if s}
        if not active:
            break
        for c, s in active.items():
            playtest(race, c, spec, s)
    status(race)


def status(race):
    for cond in CONDS:
        _, _, _, sp = paths(race, cond)
        if sp.exists():
            st = json.loads(sp.read_text(encoding="utf-8"))
            cost = sum(h.get("cost") or 0 for h in st["history"])
            tok = sum(h.get("tok") or 0 for h in st["history"])
            print(f"{cond:10} prompts={st['prompts']} features={st['features']} cost=${cost:.2f} tok={tok/1000:.0f}k "
                  f"done={st['done']} last_failed={st['last_failed']}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["init", "loop", "status", "probe"])
    ap.add_argument("--race", required=True)
    ap.add_argument("--condition")
    ap.add_argument("--tag", default="r1")
    a = ap.parse_args()
    global TAG
    TAG = a.tag
    if a.cmd == "init":
        init(a.race)
    elif a.cmd == "loop":
        loop(a.race)
    elif a.cmd == "status":
        status(a.race)
    elif a.cmd == "probe":  # manual probe of one condition's current project
        _, work, _, _ = paths(a.race, a.condition)
        print(probe(work, PORTS[a.condition], RESULTS / "raw" / "probe_manual.png"))


if __name__ == "__main__":
    main()
