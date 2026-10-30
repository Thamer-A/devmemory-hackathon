"""On-disk layout of the memory store (plain files under <project>/.devmemory/) and file hashing."""
from __future__ import annotations

import fnmatch
import hashlib
import os
from pathlib import Path

STORE_DIR = ".devmemory"
DEFAULT_IGNORES = [
    ".git", ".devmemory", "node_modules", "__pycache__", ".venv", "venv", "dist", "build", "out",
    ".idea", ".vscode", "*.pyc", "*.rbxl", "*.rbxlx", "*.rbxm", "*.rbxmx", "*.png", "*.jpg", "*.jpeg",
    "*.gif", "*.ogg", "*.mp3", "*.wav", "*.fbx", "*.obj", "*.zip", "*.exe", "*.dll",
    # secrets: never index or hash these
    ".env", ".env.*", "*.pem", "*.key", "id_rsa*", "*secret*", "*credentials*",
]
MAX_TEXT_BYTES = 512_000


def store_path(project: Path) -> Path:
    return Path(project) / STORE_DIR


def load_ignores(project: Path) -> list[str]:
    pats = list(DEFAULT_IGNORES)
    extra = store_path(project) / "ignore"
    if extra.exists():
        pats += [l.strip() for l in extra.read_text(encoding="utf-8").splitlines()
                 if l.strip() and not l.startswith("#")]
    return pats


def is_ignored(rel: str, patterns: list[str]) -> bool:
    parts = rel.split("/")
    for pat in patterns:
        if any(fnmatch.fnmatch(p, pat) for p in parts) or fnmatch.fnmatch(rel, pat):
            return True
    return False


def iter_files(project: Path):
    """Yield project-relative POSIX paths of text-indexable files, honouring ignores."""
    project = Path(project)
    pats = load_ignores(project)
    for root, dirs, files in os.walk(project):
        rel_root = Path(root).relative_to(project).as_posix()
        rel_root = "" if rel_root == "." else rel_root + "/"
        dirs[:] = sorted(d for d in dirs if not is_ignored(rel_root + d, pats))
        for name in sorted(files):
            rel = rel_root + name
            if not is_ignored(rel, pats):
                yield rel


def file_hash(path: Path) -> str | None:
    """Line-ending-insensitive content hash (CRLF vs LF must not mark memory stale)."""
    try:
        data = Path(path).read_bytes()
    except OSError:
        return None
    return hashlib.sha256(data.replace(b"\r\n", b"\n")).hexdigest()[:16]


def hash_files(project: Path, rels) -> dict[str, str | None]:
    return {r: file_hash(Path(project) / r) for r in sorted(set(rels))}


def estimate_tokens(text: str) -> int:
    """Rough token estimate (chars/4). Labelled as an estimate wherever reported."""
    return max(1, len(text) // 4) if text else 0
