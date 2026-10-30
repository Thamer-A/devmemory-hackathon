"""Run `adaptive_run next` for several conditions concurrently and wait for all of them.

  python -m bench.adaptive_parallel --race blade --conditions none,agentsmd,devmemory
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor


def step(race: str, cond: str) -> str:
    p = subprocess.run([sys.executable, "-m", "bench.adaptive_run", "next", "--race", race, "--condition", cond],
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    out = (p.stdout.strip().splitlines() or [""])[-1]
    return f"{cond}: {out[:400]}" + (f" STDERR: {p.stderr[-300:]}" if p.returncode else "")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--race", required=True)
    ap.add_argument("--conditions", default="none,agentsmd,devmemory")
    a = ap.parse_args()
    conds = [c for c in a.conditions.split(",") if c]
    with ThreadPoolExecutor(max_workers=len(conds)) as ex:
        for line in ex.map(lambda c: step(a.race, c), conds):
            print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
