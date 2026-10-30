"""Deterministic project scanner (0 LLM tokens).

Builds <store>/index/map.json and <store>/PROJECT.md from the files alone:
  - inventory with content hashes (for incremental updates and freshness checks)
  - symbols, require/import graph, Roblox remotes / Config keys / asset references
  - convention hints derived from call-site statistics, labelled as observations:
      * hub APIs: module functions called from many other files
      * exclusive sites: sensitive operations that occur in only one or two files
"""
from __future__ import annotations

import json
import re
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

from .store import MAX_TEXT_BYTES, file_hash, iter_files, store_path

TEXT_EXT = {".luau", ".lua", ".py", ".ts", ".tsx", ".js", ".jsx", ".json", ".md", ".toml", ".yaml",
            ".yml", ".txt", ".cfg", ".ini"}
LANG = {".luau": "luau", ".lua": "luau", ".py": "python", ".ts": "ts", ".tsx": "ts", ".js": "js", ".jsx": "js"}

# --- per-language extractors -------------------------------------------------------------
LUAU = {
    "func": re.compile(r"^\s*function\s+([A-Za-z_][\w]*[.:][A-Za-z_]\w*)\s*\(", re.M),
    "local_func": re.compile(r"^\s*local\s+function\s+([A-Za-z_]\w*)", re.M),
    "require": re.compile(r"require\(\s*([\w.:\"'()\[\]]+?)\s*\)"),
    "remote_define": re.compile(r'Remotes\.define\(\s*"(\w+)"'),
    "remote_use": re.compile(r'Remotes\.get\(\s*"(\w+)"\s*\)\s*[.:]\s*(\w+)'),
    "asset": re.compile(r'Assets\.get\(\s*"(\w+)"'),
    "config_use": re.compile(r"\bConfig\.(\w+)"),
}
PY = {
    "func": re.compile(r"^(?:async\s+)?def\s+([A-Za-z_]\w*)", re.M),
    "class": re.compile(r"^class\s+([A-Za-z_]\w*)", re.M),
    "method": re.compile(r"^\s+(?:async\s+)?def\s+([A-Za-z_]\w*)", re.M),
    "import": re.compile(r"^\s*(?:from\s+([\w.]+)\s+import\s+([\w, ]+)|import\s+([\w.]+))", re.M),
}
JS = {
    "func": re.compile(r"(?:export\s+)?(?:async\s+)?function\s+([A-Za-z_]\w*)"),
    "class": re.compile(r"(?:export\s+)?class\s+([A-Za-z_]\w*)"),
    "import": re.compile(r"""import\s+.*?from\s+['"]([^'"]+)['"]"""),
}
# Sensitive operations: if they occur in only one or two files, that is reported as an observed
# chokepoint ("exclusive site"). Patterns are matched against comment-stripped code.
EXCLUSIVE = {
    "luau": {
        'Instance.new("RemoteEvent")': re.compile(r'Instance\.new\(\s*"Remote(Event|Function)"'),
        "print/warn": re.compile(r"(?<![.\w:])(print|warn)\s*\("),
        "rbxassetid literal": re.compile(r"rbxassetid://"),
        "leaderstats writes": re.compile(r"leaderstats|\.Value\s*=[^=]"),
        "DataStore access": re.compile(r"GetDataStore\s*\("),
        "data.coins writes": re.compile(r"\.coins\s*(=[^=]|\+=|-=)"),
    },
    "python": {
        "print(": re.compile(r"(?<![.\w])print\s*\("),
        "sqlite3.connect / DB connection": re.compile(r"sqlite3\.connect|create_engine\("),
        "os.environ / settings reads": re.compile(r"os\.environ|os\.getenv"),
        "float() on money": re.compile(r"\bfloat\s*\("),
        "raise Exception/ValueError": re.compile(r"raise\s+(Exception|ValueError|RuntimeError)\b"),
        "open( file I/O": re.compile(r"(?<![.\w])open\s*\("),
    },
}
CONFIG_NAMES = {"config", "settings", "constants", "tunables"}


def _strip_comments(text: str, lang: str) -> str:
    if lang == "luau":
        text = re.sub(r"--\[(=*)\[.*?\]\1\]", "", text, flags=re.S)
        return re.sub(r"--[^\n]*", "", text)
    if lang == "python":
        return re.sub(r"#[^\n]*", "", text)
    return re.sub(r"//[^\n]*", "", text)


def _module_name(rel: str) -> str:
    stem = Path(rel).name.split(".")[0]
    return Path(rel).parent.name if stem in ("init", "__init__", "index") else stem


