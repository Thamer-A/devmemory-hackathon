"""Record the live demo clips (Windows): real DevMemory and Claude Code running on Blade Swarm.

  python demo/live/record_live.py terminal   # devmem scan + devmem pack for the Twin Spin request
  python demo/live/record_live.py claude     # live Claude Code session with the DevMemory hook (makes the edit)
  python demo/live/record_live.py app        # the DevMemory app: vault -> session 8 -> Pack Lab

The project is ~/devmem-live/blade-swarm: Blade Swarm at race commit 845da2a (P8-R5, just before the
Twin Spin prompt) with DevMemory's memory as it was then (sessions 1-8). Clips go to demo/footage/live_*.mp4.
Do not touch the mouse or keyboard while a clip records.
"""
import ctypes
import ctypes.wintypes as wt
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
LIVE = Path.home() / "devmem-live" / "blade-swarm"
OUT = REPO / "demo" / "footage"
TASK = "Add an Epic upgrade called Twin Spin: +2 blades for 120 coins. Make sure it shows up with the rarity colors we picked."
u32 = ctypes.windll.user32
ctypes.windll.shcore.SetProcessDpiAwareness(2)  # real pixels, so window rects match what ffmpeg captures


def windows():
    found = []
    proto = ctypes.WINFUNCTYPE(ctypes.c_bool, wt.HWND, wt.LPARAM)

    def cb(h, _):
        if u32.IsWindowVisible(h):
            n = u32.GetWindowTextLengthW(h)
            buf = ctypes.create_unicode_buffer(n + 1)
            u32.GetWindowTextW(h, buf, n + 1)
            cls = ctypes.create_unicode_buffer(256)
            u32.GetClassNameW(h, cls, 256)
            found.append((h, buf.value, cls.value))
        return True
    u32.EnumWindows(proto(cb), 0)
    return found


def wait_window(pred, before=(), timeout=20):
    t0 = time.time()
    while time.time() - t0 < timeout:
        for h, title, cls in windows():
            if h not in before and pred(title, cls):
                return h
        time.sleep(0.3)
    sys.exit("window did not appear")


def rect(h):
    r = wt.RECT()
    u32.GetWindowRect(h, ctypes.byref(r))
    return r.left, r.top, r.right - r.left, r.bottom - r.top


def focus(h):
    for _ in range(3):  # maximize, and wait until the size has settled before anything measures it
        u32.ShowWindow(h, 3)
        u32.keybd_event(0x12, 0, 0, 0)  # tap Alt: Windows only lets the foreground window change after input
        u32.keybd_event(0x12, 0, 2, 0)
        u32.SetForegroundWindow(h)
        u32.BringWindowToTop(h)
        time.sleep(0.8)


def key(vk, mods=()):
    for m in mods:
        u32.keybd_event(m, 0, 0, 0)
    u32.keybd_event(vk, 0, 0, 0)
    u32.keybd_event(vk, 0, 2, 0)
    for m in reversed(mods):
        u32.keybd_event(m, 0, 2, 0)
    time.sleep(0.05)


def paste(text):
    subprocess.run(["powershell", "-NoProfile", "-Command", "Set-Clipboard -Value $input"], input=text, text=True)
    key(0x56, (0x11,))  # Ctrl+V


def click(x, y):
    u32.SetCursorPos(int(x), int(y))
    time.sleep(0.15)
    u32.mouse_event(2, 0, 0, 0, 0)
    u32.mouse_event(4, 0, 0, 0, 0)
    time.sleep(0.3)


def record(h, name, secs_max, done=None, tail=6):
    x, y, w, hgt = rect(h)
    sw, sh = u32.GetSystemMetrics(0), u32.GetSystemMetrics(1)
    x2, y2 = min(x + w, sw), min(y + hgt, sh)
    x, y = max(x, 0), max(y, 0)
    w, hgt = x2 - x, y2 - y
    w, hgt = w - w % 2, hgt - hgt % 2
    out = OUT / f"live_{name}.mp4"
    p = subprocess.Popen(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "gdigrab", "-framerate", "30",
                          "-offset_x", str(x), "-offset_y", str(y), "-video_size", f"{w}x{hgt}", "-draw_mouse", "1",
                          "-i", "desktop", "-c:v", "libx264", "-preset", "veryfast", "-crf", "20", "-pix_fmt", "yuv420p",
                          str(out)], stdin=subprocess.PIPE)
    return p, out


def stop(p):
    try:
        p.stdin.write(b"q")
        p.stdin.flush()
    except OSError:
        pass
    p.wait(20)


def terminal_window(command):
    before = {h for h, *_ in windows()}
    subprocess.Popen(["wt", "-w", "new", "powershell", "-NoLogo", "-NoExit", "-Command", command])
    h = wait_window(lambda t, c: c == "CASCADIA_HOSTING_WINDOW_CLASS", before)
    focus(h)
    for _ in range(3):  # larger font for the video
        key(0xBB, (0x11,))  # Ctrl+=
    time.sleep(0.8)
    focus(h)
    return h


