"""Build the demo video from footage, screenshots and slides (ffmpeg only).

  python demo/video/build_video.py                 # rough cut, script timings, no audio
  python demo/video/build_video.py --vo VO.wav     # with voice-over; durations from demo/video/timings.json if present

Sections follow docs/VIDEO_SCRIPT.md. Output: demo/video/out/DevMemory_demo.mp4
"""
import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "demo" / "video" / "out"
FOOT = REPO / "demo" / "footage"
FONT = "C\\:/Windows/Fonts/calibrib.ttf"
FONT_R = "C\\:/Windows/Fonts/calibri.ttf"
BG, VIO, CY, GRN, WARN, TXT, MUT = "0x0F1115", "0x8B7CF6", "0x38D6E8", "0x3DD68C", "0xF5A524", "0xEDEDED", "0x9AA0AA"
GAME_CROP = "crop=1910:768:5:218"  # Studio game view inside the maximized 1920x1094 window
CLIPS = {"none": "none_2.mp4", "agentsmd": "agentsmd_2.mp4", "devmemory": "devmemory_1.mp4"}
DUR = {"hook": 12, "input": 28, "action": 28, "output": 20, "race": 22, "heldout": 16, "also": 9, "close": 12}
MONO = "C\\:/Windows/Fonts/consola.ttf"
SHOTS = REPO / "docs" / "app-screens"


def esc(t):
    lead = len(t) - len(t.lstrip(" "))
    t = " " * lead + t[lead:]  # drawtext strips leading spaces; keep code indentation
    return t.replace("\\", "\\\\").replace(":", "\\:").replace("'", "’").replace(",", "\\,")


def text(t, x, y, size, color=TXT, font=FONT, start=0.0, fade=0.5, box=False, end=None):
    alpha = f"if(lt(t\\,{start})\\,0\\,min(1\\,(t-{start})/{fade}))"
    if end is not None:  # fade out after `end`
        alpha = f"if(gt(t\\,{end})\\,max(0\\,1-(t-{end})/{fade})\\,{alpha})"
    b = ":box=1:boxcolor=0x0F1115@0.72:boxborderw=18" if box else ""
    return (f"drawtext=fontfile='{font}':expansion=none:text='{esc(t)}':x={x}:y={y}:fontsize={size}:fontcolor={color}"
            f":alpha='{alpha}'{b}")


def run(args):
    r = subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *args], capture_output=True, text=True)
    if r.returncode:
        sys.exit(r.stderr[-3000:])


def enc(out):
    return ["-r", "30", "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", "-an", str(out)]


def seg_hook(d, out):
    v = (f"[0:v]{GAME_CROP},crop=1365:768:272:0,scale=1920:1080,setsar=1,"
         f"{text('Thamer Alhussain', '(w-text_w)/2', 'h*0.36', 84, start=0.3, end=7.6, box=True)},"
         f"{text('Challenge 2: Deliver AI with Less Compute  ·  DevMemory', '(w-text_w)/2', 'h*0.50', 46, color=CY, start=1.0, end=7.6, box=True)},"
         f"{text('Every AI coding session starts cold.', '(w-text_w)/2', 'h*0.74', 72, start=8.4, box=True)},"
         f"{text('It forgets what you decided, and what you asked for.', '(w-text_w)/2', 'h*0.86', 44, color=CY, start=12, box=True)}[v]")
    run(["-ss", "6", "-t", str(d), "-i", FOOT / CLIPS["devmemory"], "-filter_complex", v, "-map", "[v]", *enc(out)])


