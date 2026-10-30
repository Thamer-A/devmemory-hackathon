# Challenge 2 Plan: Persistent Project Memory for AI-Assisted Development

**Working name:** DevMemory (placeholder)  
**Challenge:** Deliver AI With Less Compute  
**First demonstration domain:** Game development, with Roblox Studio as the initial integration  
**Product direction:** A general project-memory layer that can onboard an AI assistant to an existing workspace, capture accessible development activity as work happens, and provide relevant context to later sessions.

## 1. Executive summary

Build a local-first application that turns a project folder into a searchable, evolving memory vault for AI-assisted work. When pointed at an existing project, it scans the workspace, maps its structure, identifies scripts/assets/configuration and generates source-linked onboarding notes. For a new project, it begins with a lightweight project profile and incrementally records the work that the supported AI tools expose: prompts, responses, tool calls and results, commands, errors, file changes, and session metadata.

The system retains the accessible source record, but does **not** dump the whole archive into every prompt. It maintains a compact always-available project map and retrieves a task-specific context pack from project facts, asset guides, decisions, prior sessions, and relevant source files. The goal is to reduce repeated exploration and context tokens without reducing task quality.

Use Roblox Studio to make the idea concrete: onboard a Roblox project, teach the system how the place is structured and how key assets/scripts work, then show a fresh AI session completing a follow-up task with less rediscovery. Keep the architecture engine-agnostic so the same project scan, event schema, storage, search, and retrieval can later work with Unity, Unreal, Godot, and ordinary software projects.

## 2. Why this fits Challenge 2

The orientation describes Challenge 2 as delivering high-quality AI results with fewer resources. It explicitly suggests simplifying the process, reducing unnecessary processing, and checking results without excessive compute. DevMemory addresses a recurring source of waste: each fresh model session reopens files, rediscovers conventions, explores assets, repeats questions, and may redo earlier investigations.

The pitch should avoid claiming that persistent memory automatically saves compute. It creates an upfront indexing and capture cost, and retrieval can add overhead. The product must measure the full lifecycle and show the point at which repeated work pays back that investment.

**Core hypothesis:** For repeated development tasks in the same project, DevMemory can reduce input tokens and repeated project exploration while maintaining or improving task success and output quality.

## 3. Product definition

### User problem

AI coding assistants often start each new task or session without durable, project-specific context. Developers compensate by manually explaining the project, pasting notes, asking the model to inspect the repository again, or maintaining an Obsidian vault and instructions themselves. This onboarding effort is especially wasteful in game projects, where important knowledge is distributed across code, scenes/places, assets, naming conventions, engine settings, and editor-specific workflows.

### Proposed solution

DevMemory automates three jobs:

1. **Understand the workspace:** scan and index the project, then generate useful, evidence-linked onboarding material.
2. **Remember accessible work:** capture the interactions and development events exposed by supported tools, keeping the original record and building structured indexes over it.
3. **Prepare the next task:** retrieve only relevant context and provide it to the assistant through a file, prompt pack, CLI command, MCP tool, or supported hook.

### Product principles

- **Keep the source record; retrieve selectively.** “Save everything” means everything the connected tool can access and the user has enabled, not blindly collecting every machine event or transmitting the entire archive to a model.
- **Show evidence.** Generated facts should link to the file, asset, session, tool result, or user confirmation that supports them.
- **Separate observation from inference.** Mark which information came directly from the project/session and which was model-generated interpretation.
- **Make correction and deletion easy.** Users can inspect, edit, exclude, export, and delete the vault and captured sessions.
- **Be project-local by default.** Store the vault in or alongside the project, provide `.gitignore` choices, and never include credentials or unrelated personal files in scans.
- **Stay provider- and engine-adaptable.** The memory core should not depend on private APIs or one model vendor.
- **Measure quality as well as tokens.** A shorter prompt is not a win if it omits crucial context or degrades the result.

## 4. What “preserve everything” means in practice

The application can preserve a broad, auditable **development trace** where integrations expose it:

