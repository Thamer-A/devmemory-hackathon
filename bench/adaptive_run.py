"""Adaptive multi-session race: prompt -> playtest -> next prompt chosen by a FIXED rule.

  python -m bench.adaptive_run init   --race blade --condition devmemory
  python -m bench.adaptive_run next   --race blade --condition devmemory   # runs one fresh session
  (playtest in Studio with the probes; see bench/adaptive/README.md)
  python -m bench.adaptive_run record --race blade --condition devmemory --server '<json>' --client '<json>' [--gameover '<json>']
  python -m bench.adaptive_run status --race blade

Rule (identical for every condition): if any required check failed in the last playtest, the next
prompt is a bug report built only from the failed checks and error lines; otherwise the next
roadmap feature. Required = always_required + the checks of every feature prompted so far.
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO))
from bench.run import RESULTS, RUN_ROOT, git, rmtree_force  # noqa: E402
from devmem.capture import record_session  # noqa: E402
from devmem.claude_cli import run_claude  # noqa: E402
from devmem.pack import build_pack  # noqa: E402
from devmem.scan import scan  # noqa: E402


def paths(race: str, cond: str, tag: str):
    name = f"adaptive_{race}_{cond}_{tag}"
    root = RUN_ROOT / name
    return name, root / "project", root / "devmemory", root / "state.json"


def load(spec_dir: Path):
    return json.loads((spec_dir / "race.json").read_text(encoding="utf-8"))


def required(spec: dict, features_prompted: int) -> list[str]:
    req = list(spec["always_required"])
    for f in spec["roadmap"][:features_prompted]:
        req += [c for c in f["requires"] if c not in req]
    return req


def compute_checks(spec: dict, server: dict, client: dict, gameover: dict | None) -> tuple[dict, list[str]]:
    errors = list(server.get("errors", [])) + list(client.get("errors", []))
    if gameover:
        errors += [e for e in gameover.get("errors", []) if e not in errors]
    def grew(key: str) -> bool:
        a, b = server.get("stats_first", {}), server.get("stats_last", {})
        ks = [k for k in b if key in k.lower()]
        return any((b.get(k) or 0) > (a.get(k) or 0) for k in ks)
    df, dm = server.get("dist_first"), server.get("dist_min")
    c = {
        "no_errors": not errors,
        "blades_render": (client.get("blades_max") or 0) >= 1,
        "zombies_spawn": (server.get("npc_max") or 0) >= 1,
        # approach observed, or zombies reached a player who never moved (measurement may start late)
        "zombies_chase": dm is not None and ((df is not None and dm < df - 4) or dm < 6),
        "kills_and_coins": grew("coin") and grew("kill"),
        "waves_advance": bool(client.get("wave2_seen")) or (server.get("npc_spawned") or 0) > 8,
        "player_damaged": server.get("health_min") is not None and server["health_min"] < (server.get("health_max") or 0),
        "shop_offers": (client.get("shop_names_seen") or 0) >= 2,
        "hud_visible": bool(client.get("wave_word") and client.get("timer_seen") and client.get("health_seen")),
        "game_over_reset": bool(gameover and (gameover.get("gameover_seen") or gameover.get("wave1_seen"))),
        "damage_numbers": (client.get("billboards_max") or 0) >= 1,
        "map_dressed": bool(server.get("atmosphere")) and (server.get("anchored_parts") or 0) >= 40,
        "zombies_look": (server.get("npc_parts_median") or 0) >= 6,
    }
    return c, errors


def bug_prompt(spec: dict, failed: list[str], errors: list[str]) -> str:
    lines = ["I playtested it. Problems:"]
    for f in failed:
        if f == "no_errors":
            lines.append("- " + spec["bug_text"]["no_errors"] + ":")
            lines += [f"    {e}" for e in errors[:3]]
        else:
            lines.append("- " + spec["bug_text"][f])
    lines.append("Please fix these before adding anything new.")
    return "\n".join(lines)


def playtest_plan(features: int) -> dict:
    return {"observe_s": 8 if features <= 1 else 30 if features == 2 else 95,
            "gameover_test": features >= 7}


def cmd_init(a, spec, sdir):
    name, work, store, state_p = paths(a.race, a.condition, a.tag)
    rmtree_force(work.parent)
    shutil.copytree(REPO / spec["scaffold"], work)
    if a.condition == "agentsmd":
        (work / "AGENTS.md").write_text(spec["agents_md"], encoding="utf-8")
        (work / "CLAUDE.md").write_text("@AGENTS.md\n", encoding="utf-8")
    git(work, "init", "-q")
    git(work, "-c", "core.autocrlf=false", "add", "-A")
    git(work, "-c", "user.name=bench", "-c", "user.email=bench@local", "commit", "-q", "-m", "scaffold")
    state = {"race": a.race, "condition": a.condition, "tag": a.tag, "prompts": 0, "features": 0,
             "awaiting_playtest": False, "last_checks": None, "last_errors": [], "done": False, "history": []}
    state_p.write_text(json.dumps(state, indent=1), encoding="utf-8")
    print(f"initialized {work}")


def cmd_next(a, spec, sdir):
    name, work, store, state_p = paths(a.race, a.condition, a.tag)
    st = json.loads(state_p.read_text(encoding="utf-8"))
    if st["done"]:
        print("DONE"); return
    if st["awaiting_playtest"]:
        sys.exit("playtest the last session first (record)")
    if st["prompts"] >= spec["max_prompts"]:
        st["done"] = True; state_p.write_text(json.dumps(st, indent=1), encoding="utf-8"); print("DONE (cap)"); return
    req = required(spec, st["features"])
    failed = [k for k in req if st["last_checks"] is not None and not st["last_checks"].get(k)]
    if failed:
        kind, step_id, prompt = "fix", f"P{st['prompts'] + 1}-fix", bug_prompt(spec, failed, st["last_errors"])
    elif st["features"] < len(spec["roadmap"]):
        f = spec["roadmap"][st["features"]]
        kind, step_id, prompt = "feature", f"P{st['prompts'] + 1}-{f['id']}", f["prompt"]
        st["features"] += 1
    else:
        st["done"] = True; state_p.write_text(json.dumps(st, indent=1), encoding="utf-8"); print("DONE"); return

    pack_text, info = None, {}
    raw_dir = RESULTS / "raw" / name
    raw_dir.mkdir(parents=True, exist_ok=True)
    if a.condition == "devmemory":
        t0 = time.time()
        scan(work, store)
        pack_text, info = build_pack(work, store, prompt, budget=a.budget, mode="full")
        info["pack_build_s"] = round(time.time() - t0, 3)
        (raw_dir / f"{step_id}.pack.md").write_text(pack_text, encoding="utf-8")
    started = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    raw = raw_dir / f"{step_id}.jsonl"
    m = run_claude(prompt, work, raw, model=spec["model"], max_turns=spec["max_turns"],
                   append_system_prompt=pack_text, timeout_s=spec["timeout_s"])
    if a.condition == "devmemory":
        record_session(work, raw, prompt, started, store=store, extra={"race_step": step_id})
    git(work, "-c", "core.autocrlf=false", "add", "-A")
    stat = git(work, "diff", "--cached", "--shortstat").strip()
    git(work, "-c", "user.name=bench", "-c", "user.email=bench@local", "commit", "-q", "-m", step_id)
    st["prompts"] += 1
    st["awaiting_playtest"] = True
    row = {"race": a.race, "condition": a.condition, "tag": a.tag, "step": step_id, "kind": kind, "prompt": prompt,
           "ts": started, "diffstat": stat, "pack_tokens_est": info.get("tokens_est", 0), "pack_stale": info.get("stale", 0),
           **{k: m.get(k) for k in ("exit_code", "num_turns", "cost_usd_list", "wall_s", "input_tokens", "output_tokens",
                                    "cache_read_tokens", "cache_creation_tokens", "total_input_tokens", "tool_calls",
                                    "files_read_unique", "rate_limit")}}
    st["history"].append({"step": step_id, "kind": kind, "cost": m.get("cost_usd_list"), "tok": m.get("total_input_tokens")})
    state_p.write_text(json.dumps(st, indent=1), encoding="utf-8")
    with open(RESULTS / f"adaptive_{a.race}.jsonl", "a", encoding="utf-8") as f:
        f.write(json.dumps({"type": "session", **row}) + "\n")
    plan = playtest_plan(st["features"])
    print(json.dumps({"step": step_id, "kind": kind, "cost": m.get("cost_usd_list"), "tok": m.get("total_input_tokens"),
                      "turns": m.get("num_turns"), "diff": stat, "playtest": plan}))


def cmd_record(a, spec, sdir):
    name, work, store, state_p = paths(a.race, a.condition, a.tag)
    st = json.loads(state_p.read_text(encoding="utf-8"))
    server, client = json.loads(a.server), json.loads(a.client)
    gameover = json.loads(a.gameover) if a.gameover else None
    checks, errors = compute_checks(spec, server, client, gameover)
    req = required(spec, st["features"])
    failed = [k for k in req if not checks.get(k)]
    st["last_checks"], st["last_errors"], st["awaiting_playtest"] = checks, errors, False
    step_id = st["history"][-1]["step"]
    st["history"][-1].update(failed=failed)
    if not failed and st["features"] >= len(spec["roadmap"]):
        st["done"] = True
    state_p.write_text(json.dumps(st, indent=1), encoding="utf-8")
    with open(RESULTS / f"adaptive_{a.race}.jsonl", "a", encoding="utf-8") as f:
        f.write(json.dumps({"type": "playtest", "race": a.race, "condition": a.condition, "tag": a.tag, "step": step_id,
                            "required": req, "failed": failed, "checks": checks, "errors": errors[:5],
                            "server": server, "client": {k: v for k, v in client.items() if k != "sample"},
                            "gameover": gameover}) + "\n")
    print(json.dumps({"step": step_id, "failed": failed, "errors": errors[:2], "done": st["done"]}))


def cmd_status(a, spec, sdir):
    for cond in ("none", "agentsmd", "devmemory"):
        _, _, _, sp = paths(a.race, cond, a.tag)
        if not sp.exists():
            continue
        st = json.loads(sp.read_text(encoding="utf-8"))
        cost = sum(h.get("cost") or 0 for h in st["history"])
        tok = sum(h.get("tok") or 0 for h in st["history"])
        print(f"{cond:10} prompts={st['prompts']} features={st['features']} cost=${cost:.2f} tok={tok/1000:.0f}k "
              f"done={st['done']} awaiting={st['awaiting_playtest']} last_failed={st['history'][-1].get('failed') if st['history'] else None}")


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["init", "next", "record", "status"])
    ap.add_argument("--race", required=True)
    ap.add_argument("--condition", choices=["none", "agentsmd", "devmemory"])
    ap.add_argument("--tag", default="r1")
    ap.add_argument("--budget", type=int, default=2000)
    ap.add_argument("--server")
    ap.add_argument("--client")
    ap.add_argument("--gameover")
    a = ap.parse_args(argv)
    sdir = REPO / "bench" / "adaptive" / a.race
    spec = load(sdir)
    {"init": cmd_init, "next": cmd_next, "record": cmd_record, "status": cmd_status}[a.cmd](a, spec, sdir)


if __name__ == "__main__":
    main()