def clip_terminal():
    ps = REPO / "demo" / "live" / "type_demo.ps1"
    h = terminal_window(f"& '{ps}'")
    p, out = record(h, "terminal", 60)
    marker = Path.home() / "devmem-live" / "terminal_done.txt"
    marker.unlink(missing_ok=True)
    t0 = time.time()
    while not marker.exists() and time.time() - t0 < 90:
        time.sleep(0.5)
    time.sleep(4)
    stop(p)
    u32.PostMessageW(h, 0x0010, 0, 0)  # WM_CLOSE
    print("saved", out)


def clip_claude():
    cfg = LIVE / "src" / "shared" / "Config.lua"
    claude = subprocess.run([sys.executable, "-c", "from devmem.claude_cli import claude_executable as c; print(c())"],
                            cwd=REPO, capture_output=True, text=True).stdout.strip()
    # wt treats ';' as its own separator, so the session is started from a script file
    ps = Path.home() / "devmem-live" / "run_claude.ps1"
    # fresh environment: the new terminal may inherit CLAUDE_CODE_* markers from a parent Claude Code session
    clean = "Get-ChildItem Env: | Where-Object { $_.Name -like 'CLAUDE_CODE*' -or $_.Name -eq 'CLAUDECODE' } | " \
            "ForEach-Object { Remove-Item \"Env:$($_.Name)\" }"
    # the prompt goes first: --disallowedTools takes a list and would swallow the words after it
    ps.write_text(f"{clean}\nSet-Location '{LIVE}'\nClear-Host\n& '{claude}' \"{TASK}\" --model sonnet "
                  f"--permission-mode acceptEdits --disallowedTools Bash\n", encoding="utf-8")
    import json
    trusted = json.loads((Path.home() / ".claude.json").read_text(encoding="utf-8")).get("projects", {}) \
        .get(LIVE.as_posix(), {}).get("hasTrustDialogAccepted")
    h = terminal_window(f"& '{ps}'")
    p, out = record(h, "claude", 240)
    time.sleep(5)
    if not trusted:
        key(0x28)  # trust prompt: move from "No, exit" to "Yes, I trust this folder"
        time.sleep(0.4)
        key(0x0D)
    t0, seen = time.time(), None
    while time.time() - t0 < 230:
        if "TwinSpin" in cfg.read_text(encoding="utf-8") or "Twin Spin" in cfg.read_text(encoding="utf-8"):
            seen = seen or time.time()
            if time.time() - seen > 25:  # let it finish its summary
                break
        time.sleep(1)
    stop(p)
    u32.PostMessageW(h, 0x0010, 0, 0)
    print("saved", out, "| edit made:", seen is not None)


def clip_app():
    port = 8793
    srv = subprocess.Popen([sys.executable, "-m", "devmem.cli", "ui", "--project", str(LIVE), "--port", str(port),
                            "--no-browser"], cwd=REPO, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(2.5)
    chrome = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
    from urllib.parse import quote
    # Three views of the same app, opened by its own deep links (clicking by screen position is fragile with
    # display scaling): the vault overview, session 8, and Pack Lab building the pack for the Twin Spin request.
    views = [("app1", "?open=overview", 7, 0), ("app2", "?open=session:3e2bb0e2-ef67-4b5c-a255-a72a1f7c1080", 8, 2),
             ("app3", f"?open=pack&task={quote(TASK)}", 12, 5)]
    for name, q, secs, scrolls in views:
        before = {h for h, *_ in windows()}
        subprocess.Popen([chrome, f"--app=http://127.0.0.1:{port}/{q}",
                          f"--user-data-dir={Path.home() / 'devmem-live' / 'chrome'}"])
        h = wait_window(lambda t, c: c.startswith("Chrome_WidgetWin") and ("DevMemory" in t or "127.0.0.1" in t), before)
        focus(h)
        p, out = record(h, name, secs)
        x0, y0, w, hgt = rect(h)
        u32.SetCursorPos(x0 + w // 2, y0 + hgt // 2)
        time.sleep(secs - scrolls * 0.8 - 1)
        for _ in range(scrolls):
            u32.mouse_event(0x0800, 0, 0, ctypes.c_ulong(-240 & 0xFFFFFFFF).value, 0)  # wheel down
            time.sleep(0.8)
        time.sleep(1)
        stop(p)
        u32.PostMessageW(h, 0x0010, 0, 0)
        time.sleep(1.5)
        print("saved", out)
    srv.terminate()


if __name__ == "__main__":
    OUT.mkdir(exist_ok=True)
    {"terminal": clip_terminal, "claude": clip_claude, "app": clip_app}[sys.argv[1]]()