- User prompts and assistant-visible responses
- Tool calls, tool inputs, and tool outputs
- Commands and their captured output
- Files read, written, or changed when reported by the client
- Error messages, test/playtest results, screenshots, and session timestamps when available
- Model/provider/session metadata and token/usage data when the integration reports it

This is distinct from private model chain-of-thought. A provider may show a “thinking” status, a summarized rationale, or structured tool activity, but that does not mean an integration can retrieve the model’s full hidden internal reasoning. The product should store visible explanations and permitted summaries as such, never label them “complete chain-of-thought,” and make tool traces and outcomes the primary reusable evidence. This avoids designing the product around access that may not exist and keeps the memory grounded in reproducible project artifacts.

“Everything accessible” also needs user controls and redaction. A development transcript may contain secrets, customer data, personal text, or proprietary code. Provide excluded paths, secret-pattern redaction, retention controls, and an explicit local-only mode. Do not silently copy data to a cloud service.

## 5. Research findings and design implications

### Obsidian as a useful product model

Obsidian stores notes as Markdown plain-text files in a local folder called a vault. Its value for this idea is less about a special database and more about a transparent folder of durable, searchable, linkable project knowledge that humans can open and edit. A useful AI-development vault pattern combines a small project entry point, focused topic notes, cross-links, and original evidence/session records. This makes the information portable and lets a person inspect what the assistant will see.

Developers using Obsidian with coding agents commonly use it to hold project instructions, architecture notes, task state, asset/domain guides, decisions, and session handoffs. The token-saving pattern is to tell the agent where to look and retrieve targeted notes rather than loading the full vault. DevMemory’s differentiator should be reducing the manual work: automatic initial project onboarding, broad event capture, evidence links, and retrieval/context assembly.

### Specific Roblox and game-development Obsidian workflows

There is a visible Roblox-specific pattern behind the idea: creators are using a large curated “brain” alongside Claude Code and Roblox Studio integrations to teach the assistant Roblox conventions, project-specific rules, reusable skills, and how to use assets. One public Roblox creator workflow/course describes a full stack of **Obsidian memory + Claude Code + Roblox Studio MCP + custom skills + hooks/subagents**, with separate lessons for designing/building the vault, teaching Claude to use it, Roblox MCP setup, building an asset library, and playtesting. This closely matches the user’s observation: the vault acts as persistent domain and project onboarding, while Studio MCP provides the live “hands” inside the game editor. The published course is a creator’s description of a workflow, not an independent benchmark or a guarantee of measured token savings.

Another public Roblox/game-studio case study describes an Obsidian vault mirroring agent runs, approvals, notes, and status maps while agents use Roblox Studio MCP to build and test a game. That suggests a second useful pattern: use the vault as an auditable production log and human approval dashboard, not just a static documentation folder. A recently indexed creator video explicitly advertises a **40GB+ Obsidian vault for Roblox developers**, designed to help AI tools understand Studio, scripting, and game design. The listing confirms that this kind of very large Roblox knowledge vault is being promoted and watched; it does not expose the full vault contents, verify its size, or prove that 40GB of material is efficient to retrieve.

For broader game development, the underlying challenge is that game knowledge spans source code and engine data: scenes/places, prefabs/models, assets, script references, object hierarchies, configuration, runtime state, and playtest outcomes. A 2026 Unity code/asset-index preprint describes a production index that joins C# scripts to scenes, prefabs, ScriptableObjects, and GUID-linked assets, and reports a paired evaluation where its index-backed agent used about 53% fewer tokens on 28 project questions. This is promising evidence for **typed project/asset indexing**, but it is one system and a limited evaluation; it is not evidence that an Obsidian vault alone produces the same savings, and its setup cost was excluded from the reported task-session totals.

#### What these workflows teach DevMemory

