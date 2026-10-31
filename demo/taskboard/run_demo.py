"""Start the three task boards from web race round 2, fill each with the same cards, open them side by side.

Usage: python demo/taskboard/run_demo.py   (Ctrl+C stops the servers)
Each app keeps its data in demo/taskboard/<condition>/data/, which is reset on every start.
"""
import json
import shutil
import subprocess
import sys
import time
import urllib.request
from datetime import date, timedelta
from pathlib import Path

HERE = Path(__file__).resolve().parent
APPS = {"none": 4101, "agentsmd": 4102, "devmemory": 4103}
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

d = lambda n: (date.today() + timedelta(days=n)).isoformat()
CARDS = [
    ("Fix login redirect loop on Safari", "In Progress", "Bug", d(-2), "Alice"),
    ("Add CSV export to reports page", "In Progress", "Feature", d(3), "Bob"),
    ("Upgrade Node to v22 on staging", "In Progress", "Chore", d(0), "Dan"),
    ("Dark mode for settings page", "To Do", "Feature", d(7), "Carol"),
    ("Crash when uploading a 0-byte file", "To Do", "Bug", d(1), "Bob"),
    ("Write onboarding checklist", "To Do", "Chore", d(5), "Alice"),
    ("Keyboard shortcuts for card actions", "To Do", "Feature", None, None),
    ("Rotate API keys", "To Do", "Chore", d(-1), "Dan"),
    ("Drag and drop between columns", "Done", "Feature", None, "Carol"),
    ("Timezone bug in due dates", "Done", "Bug", None, "Alice"),
    ("Set up CI pipeline", "Done", "Chore", None, "Bob"),
]


def post(base, card):
    title, column, label, due, who = card
    body = {"title": title, "column": column, "label": label, "dueDate": due, "assignee": who}
    req = urllib.request.Request(base + "/api/cards", json.dumps(body).encode(), {"Content-Type": "application/json"}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=5) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code


def main():
    procs = []
    for name, port in APPS.items():
        app = HERE / name
        shutil.rmtree(app / "data", ignore_errors=True)
        log = open(app / "_server.log", "w", encoding="utf-8")
        procs.append(subprocess.Popen(["node", "server.js"], cwd=app, stdout=log, stderr=subprocess.STDOUT,
                                      env={**__import__("os").environ, "PORT": str(port)}))
    time.sleep(1.5)
    for name, port in APPS.items():
        codes = [post(f"http://127.0.0.1:{port}", c) for c in CARDS]
        print(f"{name:10s} http://127.0.0.1:{port}  seeded {codes.count(201) + codes.count(200)}/{len(CARDS)}  {codes}")
    if "--no-open" not in sys.argv:
        for i, (name, port) in enumerate(APPS.items()):
            subprocess.Popen([CHROME, f"--app=http://127.0.0.1:{port}/", f"--user-data-dir={HERE / '.chrome' / name}",
                              "--window-size=900,1000", f"--window-position={i * 640},0"])
    print("Running. Ctrl+C to stop.")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        for p in procs:
            p.terminate()


if __name__ == "__main__":
    main()