def _extract(rel: str, text: str) -> dict:
    ext = Path(rel).suffix.lower()
    lang = LANG.get(ext, "text")
    code = _strip_comments(text, lang) if lang != "text" else text
    info: dict = {"lang": lang, "module": _module_name(rel), "symbols": [], "deps": []}
    if lang == "luau":
        info["kind"] = ("server-script" if ".server." in rel else "client-script" if ".client." in rel
                        else "module")
        info["symbols"] = sorted(set(LUAU["func"].findall(code)))
        info["local_functions"] = sorted(set(LUAU["local_func"].findall(code)))[:30]
        deps = []
        for r in LUAU["require"].findall(code):
            name = re.findall(r"[A-Za-z_]\w*", r)
            if name:
                deps.append(name[-1])
        info["deps"] = sorted(set(deps))
        info["remotes_defined"] = sorted(set(LUAU["remote_define"].findall(code)))
        uses = defaultdict(set)
        for name, how in LUAU["remote_use"].findall(code):
            uses[name].add(how)
        info["remotes_used"] = {k: sorted(v) for k, v in sorted(uses.items())}
        info["assets"] = sorted(set(LUAU["asset"].findall(code)))
        info["config_keys_used"] = sorted(set(LUAU["config_use"].findall(code)))
    elif lang == "python":
        info["symbols"] = sorted(set(PY["func"].findall(code)) | set(PY["class"].findall(code)))
        info["methods"] = sorted(set(PY["method"].findall(code)) - set(info["symbols"]))[:40]
        deps = []
        for frm, names, imp in PY["import"].findall(code):
            deps.append(frm or imp)
        info["deps"] = sorted(set(d for d in deps if d))
    elif lang in ("ts", "js"):
        info["symbols"] = sorted(set(JS["func"].findall(code)) | set(JS["class"].findall(code)))
        info["deps"] = sorted(set(JS["import"].findall(code)))
    if info["module"].lower() in CONFIG_NAMES and lang in ("luau", "python"):
        keys = re.findall(r"^\s*([A-Za-z_]\w*)\s*=", code, re.M)
        info["config_keys"] = [k for k in dict.fromkeys(keys) if k not in ("local", "Config")][:80]
    return info, code


def scan(project: Path, store: Path | None = None) -> dict:
    """Scan `project`; write map.json + PROJECT.md into the store; return the map."""
    project = Path(project).resolve()
    store = Path(store) if store else store_path(project)
    files, codes = {}, {}
    for rel in iter_files(project):
        p = project / rel
        if p.suffix.lower() not in TEXT_EXT or p.stat().st_size > MAX_TEXT_BYTES:
            continue
        text = p.read_text(encoding="utf-8", errors="replace")
        info, code = _extract(rel, text)
        info.update(hash=file_hash(p), lines=text.count("\n") + 1, bytes=p.stat().st_size)
        files[rel] = info
        codes[rel] = code
    m = {"project": project.name, "scanned_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
         "llm_tokens_used": 0, "files": files, "engine": _detect_engine(project, files),
         "rojo": _rojo_mapping(project), "conventions": _conventions(files, codes)}
    m["used_by"] = _reverse_deps(files)
    (store / "index").mkdir(parents=True, exist_ok=True)
    (store / "index" / "map.json").write_text(json.dumps(m, indent=1), encoding="utf-8")
    (store / "PROJECT.md").write_text(render_project_md(m), encoding="utf-8")
    return m


def _detect_engine(project: Path, files: dict) -> str:
    if (project / "default.project.json").exists() or any(f.endswith(".luau") for f in files):
        return "roblox (rojo)" if (project / "default.project.json").exists() else "roblox"
    if any(f.endswith(".py") for f in files):
        return "python"
    if (project / "package.json").exists():
        return "node"
    return "generic"


def _rojo_mapping(project: Path) -> dict:
    pj = project / "default.project.json"
    if not pj.exists():
        return {}
    try:
        tree = json.loads(pj.read_text(encoding="utf-8")).get("tree", {})
    except ValueError:
        return {}
    out = {}

    def walk(node, path):
        for k, v in node.items():
            if k.startswith("$") or not isinstance(v, dict):
                continue
            if "$path" in v:
                out[v["$path"]] = ".".join(path + [k])
            walk(v, path + [k])
    walk(tree, [])
    return out


def _reverse_deps(files: dict) -> dict:
    by_module = defaultdict(list)
    for rel, info in files.items():
        by_module[info["module"]].append(rel)
    used = defaultdict(set)
    for rel, info in files.items():
        for d in info.get("deps", []):
            for target in by_module.get(d.split(".")[-1], []):
                if target != rel:
                    used[target].add(rel)
    return {k: sorted(v) for k, v in sorted(used.items())}


