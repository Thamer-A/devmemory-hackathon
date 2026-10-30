"""Task-specific context packs (0 LLM tokens).

Given a task string, retrieve from the project map and captured sessions, rank by keyword/path/
symbol relevance (BM25), check freshness, and emit a small Markdown pack within a token budget.
Every item carries its source and the reason it was included.

Modes:  full     map + session memories with freshness flags (C3)
        static   map only, no session memories (C2 ablation)
        nofresh  like full but session memories are shown without freshness checks (ablation)
"""
from __future__ import annotations

import json
import math
import re
from collections import Counter
from pathlib import Path

from .scan import convention_lines, scan
from .store import estimate_tokens, file_hash

STOP = set("""a an the and or of to in on for with from by at as is are be been it its this that these those
into onto than then so we our you your i me my us let lets let's please can could should would will just
add make new use using change implement implemented create update set get fix also when after before
same each all any some there here what which who how do does done not no now last next only one two""".split())


def tokenize(text: str) -> list[str]:
    text = re.sub(r"([a-z0-9])([A-Z])", r"\1 \2", text or "")
    text = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1 \2", text)
    out = []
    for w in re.findall(r"[A-Za-z][A-Za-z0-9]+|\d+", text.lower()):
        if w in STOP or len(w) < 2:
            continue
        for suf in ("ing", "ed", "es", "s"):
            if len(w) > 4 + len(suf) - 1 and w.endswith(suf):
                w = w[: -len(suf)]
                break
        out.append(w)
    return out


class BM25:
    def __init__(self, docs: dict[str, list[str]], k1: float = 1.2, b: float = 0.6):
        self.docs = {k: Counter(v) for k, v in docs.items()}
        self.len = {k: len(v) for k, v in docs.items()}
        self.avg = (sum(self.len.values()) / len(self.len)) if self.len else 1
        n = len(docs)
        df = Counter(t for c in self.docs.values() for t in c)
        self.idf = {t: math.log(1 + (n - d + 0.5) / (d + 0.5)) for t, d in df.items()}
        self.k1, self.b = k1, b

    def score(self, key: str, q: list[str]) -> tuple[float, list[str]]:
        c, s, hit = self.docs[key], 0.0, []
        for t in set(q):
            f = c.get(t, 0)
            if not f:
                continue
            hit.append(t)
            s += self.idf[t] * f * (self.k1 + 1) / (f + self.k1 * (1 - self.b + self.b * self.len[key] / self.avg))
        return s, sorted(hit)


def _file_doc(rel: str, i: dict, text: str) -> list[str]:
    toks = tokenize(rel.replace("/", " ")) * 3 + tokenize(i["module"]) * 2
    for s in i.get("symbols", []):
        toks += tokenize(s.split(".")[-1].split(":")[-1]) * 2
    for k in ("remotes_defined", "assets", "local_functions", "config_keys"):
        for s in i.get(k, []):
            toks += tokenize(s) * (2 if k == "remotes_defined" else 1)
    for s in i.get("remotes_used", {}):
        toks += tokenize(s)
    return toks + tokenize(text)[:4000]


def load_sessions(store: Path) -> list[dict]:
    out = []
    for p in sorted((Path(store) / "sessions").glob("*.meta.json")):
        try:
            out.append(json.loads(p.read_text(encoding="utf-8")) | {"_meta": p.name})
        except ValueError:
            pass
    return out


def _session_doc(s: dict) -> list[str]:
    edits = " ".join(t.get("new", "") for t in s.get("tool_calls", []) if t.get("tool") == "Edit")
    return (tokenize(s.get("prompt", "")) * 2 + tokenize(s.get("result_text") or "")
            + tokenize(" ".join(s.get("files_edited", []))) + tokenize(edits)[:400])


