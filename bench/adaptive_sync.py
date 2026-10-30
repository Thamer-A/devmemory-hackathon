"""Verify a race Studio window holds exactly the code on disk (guards against a dead Rojo server).

Studio side (Edit datamodel), run via the Studio MCP:
    local out = {}
    for _, root in ipairs({game.ReplicatedStorage:FindFirstChild("Shared"), game.ServerScriptService:FindFirstChild("Server"),
                          game.StarterPlayer.StarterPlayerScripts:FindFirstChild("Client")}) do
        if root then for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("LuaSourceContainer") then table.insert(out, {d.Name, #d.Source}) end end end
    end
    return game:GetService("HttpService"):JSONEncode(out)

  python -m bench.adaptive_sync --race blade --condition none --studio '<json>'
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from collections import Counter
from pathlib import Path

EXTS = (".server.luau", ".client.luau", ".server.lua", ".client.lua", ".luau", ".lua")


def disk_manifest(project: Path) -> Counter:
    c = Counter()
    for sub in ("shared", "server", "client"):
        root = project / "src" / sub
        for p in root.rglob("*"):
            if not p.is_file():
                continue
            name = p.name
            ext = next((e for e in EXTS if name.endswith(e)), None)
            if not ext:
                continue
            stem = name[: -len(ext)]
            if stem == "init":
                stem = p.parent.name if p.parent != root else {"shared": "Shared", "server": "Server", "client": "Client"}[sub]
            c[(stem, len(p.read_bytes()))] += 1
    return c


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--race", required=True)
    ap.add_argument("--condition", required=True)
    ap.add_argument("--tag", default="r1")
    ap.add_argument("--studio", required=True)
    a = ap.parse_args()
    project = Path(os.environ.get("TEMP", "/tmp")) / "devmem-runs" / f"adaptive_{a.race}_{a.condition}_{a.tag}" / "project"
    studio = Counter((n, l) for n, l in json.loads(a.studio))
    disk = disk_manifest(project)
    missing, extra = disk - studio, studio - disk
    if not missing and not extra:
        print(f"SYNC OK ({sum(disk.values())} scripts)")
        return 0
    print("SYNC MISMATCH  missing-in-studio:", sorted(missing), " extra-in-studio:", sorted(extra))
    return 1


if __name__ == "__main__":
    sys.exit(main())
