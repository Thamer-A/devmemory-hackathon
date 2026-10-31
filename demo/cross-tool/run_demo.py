"""Cross-tool memory demo: sessions recorded from Claude Code, retrieved for Codex CLI.

The task board in demo/taskboard/devmemory was built over 8 Claude Code sessions
(captured in claude-code-memory/). We simulate a regression (someone restyled the label colors),
then ask Codex to restore the colors the user originally asked for. Those exact colors exist only
in a past Claude Code session. Three variants on identical copies:
  without  - Codex alone (`devmem codex --no-pack`)
  pack     - DevMemory's pack prepended to the prompt
  mcp      - no pack; DevMemory offered as an MCP server for this run (Codex decides whether to call it)
  mcp_agents - as mcp, plus a one-line AGENTS.md telling the agent to call get_context_pack first
All runs are captured by DevMemory's tool-agnostic adapter (snapshot diff + `codex exec --json`).

Codex runs with --ignore-user-config (via `devmem codex --isolated`) so personal plugins such as computer
use are not loaded: in attempt 2 the MCP variant used a computer-use server to inspect open desktop windows.
Isolation: attempt 1 put the copies in sibling folders inside this repo, and Codex (without memory)
searched the parent folders and found the other copy. Now each variant runs alone in a fresh folder
under ~/devmem-xtool/ (outside the repo), the memory store lives in a separate tree, and each run's
folder is deleted before the next starts. Results and session records are copied into results/.

  python demo/cross-tool/run_demo.py [without pack mcp] [--repeats N]
"""
import json
import re
import shutil
import subprocess
import sys
import uuid
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
APP = REPO / "demo" / "taskboard" / "devmemory"
TASK = "Someone changed the label colors and now they look wrong. Put the label colors back to exactly what I originally asked for."
MODEL = "gpt-5.6-luna"  # listed in the local Codex model cache for a ChatGPT login
WANT = {"Bug": "#e5484d", "Feature": "#3e63dd", "Chore": "#8b8d98"}
WORK = Path.home() / "devmem-xtool"
MEM = Path.home() / "devmem-xtool-mem"
OUT = HERE / "results"


AGENTS_LINE = "This project uses DevMemory. Before starting any task, call the devmemory get_context_pack tool with the user's request.\n"


def setup():
    proj = WORK / uuid.uuid4().hex[:8] / "project"
    proj.mkdir(parents=True)
    shutil.copy(APP / "server.js", proj)
    shutil.copytree(APP / "public", proj / "public")
    # the regression: a restyle replaced the specified hex colors everywhere
    for f in (proj / "public" / "app.js", proj / "public" / "style.css"):
        s = f.read_text(encoding="utf-8")
        s = s.replace("#e5484d", "#ff6b6b").replace("#3e63dd", "#4dabf7").replace("#8b8d98", "#adb5bd")
        f.write_text(s, encoding="utf-8")
    store = MEM / uuid.uuid4().hex[:8]
    shutil.copytree(HERE / "claude-code-memory", store)
    return proj, store


def check(proj):
    js = (proj / "public" / "app.js").read_text(encoding="utf-8")
    line = next((l for l in js.splitlines() if "Bug" in l and "Feature" in l and "#" in l), "")
    found = {k: (re.search(k + r"['\"]?\s*:\s*['\"](#[0-9a-fA-F]{6})", line) or [None, None])[1] for k in WANT}
    return {k: (v or "").lower() == WANT[k] for k, v in found.items()}, line.strip()


def run(variant, rep):
    proj, store = setup()
    if variant == "mcp_agents":
        (proj / "AGENTS.md").write_text(AGENTS_LINE, encoding="utf-8")
    cmd = [sys.executable, "-m", "devmem.cli", "codex", TASK, "--project", str(proj), "--store", str(store), "--model", MODEL, "--isolated"]
    cmd += {"without": ["--no-pack"], "pack": [], "mcp": ["--mcp"], "mcp_agents": ["--mcp"]}[variant]
    p = subprocess.run(cmd, cwd=REPO, capture_output=True, text=True, encoding="utf-8", errors="replace")
    ok, line = check(proj)
    metas = sorted((store / "sessions").glob("*.meta.json"))
    metas = [x for x in metas if x.stem.split(".")[0] > "20261031T030000"]  # this run's sessions only
    # the adapter's own record (the agent may also have recorded a session itself through MCP end_session)
    meta = next(x for x in metas if json.loads(x.read_text(encoding="utf-8"))["provider"].startswith("codex-cli"))
    m = json.loads(meta.read_text(encoding="utf-8"))
    self_recorded = [x for x in metas if x != meta]
    raw = (store / "sessions" / m["raw_record"]).read_text(encoding="utf-8")
    calls = [json.loads(l) for l in (store / "mcp_calls.jsonl").read_text(encoding="utf-8").splitlines()] \
        if (store / "mcp_calls.jsonl").exists() else []
    servers = sorted({json.loads(l)["event"]["item"].get("server") for l in raw.splitlines()
                      if '"mcp_tool_call"' in l and json.loads(l).get("type") == "tool_event"} - {None})
    # did the agent look outside its project folder?
    outside = sorted(set(re.findall(r"\.\.[\\/]|devmem-xtool|MiskXHumain|devmem-runs", raw)) - {"devmem-xtool"})
    dest = OUT / f"{variant}_r{rep}"
    shutil.rmtree(dest, ignore_errors=True)
    dest.mkdir(parents=True)
    shutil.copy(meta, dest / "session.meta.json")
    shutil.copy(store / "sessions" / m["raw_record"], dest / "session.jsonl")
    if calls:
        shutil.copy(store / "mcp_calls.jsonl", dest / "mcp_calls.jsonl")
    for x in self_recorded:  # sessions the agent recorded itself via MCP (begin/end_session)
        shutil.copy(x, dest / ("agent_recorded_" + x.name))
    shutil.rmtree(proj.parent, ignore_errors=True)
    shutil.rmtree(store, ignore_errors=True)
    return {"variant": variant, "repeat": rep, "colors_correct": ok, "all_correct": all(ok.values()), "line": line,
            "usage": m.get("usage"), "files_edited": m.get("files_edited"), "mcp_calls": [c["tool"] for c in calls], "mcp_servers_used": servers,
            "looked_outside_project": outside, "errors": m.get("errors"),
            "final_message": (m.get("result_text") or "")[:300], "exit": p.returncode}


if __name__ == "__main__":
    variants = [a for a in sys.argv[1:] if a in ("without", "pack", "mcp", "mcp_agents")] or ["without", "pack", "mcp"]
    reps = int(sys.argv[sys.argv.index("--repeats") + 1]) if "--repeats" in sys.argv else 1
    OUT.mkdir(exist_ok=True)
    for rep in range(reps):
        for v in variants:
            r = run(v, rep)
            with open(OUT / "results.jsonl", "a", encoding="utf-8") as f:
                f.write(json.dumps(r, ensure_ascii=False) + "\n")
            print(json.dumps(r, ensure_ascii=False), flush=True)