def freshness(s: dict, project: Path) -> dict:
    """Line-level freshness: is each edit this session made still present in the current file?
    Falls back to content hashes for files the session only read."""
    edits = [t for t in s.get("tool_calls", []) if t.get("tool") in ("Edit", "Write") and t.get("file")]
    intact, modified, gone = [], [], []
    for t in edits:
        cur = (project / t["file"])
        txt = cur.read_text(encoding="utf-8", errors="replace") if cur.exists() else ""
        lines = [l.strip() for l in (t.get("new") or "").splitlines() if len(l.strip()) > 8]
        if not lines:
            continue
        ratio = sum(1 for l in lines if l in txt) / len(lines)
        (intact if ratio == 1 else gone if ratio < 0.5 else modified).append(t["file"])
    present = intact
    changed_reads = [f for f, h in (s.get("file_hashes_at_capture") or {}).items()
                     if f not in s.get("files_edited", []) and h and file_hash(project / f) != h]
    if not edits:
        status = "context-changed" if changed_reads else "fresh"
    elif not gone and not modified:
        status = "fresh"
    elif not intact:
        status = "stale"
    else:
        status = "partly-stale"
    return {"status": status, "edits_gone_from": sorted(set(gone) | set(modified)), "edits_present_in": sorted(set(present)),
            "read_files_changed": sorted(changed_reads)}


DECISION_RE = re.compile(r"\b(decision|decided|agreed|must|never|always|only|instead of|do not|don't)\b", re.I)


def decision_sentences(prompt: str) -> list[str]:
    """Standing rules stated by the user (their own words), minus session-scoped instructions."""
    parts = re.split(r"(?<=[.!?])\s+|;\s+|\n+", prompt or "")
    return [p.strip() for p in parts
            if DECISION_RE.search(p) and "this session" not in p.lower() and 20 <= len(p.strip()) <= 300]


def _evidence_lines(text: str, q: set[str], max_lines: int = 2) -> list[tuple[int, str]]:
    scored = []
    for n, line in enumerate(text.splitlines(), 1):
        lt = set(tokenize(line))
        hits = len(lt & q)
        if hits >= 2 or (hits == 1 and len(q) <= 2):
            scored.append((hits, n, line.strip()[:160]))
    scored.sort(key=lambda x: (-x[0], x[1]))
    return [(n, l) for _, n, l in scored[:max_lines]]