- **Separate the reusable game-development handbook from project-specific memory.** The handbook teaches Luau/engine workflows, debugging patterns, Studio operations, asset pipelines, and how to use MCP tools. The project layer records this game’s systems, style, architecture, assets, naming, design decisions, and bugs. Retrieval should blend the two only as needed.
- **Treat assets as first-class project knowledge.** For each asset, capture stable identifiers/paths, type, dimensions or metadata when available, source/license/ownership if known, linked scripts/scenes, intended gameplay/UI role, relevant constraints, and verified examples. Do not assume an asset name alone communicates its use.
- **Represent reusable actions as tested skills/workflows.** Examples include “add a new interactable,” “wire a RemoteEvent safely,” “create a UI panel that follows the project style,” “import/replace an asset,” and “run a playtest for this mechanic.” Each skill should include prerequisites, steps, expected result, and a check—not just prose instructions.
- **Connect memory to live editor state.** In Roblox, use Studio MCP to inspect the game tree/scripts, run Luau, view output, start playtests, and capture screenshots where supported. For other engines, adapters should map equivalent scene/object and runtime concepts.
- **Keep approval and verification records.** Store what was proposed, what a human approved or corrected, what changed in the engine, and what the playtest showed. This turns corrections into reliable project-specific guidance while retaining the raw trace.
- **Avoid brute-force context loading.** A huge vault is useful as a corpus, not as a prompt. Build catalogs, typed indexes, topic pages, and task retrieval. Return a few relevant source-backed passages and expand on request.
- **Design for freshness.** Engine APIs, plugins, imported assets, and project structure change. Label knowledge with source/date/version and mark obsolete or conflicting instructions instead of silently carrying them forward.

#### Roblox-first knowledge taxonomy

```text
Game development handbook/
  Roblox Studio operations/
  Luau patterns/
  client-server and replication/
  UI and input/
  physics and character systems/
  performance and debugging/
  asset import, IDs, licensing, and optimization/
  MCP tools and verified workflows/

This project/
  game design and constraints/
  architecture and gameplay systems/
  scripts and module relationships/
  place/tree map/
  asset catalog and usage recipes/
  UI/style guide/
  decisions, bugs, and playtest results/
  session history and handoffs/
```

This taxonomy is an initial schema, not a fixed folder religion. A project may need very different areas—for example, an animation-heavy game, a procedural world, or a monetized live-service experience.

### Existing agent integration mechanisms

- **Claude Code:** its documented hooks run on selected lifecycle/tool events and can receive structured event input. Hook configuration can support capture or context injection. Claude Code also provides CLI output modes, including JSON and streaming JSON for programmatic flows. The adapter should use documented interfaces where possible and treat internal transcript file layouts as version-sensitive implementation details.
- **Codex CLI:** `codex exec --json` emits newline-delimited JSON events, suitable for an adapter to capture assistant-visible events from a controlled CLI session. The Codex CLI also supports session resume/fork behavior, but the MVP should not depend on private desktop storage formats.
- **MCP:** a standard tool boundary can expose project-memory operations such as `search_memory`, `get_project_map`, `get_asset_guide`, `record_decision`, and `prepare_context`. An MCP adapter makes the vault usable by multiple compatible agents, while hooks/CLI adapters provide lifecycle capture where available.
- **Roblox Studio:** Roblox documents Studio MCP and its development workflows. Studio MCP can let connected agents inspect game structure and interact with scripts, models, play mode, and related development tools, which makes Roblox an unusually clear test domain for project-aware memory. Availability and exact tools can vary by Studio/client version, so the demo should validate the installed setup early.

### Implications

Build the memory core around stable internal event and artifact schemas, not one vendor’s transcript format. Use integrations to capture what they officially expose, and let users import supported logs when live hooks are unavailable. For game projects, index relationships among code, assets, scenes/places, and runtime/editor observations rather than indexing source text alone. Keep the initial search simple and explainable; a typed index plus path/symbol/keyword search may be more useful and cheaper than starting with embeddings and a vector database.

## 6. User workflows

### A. Existing project onboarding

1. User selects a project directory and confirms the scan scope.
2. DevMemory detects likely project type/engine and inventories files, scripts, assets, configuration, dependency manifests, and version-control metadata.
3. It excludes common generated/build/cache folders, secrets, and user-selected paths. It does not upload files by default.
4. It builds a local search index and produces an initial project map, such as:
   - project overview and detected engine/toolchain
   - folder and module map
   - entry points and important systems
   - asset inventory with IDs/paths and probable uses
   - build, run, test, and playtest instructions where detectable
   - open questions and low-confidence inferences