def seg_app(d, out):
    shots = ["overview.png", "session_note.png", "jsonl.png", "graph.png", "project_md.png"]
    caps = ["Scan  ·  Capture  ·  Pack  ·  Deliver", "Every session as a note: the user's own words", "The raw record, kept in full",
            "Files, sessions and decisions, linked", "A project map built with 0 AI tokens"]
    per = d / len(shots)
    ins, fc = [], []
    for i, s in enumerate(shots):
        ins += ["-i", REPO / "docs" / "app-screens" / s]  # single frame: zoompan emits d frames from it
        frames = int(per * 30)
        fc.append(f"[{i}:v]scale=2400:-2,crop=2400:1350,zoompan=z='min(zoom+0.0006\\,1.08)':d={frames}:s=1920x1080:fps=30,"
                  f"{text(caps[i], '(w-text_w)/2', 'h-150', 52, start=0.3, box=True)},setsar=1[s{i}]")
    fc.append("".join(f"[s{i}]" for i in range(len(shots))) + f"concat=n={len(shots)}:v=1:a=0[v]")
    run([*ins, "-filter_complex", ";".join(fc), "-map", "[v]", *enc(out)])


def shot(img, crop, d, out, caps, box=None):
    """One screenshot: crop (w:h:x:y in source pixels, 16:9), slow zoom, timed captions, optional highlight box."""
    frames = int(d * 30)
    w = int(crop.split(":")[0])
    k = 1920 / w
    f = [f"[0:v]crop={crop},scale=1920:1080,zoompan=z='min(zoom+0.0003\\,1.04)':d={frames}:s=1920x1080:fps=30,setsar=1"]
    if box:
        bx, by, bw, bh, t0 = box
        f.append(f"drawbox=x={int(bx*k)}:y={int(by*k)}:w={int(bw*k)}:h={int(bh*k)}:color={VIO}:t=6:enable='gte(t\\,{t0})'")
    for c, t0 in caps:
        f.append(text(c, "(w-text_w)/2", "h-130", 50, start=t0, box=True))
    run(["-i", SHOTS / img, "-filter_complex", ",".join(f) + "[v]", "-map", "[v]", "-t", str(d), *enc(out)])


def card(lines, d, out, panels=()):
    """Text card on the dark background. lines: (text, y, size, color, font, start[, x]); x defaults to centred.
    panels: (x, y, w, h, border_color) rounded-looking boxes drawn first."""
    draws = [f"drawbox=x={x}:y={y}:w={w}:h={h}:color=0x161A22:t=fill,drawbox=x={x}:y={y}:w={w}:h={h}:color={c}:t=3"
             for x, y, w, h, c in panels]
    for ln in lines:
        t, y, sz, c, fn, st = ln[:6]
        x = ln[6] if len(ln) > 6 else "(w-text_w)/2"
        draws.append(text(t, x, y, sz, color=c, font=fn, start=st))
    run(["-f", "lavfi", "-i", f"color=c={BG}:s=1920x1080:d={d}:r=30", "-filter_complex", "[0:v]" + ",".join(draws) + "[v]",
         "-map", "[v]", *enc(out)])


def seg_input_roblox(d, out):
    """Held-out task P1 H2: the plan exists only in an earlier session."""
    a, b = OUT / "_rin_a.mp4", OUT / "_rin_b.mp4"
    d1 = round(d * 0.62, 2); d2 = round(d - d1, 2)
    card([("Earlier session  ·  our Roblox benchmark game (CoinRush)  ·  planning only, no code", 170, 44, MUT, FONT_R, 0.2),
          ("\"Let's plan the daily login reward. Decisions we agreed on:", 290, 40, TXT, FONT_R, 0.8, 240),
          ("coins are granted only through CurrencyService.add  (reason \"daily_reward\")", 370, 38, TXT, FONT_R, 1.6, 300),
          ("the day boundary is 00:00 UTC", 430, 38, TXT, FONT_R, 2.2, 300),
          ("reward is 20 coins plus 10 per streak day", 490, 38, GRN, FONT, 2.8, 300),
          ("the streak caps at 7 days, as a new Config.DailyStreakCap = 7\"", 550, 38, GRN, FONT, 3.4, 300),
          ("Nothing is written to the code yet. The plan lives only in that conversation.", 720, 38, CY, FONT, 6.0)],
         d1, a, panels=[(200, 250, 1520, 380, "0x5A606B")])
    card([("Days later, a brand-new session gets one line:", 330, 46, MUT, FONT_R, 0.2),
          ("\"Add the daily reward payout calculation from the plan we made", 450, 52, TXT, FONT, 0.8),
          ("as a shared module, DailyReward.coinsFor(streak).\"", 520, 52, TXT, FONT, 0.8),
          ("It has never seen the plan.", 680, 46, WARN, FONT, 3.0)], d2, b)
    concat([a, b], out)