def build_pack(project: Path, store: Path, task: str, budget: int = 1500, mode: str = "full",
               max_files: int = 6, max_sessions: int = 3) -> tuple[str, dict]:
    project, store = Path(project), Path(store)
    map_path = store / "index" / "map.json"
    m = json.loads(map_path.read_text(encoding="utf-8")) if map_path.exists() else scan(project, store)
    q = tokenize(task)
    qset = set(q)
    texts = {rel: (project / rel).read_text(encoding="utf-8", errors="replace") for rel in m["files"]}
    files_bm = BM25({rel: _file_doc(rel, i, texts[rel]) for rel, i in m["files"].items()})
    fscores = sorted(((files_bm.score(rel, q), rel) for rel in m["files"]), key=lambda x: -x[0][0])
    top = fscores[0][0][0] if fscores else 0
    # relevance gate: relative to the best file AND at least two distinct query terms (or one rare one)
    picked_files = [(s, hits, rel) for (s, hits), rel in fscores
                    if s > 0 and s >= 0.55 * top and (len(hits) >= 2 or s >= 0.8 * top)][:max_files]

    sessions = load_sessions(store) if mode in ("full", "nofresh") else []
    picked_sessions, decisions = [], []
    if sessions:
        sb = BM25({s["_meta"]: _session_doc(s) for s in sessions})
        # informativeness judged against files AND sessions, so generic project words don't count
        gidf = BM25({**{rel: _file_doc(rel, i, "") for rel, i in m["files"].items()},
                     **{s["_meta"]: _session_doc(s) for s in sessions}}).idf
        ss = sorted(((sb.score(s["_meta"], q), s) for s in sessions), key=lambda x: -x[0][0])
        best = ss[0][0][0] if ss else 0
        for (sc, hits), s in ss:
            rare = [h for h in hits if gidf.get(h, 0) >= 1.8]
            in_prompt = set(tokenize(s.get("prompt", "")))
            # topic is set by what the user asked, not by incidental words in the assistant's output
            if sc > 0 and sc >= 0.5 * best and len(rare) >= 2 and any(r in in_prompt for r in rare):
                picked_sessions.append((sc, hits, s))
        picked_sessions = picked_sessions[:max_sessions]
        chosen = {id(s) for _, _, s in picked_sessions}
        file_terms = set()
        for _, _, rel in picked_files:
            file_terms |= set(tokenize(m["files"][rel]["module"]))
        for s in sessions:
            if id(s) in chosen:
                continue
            for sent in decision_sentences(s.get("prompt", "")):
                st = set(tokenize(sent))
                if ({t for t in st & qset if gidf.get(t, 0) >= 1.0} or st & file_terms):
                    decisions.append((sent, s))

    # ---- render, cheapest/most general first, stop at budget ----
    out = ["# DevMemory context pack",
           "Retrieved for this task from a deterministic project index"
           + (" and captured past sessions" if mode != "static" else "")
           + ". Current files are authoritative; start from the files listed instead of re-exploring the "
             "whole project" + ("; verify anything marked STALE before relying on it." if mode == "full" else "."),
           "",
           f"Project: {m['project']} ({m['engine']})"
           + (". Rojo: " + ", ".join(f"{k} -> {v}" for k, v in m["rojo"].items()) if m.get("rojo") else ""),
           "", "## Conventions (observed in code)"]
    out += [f"- {l}" for l in convention_lines(m)[:10]]
    info = {"mode": mode, "files": [], "sessions": [], "stale": 0, "items": 0}

    def fits(extra: list[str]) -> bool:
        return estimate_tokens("\n".join(out + extra)) <= budget

    if picked_files:
        out += ["", "## Relevant files"]
        for s, hits, rel in picked_files:
            i = m["files"][rel]
            role = []
            if i.get("symbols"):
                role.append("fn " + ", ".join(x.split(".")[-1].split(":")[-1] for x in i["symbols"][:6]))
            if i.get("remotes_defined"):
                role.append("defines " + ", ".join(i["remotes_defined"]))
            if i.get("remotes_used"):
                role.append("remotes " + ", ".join(f"{k}({'/'.join(v)})" for k, v in i["remotes_used"].items()))
            used = len(m.get("used_by", {}).get(rel, []))
            block = [f"- `{rel}` [{i['lines']} lines{', used by %d' % used if used else ''}] "
                     f"{'; '.join(role)[:220]} — matched: {', '.join(hits)}"]
            for n, line in _evidence_lines(texts[rel], qset):
                block.append(f"  - L{n}: `{line}`")
            if not fits(block):
                break
            out += block
            info["files"].append(rel)

    if picked_sessions:
        out += ["", "## Relevant past sessions"]
        for sc, hits, s in picked_sessions:
            fr = freshness(s, project) if mode == "full" else None
            flag = ""
            if fr and fr["status"] in ("stale", "partly-stale"):
                flag = (f" **{fr['status'].upper()}**: edits no longer present in "
                        f"{', '.join(fr['edits_gone_from'])}; code changed after this session, verify current code.")
                info["stale"] += 1
            elif fr and fr["status"] == "context-changed":
                flag = f" (files it read have changed since: {', '.join(fr['read_files_changed'][:4])})"
            prompt = re.sub(r"\s+", " ", s.get("prompt", ""))[:700]
            result = re.sub(r"\s+", " ", s.get("result_text") or "")[:350]
            block = [f"- [session {str(s.get('session_id'))[:8]}, {s.get('started_at', '')[:10]}, "
                     f"src: sessions/{s.get('raw_record')}]{flag}",
                     f"  - User asked: \"{prompt}\"",
                     f"  - Outcome (assistant-visible summary): {result}"]
            if s.get("files_edited"):
                block.append(f"  - Edited then: {', '.join(s['files_edited'])}")
            if not fits(block):
                break
            out += block
            info["sessions"].append({"session": s.get("session_id"), "score": round(sc, 2), "matched": hits,
                                     "freshness": fr["status"] if fr else None})
    if decisions:
        block = ["", "## Standing decisions stated by the user in past sessions"]
        seen = set()
        for sent, s in decisions[:4]:
            if sent in seen:
                continue
            seen.add(sent)
            block.append(f"- \"{sent}\" [session {str(s.get('session_id'))[:8]}, {s.get('started_at', '')[:10]}]")
        if fits(block):
            out += block
            info["decisions"] = len(seen)
    text = "\n".join(out) + "\n"
    info["items"] = len(info["files"]) + len(info["sessions"]) + info.get("decisions", 0)
    info["tokens_est"] = estimate_tokens(text)
    return text, info
