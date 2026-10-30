"""Run headless Claude Code (`claude -p`) and parse its documented stream-json output.

Only documented CLI output is used: `--output-format stream-json --verbose` events
(system/init, assistant, user, rate_limit_event, result). No private transcript files.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import time
from pathlib import Path

# Identical isolation flags for every eval run (see bench/TELEMETRY.md).
DEFAULT_TOOLS = ["Read", "Edit", "Write", "Glob", "Grep", "Bash"]
FILE_READ_TOOLS = {"Read"}
FILE_EDIT_TOOLS = {"Edit", "Write", "NotebookEdit"}
SEARCH_TOOLS = {"Glob", "Grep"}


def claude_executable() -> str:
    """Resolve the real claude binary. The npm .cmd shim goes through cmd.exe, which
    breaks multi-line arguments, so prefer the bundled claude.exe when present."""
    env = os.environ.get("DEVMEM_CLAUDE")
    if env:
        return env
    found = shutil.which("claude")
    if not found:
        raise FileNotFoundError("claude CLI not found on PATH (set DEVMEM_CLAUDE)")
    p = Path(found)
    if p.suffix.lower() in {".cmd", ".bat", ""}:
        exe = p.parent / "node_modules" / "@anthropic-ai" / "claude-code" / "bin" / "claude.exe"
        if exe.exists():
            return str(exe)
    return found


def build_command(prompt: str, model: str, max_turns: int, append_system_prompt: str | None = None,
                  tools: list[str] | None = None, isolated: bool = True) -> list[str]:
    cmd = [claude_executable(), "-p", prompt, "--output-format", "stream-json", "--verbose",
           "--model", model, "--max-turns", str(max_turns),
           "--permission-mode", "acceptEdits", "--no-session-persistence"]
    if isolated:
        cmd += ["--setting-sources", "project", "--strict-mcp-config"]
    cmd += ["--tools", *(tools or DEFAULT_TOOLS)]
    if append_system_prompt:
        cmd += ["--append-system-prompt", append_system_prompt]
    return cmd


def run_claude(prompt: str, cwd: Path, stream_out: Path, model: str = "haiku", max_turns: int = 30,
               append_system_prompt: str | None = None, tools: list[str] | None = None,
               timeout_s: int = 900, isolated: bool = True) -> dict:
    """Run one headless session in `cwd`, write the raw stream to `stream_out`, return metrics."""
    cmd = build_command(prompt, model, max_turns, append_system_prompt, tools, isolated)
    stream_out.parent.mkdir(parents=True, exist_ok=True)
    t0 = time.time()
    with open(stream_out, "w", encoding="utf-8", newline="\n") as f:
        try:
            proc = subprocess.run(cmd, cwd=str(cwd), stdin=subprocess.DEVNULL, stdout=f,
                                  stderr=subprocess.PIPE, timeout=timeout_s, text=True,
                                  encoding="utf-8", errors="replace")
            rc, stderr = proc.returncode, proc.stderr
        except subprocess.TimeoutExpired:
            rc, stderr = -1, "timeout"
    metrics = parse_stream(stream_out, cwd)
    metrics["exit_code"] = rc
    metrics["wall_s"] = round(time.time() - t0, 2)
    if rc != 0:
        metrics["stderr_tail"] = (stderr or "")[-500:]
    return metrics


def _rel(path: str, cwd: Path) -> str:
    try:
        return Path(path).resolve().relative_to(cwd.resolve()).as_posix()
    except (ValueError, OSError):
        return path.replace("\\", "/")


def parse_stream(stream_path: Path, cwd: Path | None = None) -> dict:
    """Summarize a stream-json file into flat metrics. Missing fields stay None."""
    events = []
    for line in Path(stream_path).read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if line:
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError:
                pass
    m: dict = {"session_id": None, "model": None, "tool_calls": 0, "tool_counts": {},
               "files_read": [], "files_edited": [], "search_calls": 0, "tool_errors": 0,
               "rate_limit": None, "result_text": None, "is_error": None, "subtype": None,
               "num_turns": None, "cost_usd_list": None, "duration_ms": None,
               "input_tokens": None, "output_tokens": None, "cache_read_tokens": None,
               "cache_creation_tokens": None, "total_input_tokens": None}
    root = cwd or Path(".")
    for e in events:
        t = e.get("type")
        if t == "system" and e.get("subtype") == "init":
            m["session_id"], m["model"] = e.get("session_id"), e.get("model")
        elif t == "assistant":
            for b in e.get("message", {}).get("content", []) or []:
                if b.get("type") != "tool_use":
                    continue
                name, inp = b.get("name"), b.get("input") or {}
                m["tool_calls"] += 1
                m["tool_counts"][name] = m["tool_counts"].get(name, 0) + 1
                fp = inp.get("file_path")
                if name in FILE_READ_TOOLS and fp:
                    m["files_read"].append(_rel(fp, root))
                elif name in FILE_EDIT_TOOLS and fp:
                    m["files_edited"].append(_rel(fp, root))
                elif name in SEARCH_TOOLS:
                    m["search_calls"] += 1
        elif t == "user":
            content = e.get("message", {}).get("content")
            if isinstance(content, list):
                m["tool_errors"] += sum(1 for b in content
                                        if isinstance(b, dict) and b.get("type") == "tool_result" and b.get("is_error"))
        elif t == "rate_limit_event":
            info = e.get("rate_limit_info", {}).get("unifiedWindows", {})
            m["rate_limit"] = {k: v.get("utilization") for k, v in info.items()}
        elif t == "result":
            u = e.get("usage") or {}
            m.update(session_id=e.get("session_id") or m["session_id"], result_text=e.get("result"),
                     is_error=e.get("is_error"), subtype=e.get("subtype"), num_turns=e.get("num_turns"),
                     cost_usd_list=e.get("total_cost_usd"), duration_ms=e.get("duration_ms"),
                     input_tokens=u.get("input_tokens"), output_tokens=u.get("output_tokens"),
                     cache_read_tokens=u.get("cache_read_input_tokens"),
                     cache_creation_tokens=u.get("cache_creation_input_tokens"))
            parts = [m["input_tokens"], m["cache_read_tokens"], m["cache_creation_tokens"]]
            if all(p is not None for p in parts):
                m["total_input_tokens"] = sum(parts)
    m["files_read_unique"] = len(set(m["files_read"]))
    return m