def seg_action_roblox(d, out):
    """The actual pack delivered for that run (results/raw/heldout/heldout_P1-H2_C3_haiku_r0_*.pack.md), excerpt."""
    X = 150
    lines = [("DevMemory builds a pack for this request  ·  0 AI tokens  ·  actual pack, excerpt", 90, 40, TXT, FONT, 0.2),
             ("# DevMemory context pack     Project: game (roblox, rojo)", 200, 28, CY, MONO, 0.8, X),
             ("## Conventions (observed in code)", 260, 28, VIO, MONO, 1.6, X),
             ("- `data.coins writes` occur only in CurrencyService / DataService", 305, 26, TXT, MONO, 2.0, X),
             ("- `CurrencyService.add(...)` is the shared entry point, called from 5 files", 345, 26, TXT, MONO, 2.4, X),
             ("## Relevant past sessions", 415, 28, VIO, MONO, 4.0, X),
             ("- [session 17c7cb15, 2026-10-30]", 460, 26, MUT, MONO, 4.4, X),
             ("  User asked: \"Let's plan the daily login reward ... Decisions we agreed on:", 500, 26, TXT, MONO, 5.0, X),
             ("  (1) coins are granted only through CurrencyService.add ... \"daily_reward\";", 540, 26, TXT, MONO, 5.6, X),
             ("  (2) the day boundary is 00:00 UTC, not server local time;", 580, 26, TXT, MONO, 6.2, X),
             ("  (3) reward is 20 coins plus 10 per streak day;", 620, 26, GRN, MONO, 6.8, X),
             ("  (4) the streak caps at 7 days, as a new Config.DailyStreakCap = 7; ...\"", 660, 26, GRN, MONO, 7.4, X),
             ("## Relevant files", 730, 28, VIO, MONO, 9.0, X),
             ("- src/shared/Config.luau [61 lines, used by 7]   L10: RoundRewardCoins = 25", 775, 26, TXT, MONO, 9.4, X),
             ("The plan, word for word, plus the rules this game already follows.", 900, 44, CY, FONT, 12.0)]
    card(lines, d, out, panels=[(110, 170, 1700, 660, "0x5A606B")])


def seg_code(d, out):
    """Side-by-side output (results/raw/heldout/heldout_P1-H2_C0_haiku_r0_*.diff vs ..._C3_haiku_r0_*.diff)."""
    L, R = 120, 1000
    lines = [("Same request. Same model.", 70, 52, TXT, FONT, 0.2),
             ("Claude, no memory", 180, 42, TXT, FONT, 0.6, L), ("Claude + DevMemory", 180, 42, VIO, FONT, 0.6, R),
             ("DailyRewardBaseCoins = 50,", 290, 30, WARN, MONO, 1.2, L + 30),
             ("DailyRewardPerDayCoins = 10,", 335, 30, TXT, MONO, 1.2, L + 30),
             ("DailyRewardMaxStreak = 7,", 380, 30, TXT, MONO, 1.2, L + 30),
             ("return BaseCoins + PerDayCoins", 450, 28, MUT, MONO, 1.6, L + 30),
             ("       * (cappedDay - 1)", 490, 28, MUT, MONO, 1.6, L + 30),
             ("DailyRewardBase = 20,", 290, 30, GRN, MONO, 2.4, R + 30),
             ("DailyRewardPerStreakDay = 10,", 335, 30, GRN, MONO, 2.4, R + 30),
             ("DailyStreakCap = 7,", 380, 30, GRN, MONO, 2.4, R + 30),
             ("return Base + PerStreakDay * day", 450, 28, MUT, MONO, 2.8, R + 30),
             ("  (day clamped to DailyStreakCap)", 490, 28, MUT, MONO, 2.8, R + 30),
             ("50 coins: invented", 580, 36, WARN, FONT, 4.0, L + 30),
             ("20 + 10 per day, cap 7: the plan", 580, 36, GRN, FONT, 4.5, R + 30),
             ("0 of 3 correct", 700, 64, WARN, FONT, 7.0, L + 30),
             ("3 of 3 correct", 700, 64, GRN, FONT, 7.5, R + 30),
             ("A bigger model and a hand-written CLAUDE.md also failed every time", 790, 30, MUT, FONT_R, 9.0, L + 30),
             ("Same token cost on average (62k vs 63k)", 790, 30, MUT, FONT_R, 9.5, R + 30),
             ("Held-out Roblox task H2, frozen before any run. Model: Claude Haiku 5.5.", 960, 28, MUT, FONT_R, 11.0)]
    card(lines, d, out, panels=[(L, 250, 800, 290, "0x5A606B"), (R, 250, 800, 290, VIO)])