5. Every generated note includes evidence links to source paths and an “inferred” marker where appropriate.
6. User reviews/edits the generated overview, chooses an AI adapter, and runs a task.

### B. New project from the first session

1. User creates/opens a project and enables DevMemory capture for the chosen assistant.
2. DevMemory creates a minimal project profile and begins recording supported session events.
3. File changes and new assets update the project index incrementally.
4. At session end, DevMemory creates a compact handoff: what changed, decisions made, errors/results, and likely next steps, with links to the full event record.
5. For a new task, the user or agent asks DevMemory to prepare context. It returns a small pack tailored to the task.

### C. Cross-session/cross-model continuation

A new assistant can retrieve project instructions, a relevant asset guide, prior decisions, and the last related session even if the original session was in another model/tool. The new model should see source citations and session metadata so it can verify rather than blindly trust inherited summaries.

## 7. Proposed vault layout

Keep it understandable to developers and usable without the application:

```text
<project>/
  .devmemory/
    config.yaml                 # capture, ignore, redaction, and integration settings
    PROJECT.md                  # short always-loadable project map and retrieval instructions
    index/                      # rebuildable file/search metadata; optionally gitignored
    sources/
      files/                    # optional extracted metadata, not duplicate source files
      assets/                   # inventories and thumbnails/previews where supported
    knowledge/
      architecture.md
      systems/
      assets/
      workflows/
      decisions/
      questions.md
    sessions/
      2026-10-29_<session-id>.jsonl  # append-only accessible event record
      summaries/                # compact, source-linked handoffs
    context-packs/              # reproducible task retrieval output, optionally ephemeral
```

Treat the project’s own files as authoritative. Avoid copying large binary assets into the vault. Store metadata, hashes, paths, relationships, and previews when safe; read actual source files only when retrieval requires them. Let the user choose whether session logs and derived knowledge are committed to Git. Include a conservative default ignore file and explain that local transcripts can contain sensitive material.

## 8. System architecture

### Core components

1. **Project scanner:** walks configured roots; detects engine/language/manifests; applies ignore rules and secret/path exclusions; extracts text and metadata; hashes files for incremental updates.
2. **Engine adapters:** interpret domain-specific project files/assets. First adapter: Roblox/Luau and Studio-connected structure. Later adapters can cover Unity, Unreal, Godot, and generic repositories.
3. **Session adapters:** accept provider events, hook input, JSONL streams, imports, and tool events, then normalize them into a common schema.
4. **Event store:** append-only JSONL or SQLite-backed records for event integrity and filtering. Preserve original raw event payload when permitted, alongside normalized fields.
5. **Knowledge builder:** generate concise notes and relationships from the project and session evidence; attach source IDs, timestamps, confidence, and provenance.
6. **Search/retrieval:** keyword/path/symbol search first; optional embeddings/reranking later. Combine query relevance with recency and confidence, deduplicate, enforce token budget, and return source citations.
7. **Context delivery:** CLI command and/or MCP server for MVP; optional provider hooks add context automatically at session start or before a task.
8. **Human-facing viewer:** a small local UI or Markdown vault browsing workflow for search, source inspection, editing, and deletion. Obsidian compatibility is a feature, not a dependency.

### Example normalized event schema

```json
{
  "event_id": "uuid",
  "session_id": "provider-session-id",
  "timestamp": "ISO-8601",
  "provider": "claude-code|codex|other",
  "event_type": "user_message|assistant_message|tool_call|tool_result|file_change|command|error|usage",
  "actor": "user|assistant|tool|system",
  "tool_name": null,
  "content": "captured content when available",
  "project_paths": [],
  "token_usage": {"input": null, "output": null, "cached_input": null},
  "source_ref": "path/session/event anchor",
  "redactions": [],
  "capture_method": "hook|jsonl|import|mcp|manual"
}
```

