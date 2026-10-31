"""`devmem app`: run the UI server on a free port and show it in a standalone Chrome/Edge app window."""
from __future__ import annotations

import os
import shlex
import subprocess
import sys
import threading
import webbrowser
from pathlib import Path

from .ui_server import make_server

BROWSERS = [r"C:\Program Files\Google\Chrome\Application\chrome.exe",
            r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
            r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
            r"C:\Program Files\Microsoft\Edge\Application\msedge.exe"]


def find_browser() -> str | None:
    for b in BROWSERS:
        if Path(b).is_file():
            return b
    return None


def profile_dir() -> Path:
    return Path(os.environ.get("LOCALAPPDATA") or Path.home() / ".cache") / "DevMemory" / "browser"


def browser_command(url: str, exe: str | None = None) -> list[str] | None:
    exe = exe or find_browser()
    if not exe:
        return None
    return [exe, f"--app={url}", f"--user-data-dir={profile_dir()}", "--window-size=1440,900", "--no-first-run",
            "--no-default-browser-check"]


def run_app(project: Path | None, store: Path | None, dry_run: bool = False, port: int = 0) -> int:
    srv, st = make_server(project, store, port)
    url = f"http://127.0.0.1:{srv.server_address[1]}/"
    cmd = browser_command(url)
    if dry_run:
        print(url)
        print(" ".join(shlex.quote(c) if " " in c else c for c in cmd) if cmd else "(no Chrome/Edge found: would use webbrowser.open)")
        srv.server_close()
        return 0
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    try:
        if cmd:
            profile_dir().mkdir(parents=True, exist_ok=True)
            proc = subprocess.Popen(cmd)
            # Chrome may hand off to an already-running instance on the same profile and exit quickly;
            # with a dedicated user-data-dir the launched process normally stays alive until the window closes.
            proc.wait()
        else:
            webbrowser.open(url)
            print(f"DevMemory running at {url}  (Ctrl+C to stop)", flush=True)
            threading.Event().wait()
    except KeyboardInterrupt:
        pass
    finally:
        srv.shutdown()
        srv.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(run_app(None, None))