def seg_also(d, out):
    card([("Also tested", 300, 60, TXT, FONT, 0.2),
          ("A web-app race: all 8 features built, DevMemory the cheapest", 450, 44, CY, FONT, 0.8),
          ("Memory shared between Claude Code and Codex: 3 of 3 right vs 0 of 3", 530, 44, CY, FONT, 1.6),
          ("Every number, method and disclosure: RESULTS.md in the repository", 700, 34, MUT, FONT_R, 2.6)], d, out)


# ---- Blade Swarm test case: race prompt R6 in the DevMemory build ----
def seg_input_bs(d, out):
    a, b, c = OUT / "_bin_a.mp4", OUT / "_bin_b.mp4", OUT / "_bin_c.mp4"
    d1 = round(d * 0.34, 2); d2 = round(d * 0.22, 2); d3 = round(d - d1 - d2, 2)
    shot("bs_session_R5.png", "1600:900:0:0", d1, a, [("Blade Swarm: every AI session, recorded by DevMemory", 0.4)])
    shot("bs_session_R5.png", "1025:577:300:90", d2, b,
         [("Session 8: the user picks the rarity colors", 0.4)], box=(34, 192, 958, 64, 1.5))
    card([("The next session is brand new. It gets:", 300, 46, MUT, FONT_R, 0.2),
          ("\"Add an Epic upgrade called Twin Spin: +2 blades for 120 coins.", 430, 52, TXT, FONT, 0.8),
          ("Make sure it shows up with the rarity colors we picked.\"", 500, 52, GRN, FONT, 1.6),
          ("It has never seen session 8.", 660, 46, WARN, FONT, 3.5)], d3, c)
    concat([a, b, c], out)


def seg_action_bs(d, out):
    """Actual pack delivered for R6: results/raw/adaptive_blade_devmemory_r1/P9-R6.pack.md (excerpt)."""
    X = 150
    lines = [("DevMemory builds a pack for this request  ·  0 AI tokens  ·  actual pack, excerpt", 90, 40, TXT, FONT, 0.2),
             ("# DevMemory context pack      Project: roblox (rojo)", 195, 27, CY, MONO, 0.8, X),
             ("## Conventions (observed in code)", 250, 27, VIO, MONO, 1.4, X),
             ("- Tunables live in src/shared/Config.lua (51 keys, used by 8 files)", 292, 25, TXT, MONO, 1.8, X),
             ("- Instance.new(\"RemoteEvent\") occurs only in src/shared/Remotes.lua", 330, 25, TXT, MONO, 2.2, X),
             ("## Relevant past sessions", 395, 27, VIO, MONO, 3.5, X),
             ("- [session dbf18bb2]  User asked: \"Now the upgrade shop ... +1 Blade (Rare, 60 coins),", 437, 25, TXT, MONO, 4.0, X),
             ("  Sharper Blades (Common, 30) ... Greed +25% coins (Rare, 50) ...\"", 475, 25, TXT, MONO, 4.4, X),
             ("- [session 3e2bb0e2]  User asked: \"The UI is ugly. Make a proper HUD and shop UI ...", 530, 25, TXT, MONO, 5.6, X),
             ("  rarity colors Common = gray, Rare = blue, Epic = purple ...\"", 568, 25, GRN, MONO, 6.2, X),
             ("  Outcome: \"... The colors live in a new Config.Ui table in src/shared/Config.lua\"", 606, 25, GRN, MONO, 7.0, X),
             ("## Relevant files", 670, 27, VIO, MONO, 8.5, X),
             ("- src/server/Shop.lua [164 lines]   - src/shared/Config.lua [73 lines]", 712, 25, TXT, MONO, 8.9, X),
             ("~970 tokens: both earlier decisions, word for word, and where the code keeps them.", 880, 42, CY, FONT, 11.0)]
    card(lines, d, out, panels=[(110, 165, 1700, 600, "0x5A606B")])