The event schema must allow missing fields and provider-specific metadata. Never fabricate token usage or claim an event is complete when the provider only supplied a partial stream.

### Context retrieval flow

```text
Task request
    ↓
Parse intent + identify engine/files/systems/assets
    ↓
Search project map, symbols, asset metadata, decisions, and session records
    ↓
Rank by relevance + freshness + confidence; filter secrets/stale notes
    ↓
Fit within context budget; include source paths and evidence snippets
    ↓
Deliver context pack to the assistant; log pack size and sources
    ↓
Capture resulting work and update indexes/knowledge
```

The context pack should be inspectable and reproducible. A developer should be able to see what was retrieved, why each item was included, and approximate token cost.

## 9. MVP scope for the hackathon

### Must build

- Local project folder selection and configurable ignore/exclusion rules.
- Generic file inventory, text indexing, and project map generation.
- One usable session-capture route (prefer a documented CLI JSON/stream or hook route that can be demonstrated reliably).
- One query/context-pack command with source links and a maximum token budget.
- Session summary/handoff linked to the original event record.
- A Roblox Studio test path: project scan plus a real Studio-connected or source-export based workflow.
- Basic token and quality measurement for repeated tasks.

### Good stretch items

- Roblox asset inventory/relationships and generated asset-use notes.
- MCP server exposing search and context tools.
- Second provider adapter to demonstrate portability.
- Obsidian-openable Markdown navigation and graph links.
- Embedding search, only if keyword/path retrieval proves inadequate.
- Simple local UI showing the vault, retrieved context, token counts, and source provenance.

### Deliberately defer

- Full support for every game engine/editor/provider.
- Autonomous rewriting of all project documentation.
- Cloud sync, team accounts, or a hosted vector database.
- Capturing hidden model reasoning or reverse-engineering private transcript formats.
- Complex ontology/knowledge-graph reasoning before a measurable retrieval need exists.
- Automatic changes to game files or publishing/deploying without an explicit user action.

## 10. Roblox demonstration design

### Test project setup

Choose a small but non-trivial Roblox project with several interconnected components: for example, an inventory/shop interaction, an enemy behavior, or a round-based gameplay loop. Include a mix of scripts, assets, RemoteEvents/RemoteFunctions, UI, and at least one project-specific convention that is easy to forget. Avoid building a giant game from scratch during the hackathon.

### Scenario

1. Run DevMemory’s initial scan on the project. Show the discovered structure and generated notes for key systems/assets, including evidence links.
2. Ask an AI assistant to implement or debug a first task. Capture the accessible interaction and file/tool events. Have Studio playtest/verification evidence recorded if supported.
3. End that session.
4. Start a new session with a related task that depends on earlier project decisions or an asset convention. Run both baseline and DevMemory variants.
5. Show the DevMemory context pack: project rules, relevant asset/system note, prior decision, and relevant session outcome. Show that unrelated vault records were not injected.
6. Compare token usage and task quality, then open the resulting change and playtest result in Studio.

### Demo principle

The compelling “wow” is not that the system generated many notes. It is that it automatically learned enough about an existing game, preserved what happened, and let a fresh model continue correctly without a long re-onboarding conversation.

## 11. Evaluation plan: prove savings and preserve quality

### Experimental comparison

For 3–5 representative Roblox/game-development tasks, create paired runs:

- **Baseline:** a fresh assistant session with the same user request and normal manual/project context, with no DevMemory retrieval.
- **DevMemory:** a fresh assistant session with the same user request and DevMemory’s generated/retrieved context pack.

Keep model, model settings, tool permissions, task, and verification rubric the same. If possible, use the same project snapshot and alternate run order to reduce order effects. Do not compare a warm ongoing chat against a cold memory-assisted session.

### Metrics

- Input tokens; output tokens; cached tokens if exposed
- Total measured tokens including initial scan/capture/summary/indexing model calls
- Number of files opened or searched / exploration tool calls
- Time to first useful code change and total completion time
- Task success against a predefined checklist
- Defects, missing constraints, and rework required
- Retrieval precision: relevant items retrieved vs irrelevant context included
- Onboarding coverage: project systems/assets discovered correctly
- Break-even point: number of follow-up tasks/sessions before cumulative tokens or cost are lower than baseline

