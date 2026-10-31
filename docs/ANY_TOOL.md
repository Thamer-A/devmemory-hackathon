# Using DevMemory with any AI coding tool

DevMemory has three parts, and only one of them depends on the AI tool:

| Part | Tool-specific? | How it works with any tool |
|---|---|---|
| **Scan** (project map) | No | Deterministic, 0 LLM tokens. |
| **Pack** (task context) | No | Plain Markdown. Any model can read it. |
| **Capture** (session memory) | Partly | Claude Code: full stream-json record. Codex: `codex exec --json` events plus the observed diff. Any other tool: snapshot diff of the project, plus whatever output the tool shows. |

All captures are written in the same session format, so retrieval, origin lineage and line-level STALE flags work the same whichever tool made the memory. Memory made in one tool can be used in another (see the demo below).

## 1. MCP server (any MCP client)

```
python -m devmem.cli mcp --project <your project>
```

Tools: `get_context_pack(task)`, `list_sessions()`, `read_session(id)`, `begin_session()`, `end_session(prompt, summary)`. Every call is logged to `.devmemory/mcp_calls.jsonl`. When a client sends a summary through `end_session`, it is stored labelled as the assistant's self-report. The diff is computed by DevMemory itself.

- **Claude Code:** `--mcp-config` with `{"mcpServers": {"devmemory": {"command": "python", "args": ["-m", "devmem.cli", "mcp", "--project", "<dir>"]}}}`. **Tested.** Claude called `get_context_pack` and used the STALE flag in its answer.
- **Codex CLI:** `codex mcp add devmemory -- python -m devmem.cli mcp --project <dir>`, or for a single run, `devmem codex "<task>" --mcp`. That passes `-c mcp_servers.devmemory...` overrides and leaves your Codex config unchanged. **Tested.** Headless `codex exec` cannot ask for approval, so DevMemory's tools need `mcp_servers.devmemory.tools.<tool>.approval_mode = "approve"`; `devmem codex --mcp` sets this for the run.
- **Other MCP clients** that use the standard `mcpServers` JSON (Cursor, Claude Desktop, VS Code and others): same command. Not tested here.

## 2. Wrap any command-line agent

```
python -m devmem.cli wrap --prompt "<task>" --provider aider -- <agent command with {prompt} or {pack_file}>
```

DevMemory builds the pack, puts it into the command (`{prompt}` = pack + task, `{pack_file}` = path to the pack; also in `$DEVMEM_PACK_FILE`), snapshots the project before and after, and records the session.

## 3. IDE agents without a command line (Cursor, Copilot, ...)

```
python -m devmem.cli begin
... work in the IDE ...
python -m devmem.cli end --prompt "<what you asked>" --provider cursor [--summary "<what it did>"]
```

To give the IDE agent the pack, run `python -m devmem.cli pack "<task>" --out context.md` and attach the file, or use the MCP server.

## 4. Codex CLI adapter

```
python -m devmem.cli codex "<task>" [--model M] [--no-pack | --mcp]
```

Uses Codex's documented flags: `exec --json`, `-o` (final message), `-C` and `--sandbox workspace-write`. Its JSONL events, final message, token usage and errors are stored with the observed diff.

## What capture can and cannot see per tool

- **Claude Code:** prompts, visible replies, every tool call and result, files read and edited, usage.
- **Codex CLI:** prompt, agent messages, command runs, file changes and usage from `--json`, plus the observed diff.
- **Any other tool:** prompt, the observed diff, and the tool's visible output. Files it only *read* are not observable; that field is left empty, never guessed.