def seg_output_bs(d, out):
    a, b = OUT / "_bout_a.mp4", OUT / "_bout_b.mp4"
    d1 = round(d * 0.55, 2); d2 = round(d - d1, 2)
    X = 220
    card([("The result, in the DevMemory build:  src/shared/Config.lua", 120, 42, TXT, FONT, 0.2),
          ("Rarity = {", 250, 30, TXT, MONO, 0.8, X),
          ("    Common = Color3.fromRGB(150, 156, 170),", 300, 30, TXT, MONO, 1.2, X),
          ("    Rare   = Color3.fromRGB(70, 140, 255),", 350, 30, TXT, MONO, 1.4, X),
          ("    Epic   = Color3.fromRGB(170, 90, 240),", 400, 30, TXT, MONO, 1.6, X),
          ("},", 450, 30, TXT, MONO, 1.6, X),
          ("gray", 300, 30, MUT, FONT, 2.0, 1300), ("blue", 350, 30, "0x468CFF", FONT, 2.2, 1300),
          ("purple", 400, 30, "0xAA5AF0", FONT, 2.4, 1300),
          ("{ Id = \"TwinSpin\", Name = \"Twin Spin\", Rarity = \"Epic\", Cost = 120, Amount = 2 },", 560, 28, GRN, MONO, 3.5, X),
          ("Twin Spin arrives as an Epic upgrade, in the colors the user chose.", 760, 44, CY, FONT, 5.0)],
         d1, a, panels=[(180, 220, 1560, 410, VIO)])
    v = (f"[0:v]{GAME_CROP},crop=1365:768:272:0,scale=1920:1080,setsar=1,"
         f"{text('The DevMemory build: shop cards in the chosen rarity colors', '(w-text_w)/2', 'h-140', 48, start=0.3, box=True)}[v]")
    run(["-ss", "19", "-t", str(d2), "-i", FOOT / CLIPS["devmemory"], "-filter_complex", v, "-map", "[v]", *enc(b)])
    concat([a, b], out)


def seg_input(d, out):
    a, b, c = OUT / "_in_a.mp4", OUT / "_in_b.mp4", OUT / "_in_c.mp4"
    d1 = round(d * 0.46, 2); d2 = round(d * 0.2, 2); d3 = round(d - d1 - d2, 2)
    shot("xtool_session_labels.png", "1025:577:300:90", d1, a,
         [("Earlier, in Claude Code: the user picks exact label colors", 0.5)], box=(34, 192, 958, 64, 2.5))
    card([("Later, the app is restyled...", 420, 72, TXT, FONT, 0.2), ("...and the colors drift.", 520, 72, WARN, FONT, 1.2)], d2, b)
    card([("Now the user asks a different AI tool:", 300, 44, MUT, FONT_R, 0.2),
          ("\"Put the label colors back to exactly", 420, 64, TXT, FONT, 0.8),
          ("what I originally asked for.\"", 500, 64, TXT, FONT, 0.8),
          ("→  Codex  (it has never seen the earlier session)", 650, 48, CY, FONT, 2.0)], d3, c)
    concat([a, b, c], out)