### Calculation

For N tasks:

```text
baseline_total = Σ baseline_tokens(task_i)
devmemory_total = indexing_tokens + capture_and_summary_tokens + Σ retrieval_and_task_tokens(task_i)
token_savings_percent = (baseline_total - devmemory_total) / baseline_total × 100
```

Report token savings only alongside quality and coverage. If subscription-based tools do not expose exact token counts, label estimates clearly and use consistent proxy metrics such as context size, number of tool reads, or measured API usage from an eligible route. Do not mix token counts from different providers without labeling them.

### Success criteria (initial targets, revise after a pilot)

- Initial scan produces a useful, human-correctable project map with traceable evidence.
- The follow-up task’s context pack is materially smaller than replaying the full prior conversation/project exploration.
- Across repeated tasks, cumulative input tokens or repeated exploration calls fall by a meaningful amount (target: ≥25% after onboarding amortizes).
- Task success is no worse than baseline under the same rubric; ideally fewer missed project conventions.
- User can identify where each important retrieved instruction came from.
- Capture and context delivery work reliably in the recorded demo without relying on undocumented private file formats.

These are prototype targets, not guaranteed results. The final presentation should report actual results, including any tasks where memory failed.

## 12. Build sequence and decision gates

### Phase 1 — Narrow and validate (first 1–2 hours)

- Read the official platform’s complete Challenge 2 brief and judging rubric when published; the orientation said detailed challenge information and criteria would appear on the platform.
- Pick one test game project and 3–5 repeatable follow-up tasks.
- Check which assistant/editor workflows are actually available on the hackathon machine.
- Confirm Roblox Studio MCP / project export setup early, and determine the simplest verifiable task.
- Inspect token/usage visibility for the selected assistant path.
- Decide the MVP capture interface based on the documented tools available today.

**Gate:** If live hooks are unreliable, use supported JSONL export/import or a manual session-log import for the demo, and be transparent about what is automated.

### Phase 2 — Project onboarding (next 2–4 hours)

- Implement scoped scanner, ignore rules, file hashes, basic text search, and project map.
- Generate concise Markdown notes with source paths, confidence, and last scanned timestamp.
- Test the scan on the selected game project and manually correct the most important errors.

**Gate:** Stop expanding file-type support when the chosen project’s important code/assets are covered.

### Phase 3 — Session capture and memory (next 3–5 hours)

- Implement one provider/session adapter and normalize captured records.
- Save append-only session events and compact source-linked handoffs.
- Add privacy controls: excludes, redaction, local storage, and visible capture state.
- Verify a second session’s events are added without corrupting the first.

### Phase 4 — Retrieval/context assembly (next 2–4 hours)

- Implement task query, keyword/path/symbol search, ranking, deduplication, and token budget.
- Return a context pack with source snippets and retrieval reasons.
- Deliver it through the easiest reliable path: CLI-generated prompt/file, MCP tool, or adapter hook.
- Log selected records and approximate/exact context size.

### Phase 5 — Evaluation and demo polish (remaining time)

- Run paired baseline and memory-assisted tasks.
- Fix only retrieval or onboarding failures that affect the demo’s core claim.
- Capture screens and token/quality results.
- Prepare a concise narrative and slides; record a 3–4 minute demo video as required by the orientation.
- Publish the project page by the stated deadline and verify publication.

## 13. Risks and mitigations

