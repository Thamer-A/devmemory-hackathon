"""Build a playable Roblox place from the P1 benchmark game, for the demo.

  python demo/build_demo.py [--game bench/projects/P1/game] [--rojo PATH]

Copies the game's source into demo/build/src (the benchmark fixture is never modified), patches
the COPY of DataService so an unpublished place in Studio falls back to in-memory data instead
of kicking the player (DataStores need a published place with API access), and runs `rojo build`
with demo/CoinRush.demo.project.json (adds baseplate, spawn, CoinZone, EnemySpawns).
Output: demo/build/CoinRush.rbxlx -> open it in Roblox Studio and press Play.
"""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
DEFAULT_ROJO = Path.home() / "tools" / "rojo-7.7.1" / "rojo.exe"

STORE_LINE = "local store = DataStoreService:GetDataStore(Config.DataStoreName)"
STORE_PATCH = '''-- [demo build] unpublished places in Studio cannot open DataStores; keep data in memory instead
local okStore, store = pcall(function()
	return DataStoreService:GetDataStore(Config.DataStoreName)
end)
if not okStore then
	Log.warn("DataService", "DataStore unavailable (unpublished place?); using in-memory data")
	local memory = {}
	store = {
		GetAsync = function(_, key)
			return memory[key]
		end,
		SetAsync = function(_, key, value)
			memory[key] = value
		end,
		UpdateAsync = function(_, key, fn)
			memory[key] = fn(memory[key])
			return memory[key]
		end,
	}
end'''
LOAD_FAIL = "\t\ttask.wait(Config.DataRetryDelay)\n\tend\n\treturn nil\nend"
LOAD_PATCH = ("\t\ttask.wait(Config.DataRetryDelay)\n\tend\n"
              "\tif game:GetService(\"RunService\"):IsStudio() then\n"
              "\t\tLog.warn(\"DataService\", \"[demo build] using fresh data in Studio for\", player.Name)\n"
              "\t\treturn reconcile(nil)\n\tend\n\treturn nil\nend")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--game", default=str(REPO / "bench" / "projects" / "P1" / "game"))
    ap.add_argument("--rojo", default=str(DEFAULT_ROJO))
    a = ap.parse_args()
    game = Path(a.game)
    build = HERE / "build"
    src = build / "src"
    if src.exists():
        shutil.rmtree(src)
    shutil.copytree(game / "src", src)
    (build / "assets").mkdir(parents=True, exist_ok=True)
    shutil.copyfile(game / "assets" / "manifest.json", build / "assets" / "manifest.json")

    ds = src / "server" / "services" / "DataService.luau"
    text = ds.read_text(encoding="utf-8")
    for old, new in ((STORE_LINE, STORE_PATCH), (LOAD_FAIL, LOAD_PATCH)):
        if old not in text:
            print(f"warning: DataService patch point not found: {old[:50]!r}", file=sys.stderr)
        text = text.replace(old, new, 1)
    ds.write_text(text, encoding="utf-8", newline="\n")

    out = build / "CoinRush.rbxlx"
    r = subprocess.run([a.rojo, "build", str(HERE / "CoinRush.demo.project.json"), "-o", str(out)])
    if r.returncode == 0:
        print(f"built {out}")
    return r.returncode


if __name__ == "__main__":
    sys.exit(main())