def seg_action(d, out):
    a, b, c = OUT / "_ac_a.mp4", OUT / "_ac_b.mp4", OUT / "_ac_c.mp4"
    d1 = round(d * 0.3, 2); d2 = round(d * 0.32, 2); d3 = round(d - d1 - d2, 2)
    shot("xtool_packlab.png", "1025:577:300:90", d1, a,
         [("DevMemory scans the project with 0 AI tokens and builds a pack", 0.4)], box=(34, 282, 956, 90, 3))
    shot("xtool_packlab.png", "1025:577:300:380", d2, b,
         [("It finds the session where the colors were chosen, flagged partly stale", 0.4)], box=(34, 410, 956, 90, 2))
    lines = [("$ devmem codex \"Put the label colors back to exactly what I originally asked for.\"", 250, 30, TXT, MONO, 0.2),
             ("  scan   project map, 0 LLM tokens", 330, 30, MUT, MONO, 1.2),
             ("  pack   861 tokens: the user's original request (session S3, partly stale), app.js", 380, 30, MUT, MONO, 2.0),
             ("  codex  exec --json  (pack + request)", 430, 30, MUT, MONO, 3.0),
             ("Codex:  Restored the label colors in public/app.js", 560, 36, GRN, MONO, 5.5),
             ("Bug #e5484d   Feature #3e63dd   Chore #8b8d98", 620, 36, GRN, MONO, 6.5),
             ("The session is captured too, so the next tool can build on it.", 800, 40, CY, FONT, 9.0)]
    card(lines, d3, c)
    concat([a, b, c], out)


def concat(parts, out):
    lst = OUT / (out.stem + "_list.txt")
    lst.write_text("".join(f"file '{p.as_posix()}'\n" for p in parts), encoding="utf-8")
    run(["-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", out])


def seg_race(d, out):
    names = [("none", "Claude Base", "3.08M", "$3.41", MUT), ("agentsmd", "Claude + AGENTS.md", "3.41M", "$2.88", MUT),
             ("devmemory", "Claude + DevMemory", "1.85M", "$2.48", VIO)]
    ins, fc = [], [f"color=c={BG}:s=1920x1080:d={d}:r=30[bg]"]
    for i, (k, *_rest) in enumerate(names):
        ins += ["-ss", "4", "-t", str(d), "-i", FOOT / CLIPS[k]]
        fc.append(f"[{i}:v]{GAME_CROP},crop=1024:768:443:0,scale=600:450,setsar=1[p{i}]")
    cur = "bg"
    for i, (k, title, tok, cost, col) in enumerate(names):
        x = 30 + i * 630
        fc.append(f"[{cur}][p{i}]overlay={x}:250[o{i}]")
        cur = f"o{i}"
    draws = [text("The same game, built three ways: 16 fresh sessions each", "(w-text_w)/2", 70, 48)]
    for i, (k, title, tok, cost, col) in enumerate(names):
        cx = 30 + i * 630 + 300
        draws.append(text(title, f"{cx}-text_w/2", 185, 42, color=col if k == "devmemory" else TXT))
        draws.append(text(tok, f"{cx}-text_w/2", 735, 76, color=col if k == "devmemory" else TXT, start=2 + i * 0.4))
        draws.append(text("input tokens", f"{cx}-text_w/2", 820, 30, color=MUT, start=2 + i * 0.4))
        draws.append(text(cost, f"{cx}-text_w/2", 870, 52, color=col if k == "devmemory" else TXT, start=4 + i * 0.4))
    draws.append(text("All three playable (human check). Same AI-generated art pack in every build. Cost at API list price.", "(w-text_w)/2", 985, 30, color=MUT, start=1))
    fc.append(f"[{cur}]" + ",".join(draws) + "[v]")
    run([*ins, "-filter_complex", ";".join(fc), "-map", "[v]", *enc(out)])