| Risk | Why it matters | Mitigation |
|---|---|---|
| No access to private chain-of-thought | The original framing could promise data the product cannot obtain | Call it an accessible development trace; preserve tool activity and visible explanations, not hidden reasoning |
| Logs include secrets or sensitive data | Sessions and project files may contain credentials/proprietary content | Local-first default, path exclusions, secret redaction, retention/delete controls, no cloud upload by default |
| Vault grows without bounds | Full event retention increases disk/index cost and retrieval noise | Append-only compressed source records, retention/archival settings, indexes separate from source, relevance-based retrieval |
| Bad generated notes become false “facts” | A later model may repeat a mistaken inference | Evidence links, confidence/provenance, freshness, conflict handling, user correction, source-of-truth priority |
| Retrieval misses crucial context | Fewer tokens can lower output quality | Measure recall/precision and task quality; retrieve project map plus targeted notes; allow “show why” and broader search |
| Upfront scan costs exceed savings | Challenge claim may fail for one-off tasks | Measure break-even by repeated tasks; fast local parsing first, optional model enrichment, incremental rescans |
| Integration churn | Provider session formats and editor tools change | Use documented hooks/CLI/MCP interfaces; modular adapters; schema versioning; import/export fallback |
| Game asset binaries are large/opaque | Text-only indexing misses important asset knowledge | Index names, IDs, metadata, references, thumbnails/previews when possible; use Studio MCP inspection where appropriate |
| Broad scope dilutes demo | “Works for everything” is hard to prove in a short hackathon | General core, one polished game-development demonstration; name future adapters as roadmap |

## 14. Suggested project-page language

### Name

**DevMemory** (placeholder; check naming availability before finalizing)

### Short description

An automatic, local-first memory vault that onboards AI assistants to a development project, preserves accessible work history, and retrieves the right context for future tasks to reduce repeated exploration and token use.

### Issue

AI assistants repeatedly spend time and context rediscovering project structure, tools, assets, decisions, and workflows across sessions. Manually maintained notes help, but take effort and may omit useful details. Replaying entire histories wastes context and still makes it hard to find the relevant evidence.

### Our solution

DevMemory scans an existing workspace to build a source-linked project vault, then captures accessible AI-assisted development activity over time. For each new task, it retrieves a compact, relevant context pack instead of sending the full archive. It is general-purpose in architecture and demonstrated on a Roblox game-development project.

### Differentiation

The project combines automatic project onboarding, broad accessible trace capture, human-readable local memory, evidence-linked knowledge, and token-budgeted retrieval. It measures the cost of creating memory against the savings and task quality of reusing it.

## 15. Three-to-four-minute demo script

1. **Problem (20–30 sec):** Fresh AI sessions repeatedly rediscover how a game is built and how its assets/systems should be used.
2. **Point at project (35–45 sec):** DevMemory scans the Roblox project and creates a navigable map and relevant system/asset notes with source links.
3. **Capture work (30–40 sec):** Show one AI-assisted task, Studio/tool interaction, and the resulting event/session record and summary.
4. **Fresh-session continuation (60–75 sec):** Ask a follow-up task in a new session. Show the small retrieved context pack and its provenance, then complete/playtest the task.
5. **Evidence (30–40 sec):** Show baseline vs DevMemory tokens/exploration calls, task quality checklist, and amortized total including setup.
6. **Close (15–20 sec):** General memory engine; Roblox is the first adapter/demo. Mention the next engine adapters as future work.

## 16. Questions to resolve before implementation

- What exact Challenge 2 examples, constraints, and judging criteria are on the platform?
- Which AI coding tools and accounts are available during the event, and what telemetry do they expose?
- Can the selected assistant invoke MCP or hooks in the current environment?
- Does the test Roblox project have scripts/assets in a filesystem-exportable form, or must Studio MCP inspect them live?
- Which data should be committed to Git versus ignored by default?
- Is the best first user interface a CLI, MCP server, editor integration, or small local desktop view? For the hackathon, choose the quickest one the evaluator can understand and use.

## 17. Sources and further reading

### Meeting material in this project

- [Hackathon-Notes-ActionItems-Checklist.md](Hackathon-Notes-ActionItems-Checklist.md) — challenge definitions, submission requirements, and schedule. Challenge 2 is “Deliver AI With Less Compute”; the orientation calls for efficient high-quality results and suggests simplifying processes and checking results efficiently.
- [Future-AI-Builders-Hackathon-HUMAIN-Orientation-Transcript.md](Future-AI-Builders-Hackathon-HUMAIN-Orientation-Transcript.md) — full orientation transcript, especially 44:46 and 01:02:13 for Challenge 2, 52:40 for implementation guidance, and 56:13 for narrowing broad challenges.
- [Hackathon-Speaker-Breakdown-and-Questions.md](Hackathon-Speaker-Breakdown-and-Questions.md) — participant questions and submission/demo context.

