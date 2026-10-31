# Team Task Board

Web app: Node.js (no npm dependencies), `node server.js`, static frontend in `public/`.

## Where things live
- `server.js` – http server (built-ins only). Port = `PORT` env (default 3000). Serves `public/`, API under `/api`.
- `public/index.html`, `public/app.js`, `public/style.css` – frontend (vanilla JS). Renders 3 columns, add-card form.
- `data/board.json` – storage (JSON array of cards; created on first write; git-ignored).

## Design decisions
- Columns (exact strings): `To Do`, `In Progress`, `Done`. Default for new cards: `To Do`.
- Card shape: `{ id: string (crypto.randomUUID), title: string, column: string }`.
- `GET /api/cards` → 200, array of cards.
- `POST /api/cards` body `{title, column?}` → 201 with created card. 400 `{error}` if title missing/blank or column not one of the three.
- Title is trimmed. Frontend uses textContent (no HTML injection).
- Styling (dark theme, CSS vars in `:root` of `style.css`): page bg `#0f1115`, column panel `#171a21` (14px radius, 1px border `#2a2f3b`), cards `#1f232d` with shadow, text `#e6e8ee`, muted `#9097a7`, violet accent `#8b7cf6` (submit button, active filter, focus rings, drag `.over` dashed outline, card hover border).
- Column header `h2` = name span + `span.count` badge (violet pill) showing number of cards visible in that column (respects the active filter); built in `render()`.
- Responsive: `@media (max-width: 800px)` → board becomes 1 column, form fields wrap full-width, larger delete tap target. Laptop = 3-column grid.

- `PATCH /api/cards/:id` body `{column}` → 200 with updated card. 400 `{error}` if column invalid/missing, 404 `{error}` if id unknown.
- `DELETE /api/cards/:id` → 204 no body. 404 `{error}` if id unknown.
- Frontend: cards are `draggable`; dropping on a column PATCHes it (card id passed via `dataTransfer` `text/plain`). Each card has a `×` button (`.delete`) that DELETEs. Column gets `.over` class (dashed blue outline `#0052cc`) during dragover. Card is flex row (title span + delete button).
- Card ordering within a column = array order; no reordering within column.

- Labels: card has `label` field: `Bug` | `Feature` | `Chore` | `null` (none; old cards without the field = none). `POST /api/cards` accepts optional `label` (400 `{error:'invalid label'}` if not one of those; ''/null = none). PATCH only changes `column`.
- Frontend: add-form has `#label` select. Pill `.pill.bug|feature|chore` (#e5484d / #3e63dd / #8b8d98, white text) under the title. Filter bar `#filters` (buttons `data-filter` ''=All/Bug/Feature/Chore, `.active` = violet accent `#8b7cf6` with dark text); client-side `filter` var in app.js, one label at a time.

- Due dates: card has `dueDate` field `YYYY-MM-DD` or `null` (old cards without it = none). `POST /api/cards` accepts optional `dueDate` (400 `{error:'invalid dueDate'}` if not a real calendar date in that format; ''/null = none). PATCH only changes `column`.
- Frontend: add-form has `#dueDate` date input. Card shows `.due` text ("Due YYYY-MM-DD"); `.card.overdue` (date < today, local) = 2px red border `#de350b`; `.card.due-today` = 2px amber border `#ff991f`. Comparison is string-based against local date in `render()`.

- Assignees: team = `Alice`, `Bob`, `Carol`, `Dan` (`ASSIGNEES` in server.js). Card has `assignee` field: one of those or `null` (old cards without it = none). `POST /api/cards` accepts optional `assignee` (400 `{error:'invalid assignee'}` if not a member; ''/null = none). PATCH only changes `column`.
- Frontend: add-form has `#assignee` select. Card shows `.avatar` (24px-ish violet `#8b7cf6` circle, dark text, initials of name, `title` = full name) between title and delete button. Assignee filter bar `#assignee-filters` (buttons `data-assignee` ''=Everyone/names, `.active` same style as `#filters`) below label filter; client-side `assigneeFilter` var in app.js. Label and assignee filters combine with AND; column count badges respect both.

- WIP limit: `In Progress` holds max 3 cards (`WIP_LIMIT` in server.js). POST into it, or PATCH a card into it from another column, beyond that → 409 `{error:'In Progress is full (max 3 cards)'}`. Frontend `toast()`/`failed()` in app.js shows a `.toast` (bottom-center, `#1f232d`, violet border, 3s) on any non-ok POST/PATCH. Label colors unchanged.

- Search: `#search` input (in `#search-bar`, above `#filters`) filters cards client-side by case-insensitive title substring (`search` var in app.js); ANDs with label + assignee filters; count badges respect it. `#clear-filters` button ("Clear filters") resets search, label and assignee filters to All/Everyone and re-renders. Styled with panel bg/border, violet focus ring; full-width on mobile.

## Not yet done
- Changing a card's label, due date or assignee after creation.
- Editing card titles, reordering within a column, no auth.

Keep this file up to date: after every change, record the design decisions (API shapes, field names, colors, rules) and where things live, so the next session can continue without re-reading everything.