def seg_xtool(d, out):
    shots = REPO / "docs" / "taskboard-screens"
    fc = [f"color=c={BG}:s=1920x1080:d={d}:r=30[bg]",
          "[0:v]scale=900:-2,setsar=1[a]", "[1:v]scale=900:-2,setsar=1[b]",
          "[bg][a]overlay=40:250[o1]", "[o1][b]overlay=980:250[o2]"]
    draws = [text("Same request, same Codex: without vs. with DevMemory", "(w-text_w)/2", 70, 52),
             text("\"Put the label colors back to exactly what I originally asked for.\"", "(w-text_w)/2", 150, 34, color=MUT, font=FONT_R),
             text("Codex, no memory", "490-text_w/2", 200, 38),
             text("Codex + DevMemory", "1430-text_w/2", 200, 38, color=VIO),
             text("0 of 3 right  ·  153k tokens", "490-text_w/2", 880, 44, color=WARN, start=6),
             text("3 of 3 right  ·  68k tokens", "1430-text_w/2", 880, 44, color=GRN, start=7),
             text("Green 'Chore' tags: a guess. Gray: what the user picked.", "(w-text_w)/2", 970, 30, color=MUT, start=10)]
    fc.append("[o2]" + ",".join(draws) + "[v]")
    run(["-loop", "1", "-t", str(d), "-i", shots / "codex_no_memory.png", "-loop", "1", "-t", str(d), "-i",
         shots / "codex_with_devmemory.png", "-filter_complex", ";".join(fc), "-map", "[v]", *enc(out)])


def seg_slide(n, d, out, zoom=True):
    frames = int(d * 30)
    z = f"zoompan=z='min(zoom+0.0004\\,1.06)':d={frames}:s=1920x1080:fps=30" if zoom else "scale=1920:1080"
    run(["-i", REPO / "docs" / "deck" / "preview" / f"Slide{n}.PNG",
         "-filter_complex", f"[0:v]scale=2200:-2,{z},setsar=1[v]", "-map", "[v]", *enc(out)])


def seg_close(d, out):
    v = (f"[0:v]{GAME_CROP},crop=1365:768:272:0,scale=1920:1080,boxblur=12:2,eq=brightness=-0.25,setsar=1,"
         f"{text('DevMemory', '(w-text_w)/2', 'h/2-150', 120, start=0.2)},"
         f"{text('Preserve everything. Send only what earns its tokens.', '(w-text_w)/2', 'h/2+10', 54, color=VIO, start=0.8)},"
         f"{text('Local-first  ·  Claude Code, Codex, any MCP client  ·  tested on 28 unseen tasks', '(w-text_w)/2', 'h/2+110', 34, color=MUT, start=1.4)},"
         f"{text('Thamer Alhussain  ·  HUMAIN–Misk Future AI Builders Hackathon', '(w-text_w)/2', 'h-140', 34, color=TXT, start=3.0)}[v]")
    run(["-ss", "30", "-t", str(d), "-i", FOOT / CLIPS["devmemory"], "-filter_complex", v, "-map", "[v]", *enc(out)])


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    tf = REPO / "demo" / "video" / "timings.json"
    if tf.exists():
        DUR.update(json.loads(tf.read_text(encoding="utf-8")))
    parts = []
    for name, fn in [("hook", seg_hook), ("input", seg_input_bs), ("action", seg_action_bs), ("output", seg_output_bs),
                     ("race", seg_race), ("heldout", lambda d, o: seg_slide(7, d, o)), ("also", seg_also),
                     ("close", seg_close)]:
        p = OUT / f"{len(parts):02d}_{name}.mp4"
        fn(DUR[name], p)
        parts.append(p)
        print("built", p.name, DUR[name], "s", flush=True)
    lst = OUT / "parts.txt"
    lst.write_text("".join(f"file '{p.as_posix()}'\n" for p in parts), encoding="utf-8")
    silent = OUT / "video_only.mp4"
    run(["-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", silent])
    final = OUT / "DevMemory_demo.mp4"
    if "--vo" in sys.argv:
        vo = sys.argv[sys.argv.index("--vo") + 1]
        run(["-i", silent, "-i", vo, "-map", "0:v", "-map", "1:a", "-c:v", "copy", "-af", "loudnorm=I=-16:TP=-1.5",
             "-c:a", "aac", "-b:a", "192k", "-shortest", final])
    else:
        run(["-i", silent, "-c", "copy", final])
    print("done:", final, sum(DUR.values()), "s")


if __name__ == "__main__":
    main()