### Product/platform documentation

- [Obsidian: How Obsidian stores data](https://obsidian.md/help/data-storage) — vault as local folder; Markdown plain-text storage.
- [Obsidian Help](https://help.obsidian.md/) — notes, linking, vaults, plugins, and workflows.
- [Claude Code: Hooks reference](https://code.claude.com/docs/en/hooks) — documented lifecycle/tool hooks and event handling.
- [Claude Code: CLI usage](https://docs.anthropic.com/en/docs/claude-code/cli-usage) — CLI, output formats, and programmatic use.
- [Claude Code: Data usage](https://docs.anthropic.com/en/docs/claude-code/data-usage) — data handling context; re-check current retention and privacy terms before shipping integrations.
- [Codex CLI: Command line reference](https://learn.chatgpt.com/docs/cli/reference) — JSONL output/events and session commands.
- [Codex CLI: Non-interactive mode](https://learn.chatgpt.com/docs/non-interactive-mode) — JSONL output and ephemeral mode behavior.
- [Roblox Creator Hub: Studio MCP](https://create.roblox.com/docs/studio/mcp) — connect AI coding tools to Roblox Studio and interact with project structure and Studio tools.
- [Roblox Creator Hub: AI-accelerated workflows](https://create.roblox.com/docs/ai/accelerated-workflows) — current Roblox Studio AI and development workflow context.
- [Roblox Creator Hub: Coding harness](https://create.roblox.com/docs/ai/coding-harness) — Script Sync, MCP, and Git-oriented AI development setup.
- [Roblox Studio Agent Plugin repository](https://github.com/Roblox/roblox-studio-agent-plugin) — official plugin/integration implementation notes; review data-sharing details before enabling features.

### Specific Roblox and game-development workflow examples

- [“Build your own AI dev team for Roblox” by SyphoDev](https://payhip.com/b/S9gWL) — a public creator-described workflow that explicitly combines an Obsidian brain, Roblox Studio MCP, reusable skills, hooks, asset library work, and playtests. Treat as a workflow example, not independent validation of performance claims.
- [“AI Game Studio Automation” case study](https://robiriu.github.io/projects/ai-game-studio-mimio/) — describes using Roblox Studio MCP with an Obsidian vault that mirrors agent runs, approvals, notes, and status maps.
- [Creator video listing: 40GB+ Obsidian vault for Roblox developers](https://darkugc.com/video/tt-7701541453754862861) — secondary listing of a creator video about a Roblox/Studio/scripting/game-design knowledge vault; the listing does not verify the vault’s size/content or its efficiency.
- [Unity Insight: A Production Code–Asset Index for LLM Coding Agents in Unity Projects (2026 preprint)](https://arxiv.org/abs/2609.27585) — typed links among scripts, scenes, prefabs, and assets; reports token reductions in a limited paired study. Treat as a promising technical precedent, not a universal result or an Obsidian benchmark.

### Community workflow examples (anecdotal, not benchmark evidence)

- [Community discussion: Obsidian as a persistent brain for Claude Code](https://www.reddit.com/r/ClaudeAI/comments/1rv5ox0/i_used_obsidian_as_a_persistent_brain_for_claude/) — project vault structure, index notes, commands, and selective retrieval pattern.
- [Community discussion: Obsidian with Claude Code](https://www.reddit.com/r/ClaudeAI/comments/1qr19df/claude_code_obsidian_how_i_use_it_short_guide/) — project-specific context and agent workflow examples.

**Research note:** Product and API capabilities change. Confirm the current official documentation and platform challenge page on the day implementation begins. Community workflows are useful for design inspiration, but their reported token savings are not treated as verified results; DevMemory must produce its own controlled measurements.
