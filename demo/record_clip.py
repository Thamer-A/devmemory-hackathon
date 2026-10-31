"""Record one Roblox Studio window for the demo video.

  python demo/record_clip.py none 30        # records the window whose title contains "none.rbxl" for 30 s
  python demo/record_clip.py agentsmd 30
  python demo/record_clip.py devmemory 30

Brings the Studio window to the front, counts down 3 s, then records at 60 fps to demo/footage/<name>_<n>.mp4.
Press Play (F5) in that Studio window first.
"""
import ctypes
import subprocess
import sys
import time
from pathlib import Path

OUT = Path(__file__).resolve().parent / "footage"


def find_window(fragment):
    titles = []
    proto = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)

    def cb(hwnd, _):
        n = ctypes.windll.user32.GetWindowTextLengthW(hwnd)
        if n and ctypes.windll.user32.IsWindowVisible(hwnd):
            buf = ctypes.create_unicode_buffer(n + 1)
            ctypes.windll.user32.GetWindowTextW(hwnd, buf, n + 1)
            if fragment.lower() in buf.value.lower() and "Roblox Studio" in buf.value:
                titles.append((hwnd, buf.value))
        return True
    ctypes.windll.user32.EnumWindows(proto(cb), 0)
    return titles[0] if titles else (None, None)


def main():
    name = sys.argv[1]
    secs = int(sys.argv[2]) if len(sys.argv) > 2 else 30
    hwnd, title = find_window(f"{name}.rbxl")
    if not hwnd:
        sys.exit(f"no Roblox Studio window with {name}.rbxl in its title")
    ctypes.windll.user32.ShowWindow(hwnd, 3)  # maximize
    ctypes.windll.user32.SetForegroundWindow(hwnd)
    OUT.mkdir(exist_ok=True)
    n = len(list(OUT.glob(f"{name}_*.mp4"))) + 1
    out = OUT / f"{name}_{n}.mp4"
    for i in (3, 2, 1):
        print(f"recording {name} in {i}...", flush=True)
        time.sleep(1)
    print(f"RECORDING {secs}s -> {out}", flush=True)
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "gdigrab", "-framerate", "60",
                    "-draw_mouse", "0", "-i", f"title={title}", "-t", str(secs),
                    "-c:v", "libx264", "-preset", "veryfast", "-crf", "18", "-pix_fmt", "yuv420p", str(out)])
    print("done:", out)


if __name__ == "__main__":
    main()