def _conventions(files: dict, codes: dict) -> dict:
    """Observed, not inferred: hub APIs and exclusive sites, with file evidence."""
    # hub APIs: Module.fn( calls from other files
    defined = {}
    for rel, info in files.items():
        for s in info.get("symbols", []):
            if "." in s or ":" in s:
                defined[re.split(r"[.:]", s)[0] + "." + re.split(r"[.:]", s)[1]] = rel
    calls = defaultdict(set)
    for rel, code in codes.items():
        for mod_fn in set(re.findall(r"\b([A-Z]\w*)[.:]([a-z]\w*)\s*\(", code)):
            key = f"{mod_fn[0]}.{mod_fn[1]}"
            if key in defined and defined[key] != rel:
                calls[key].add(rel)
    hubs = sorted(((k, sorted(v)) for k, v in calls.items() if len(v) >= 3), key=lambda kv: -len(kv[1]))
    # exclusive sites per language
    exclusive = []
    langs = {i["lang"] for i in files.values()}
    for lang in langs:
        for label, rx in EXCLUSIVE.get(lang, {}).items():
            hits = sorted(rel for rel, code in codes.items() if files[rel]["lang"] == lang and rx.search(code))
            n_lang = sum(1 for i in files.values() if i["lang"] == lang)
            if 1 <= len(hits) <= 2 and n_lang >= 6:
                exclusive.append({"op": label, "only_in": hits})
            elif not hits and n_lang >= 6 and label in ("print/warn", "print(", "rbxassetid literal"):
                exclusive.append({"op": label, "only_in": []})
    config_mods = [rel for rel, i in files.items() if i.get("config_keys")]
    cfg_users = {rel: sorted(r for r, i in files.items() if i.get("config_keys_used") or
                             any(d.split(".")[-1] == files[rel]["module"] for d in i.get("deps", [])))
                 for rel in config_mods}
    return {"hub_apis": [{"api": k, "callers": len(v), "files": v} for k, v in hubs[:12]],
            "exclusive_sites": sorted(exclusive, key=lambda e: e["op"]),
            "config_modules": {rel: {"keys": len(files[rel]["config_keys"]), "used_by": len(cfg_users[rel])}
                               for rel in config_mods}}


def convention_lines(m: dict) -> list[str]:
    """Human-readable convention hints, each traceable to observed evidence."""
    c, lines = m["conventions"], []
    for e in c["exclusive_sites"]:
        if e["only_in"]:
            lines.append(f"`{e['op']}` occurs only in {', '.join(e['only_in'])} (observed); "
                         f"go through that module instead of repeating it.")
        else:
            lines.append(f"`{e['op']}` occurs nowhere in source (observed); avoid introducing it.")
    for h in c["hub_apis"][:8]:
        lines.append(f"`{h['api']}(...)` is the shared entry point, called from {h['callers']} files.")
    for rel, info in c["config_modules"].items():
        lines.append(f"Tunables live in `{rel}` ({info['keys']} keys, used by {info['used_by']} files); "
                     f"add new constants there.")
    return lines


def render_project_md(m: dict) -> str:
    """Compact, always-loadable map (also readable in any Markdown viewer / Obsidian)."""
    out = [f"# {m['project']} — project map", "",
           f"Engine: {m['engine']}. Files indexed: {len(m['files'])}. Built deterministically "
           f"({m['llm_tokens_used']} LLM tokens) at {m['scanned_at']}.", ""]
    if m["rojo"]:
        out += ["## Rojo mapping"] + [f"- `{k}` -> {v}" for k, v in m["rojo"].items()] + [""]
    out += ["## Conventions (observed)"] + [f"- {l}" for l in convention_lines(m)] + [""]
    out += ["## Files"]
    for rel, i in m["files"].items():
        if i["lang"] == "text" and not rel.endswith(".json"):
            continue
        bits = []
        if i.get("symbols"):
            bits.append("fn: " + ", ".join(s.split(".")[-1].split(":")[-1] for s in i["symbols"][:8]))
        if i.get("remotes_defined"):
            bits.append("defines remotes: " + ", ".join(i["remotes_defined"]))
        if i.get("remotes_used"):
            bits.append("remotes: " + ", ".join(i["remotes_used"]))
        if i.get("config_keys"):
            bits.append(f"{len(i['config_keys'])} config keys")
        out.append(f"- `{rel}`" + (" — " + "; ".join(bits) if bits else ""))
    return "\n".join(out) + "\n"
