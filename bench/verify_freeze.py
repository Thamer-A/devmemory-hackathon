"""Check that the held-out tasks are byte-identical to the frozen set (bench/HELDOUT_FREEZE.txt).

  python -m bench.verify_freeze                          (first held-out set)
  python -m bench.verify_freeze HELDOUT2_FREEZE.txt      (second held-out set)
"""
from __future__ import annotations

import hashlib
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent


def main() -> int:
    name = sys.argv[1] if len(sys.argv) > 1 else "HELDOUT_FREEZE.txt"
    lines = (REPO / "bench" / name).read_text(encoding="utf-8").splitlines()
    entries = [l for l in lines if l.strip() and not l.startswith("TOTAL")]
    total = next(l.split()[1] for l in lines if l.startswith("TOTAL"))
    bad = 0
    for l in entries:
        digest, rel = l.split(None, 1)
        p = REPO / rel.strip()
        if not p.exists():  # freeze file lists paths relative to bench/
            p = REPO / "bench" / rel.strip()
        # accept either line-ending form: the freeze hashed the working copy, git may check out LF or CRLF
        if p.exists():
            raw = p.read_bytes()
            lf = raw.replace(b"\r\n", b"\n")
            forms = {hashlib.sha256(x).hexdigest() for x in (raw, lf, lf.replace(b"\n", b"\r\n"))}
        else:
            forms = set()
        if digest not in forms:
            bad += 1
            print(f"CHANGED {rel}")
    joined = hashlib.sha256("\n".join(entries).encode()).hexdigest()
    joined_nl = hashlib.sha256(("\n".join(entries) + "\n").encode()).hexdigest()
    print(f"{len(entries)} files, {bad} changed; TOTAL recorded {total[:16]}…, "
          f"recomputed {'match' if total in (joined, joined_nl) else 'differs (format)'}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
