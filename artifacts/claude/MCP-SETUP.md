# Max's Integrations — MCP & API Setup Reference

**Audience:** a future version of Claude (or Max) with zero prior context. This
documents every external integration wired into Claude Code on this machine
(NixOS, host `Aragorn`, Framework 13, user `maxlang`): what it is, how we set it
up together, what Max has to do by hand, and how to use it day to day.

> **Scope note.** Claude Code (the CLI, installed via `pkgs-unstable.claude-code`
> in `modules/home_manager/claude.nix`) talks to *local* MCP servers listed in
> `~/.claude.json` under `mcpServers`, plus *remote* connectors attached through
> the claude.ai account. Google Drive is the only remote connector; everything
> else is a local process on this laptop.

---

## 0. The big picture

| Integration | Kind | Transport | Config lives in | Auth model | Managed by Nix? |
|---|---|---|---|---|---|
| `google-workspace-home` | Gmail + Calendar + Drive + Docs + Sheets + Slides + Forms + Tasks (max@langhorst.com) | stdio (python venv) | `~/.claude.json` + `~/.config/google-workspace-home/` | Google OAuth (per-instance token dir) | no (imperative) |
| `google-workspace-cmu` | same eight services (mlanghor@andrew.cmu.edu) | stdio (python venv) | `~/.claude.json` + `~/.config/google-workspace-cmu/` | Google OAuth (same client, separate creds dir) | no (imperative) |
| `beeper` | All messaging (Beeper Desktop) | HTTP (localhost:23373) | `~/.claude.json` only | none — trusts the local desktop app | no |
| `claude_ai_Google_Drive` | Google Drive | remote connector | claude.ai account (not on disk) | Google OAuth via Anthropic | n/a |
| `canvas` | Canvas LMS (CMU) | stdio (python venv) | `~/.claude.json` + `~/.config/canvas-mcp/` | personal access token (`.env`, sops fallback) | no (imperative) |

**Two config planes.** Runtime state (OAuth tokens, project history) lives under
`~/.config/*` and `~/.claude.json` and is deliberately *mutable / not in Nix*.
The reproducible pieces (the Claude Code package, `~/.claude/CLAUDE.md`, and
every secret) are declarative in this repo. See
`modules/home_manager/claude.nix` and `modules/nixos/sops.nix`.

> **History.** Until 2026-07-23 the Gmail server was *built from source* by
> `claude.nix` and its `~/.claude.json` entries were managed declaratively. That
> is gone — every MCP server is now an imperative `~/.config/` venv, and Nix
> manages only the Claude Code package, `CLAUDE.md`, and secrets.

**Golden rules that survive any reset:**
- OAuth **tokens** get rewritten on every refresh — never put them in Nix, never
  commit them. Only OAuth *client secrets* and API tokens go in sops.
- Every MCP server lives in its own `~/.config/<name>/` dir with a `shell.nix`
  owning the interpreter plus a pip `.venv` — per Max's global convention in
  `~/.claude/CLAUDE.md`. Register with `claude mcp add -s user <name> <run.sh>`;
  **`-s user` is not optional**, plain `claude mcp add` scopes the entry to the
  current project dir.
- **Never auto-send email / share docs.** Draft, show Max, wait for explicit
  "send". This is a standing operating rule.

---

## 1. Google Workspace — `google-workspace-home` and `google-workspace-cmu`

**Server:** [workspace-mcp](https://github.com/taylorwilsdon/google_workspace_mcp)
(PyPI `workspace-mcp`), python, stdio. **One full-service instance per Google
account**, each covering all eight services: gmail, calendar, drive, docs,
sheets, slides, forms, tasks.

| Instance | Account | Used for |
|---|---|---|
| `google-workspace-home` | **max@langhorst.com** | SAT tutoring / StudyCore, family, finances |
| `google-workspace-cmu` | **mlanghor@andrew.cmu.edu** | courses, research, IGB lab |

Tool names are namespaced per instance:
`mcp__google-workspace-home__search_gmail_messages`,
`mcp__google-workspace-cmu__get_events`, etc. Always pass the matching account
as `user_google_email` — the servers run `--single-user`, so the wrong address
just errors.

### Wiring
```
~/.config/google-workspace-{home,cmu}/
  shell.nix        # python312 venv
  .venv/           # bin/workspace-mcp
  .python-gcroot   # pins the interpreter against store GC
  run.sh           # sets OAuth env, execs workspace-mcp --single-user --transport stdio
  credentials/     # this instance's cached OAuth token — mode 700, never in git
```

- **One shared OAuth client** for both instances (and formerly the retired
  servers): `~/.config/gmail-mcp/gcp-oauth.keys.json`, a Desktop-app credential
  in GCP project `gmail-mcp-502104`. All Workspace APIs are enabled on that one
  project. Each `run.sh` points `GOOGLE_CLIENT_SECRET_PATH` at this same file and
  gives `GOOGLE_MCP_CREDENTIALS_DIR` its own per-instance dir, so the two
  accounts never collide.
- **`--tools gmail calendar drive docs sheets slides forms tasks`** — full
  read/write. Other CLI knobs if scoping is ever wanted: `--tool-tier`,
  `--read-only`, `--permissions SERVICE:LEVEL` (gmail levels
  readonly/organize/drafts/send/full, cumulative).
- **platformdirs gotcha.** `platformdirs` is a transitive fastmcp dep that
  workspace-mcp's metadata misses, and `pip install workspace-mcp platformdirs`
  as ONE command silently skips it — the server then dies at import with
  `ModuleNotFoundError: platformdirs`. **Install it as a separate pip step.**
  The cmu `shell.nix` does this correctly; home's still carries the old one-liner
  (its venv is already correct, so it only bites on a rebuild).

### Max's manual steps (redo after wipe)
1. Rebuild the venvs: `nix-shell ~/.config/google-workspace-home/shell.nix --run setup`
   (and the cmu one). Watch for the platformdirs trap above.
2. Register both, **user scope**:
   ```
   claude mcp add -s user google-workspace-home ~/.config/google-workspace-home/run.sh
   claude mcp add -s user google-workspace-cmu  ~/.config/google-workspace-cmu/run.sh
   ```
3. Restart Claude Code, then make one tool call per instance. The first call
   triggers browser OAuth (`start_google_auth`) → consent **as the matching
   account** → token caches into that instance's `credentials/`. CMU's Workspace
   admin does not block this client; consent goes through normally.

### How to use
Gmail search takes normal Gmail syntax:
`in:inbox category:primary is:unread newer_than:14d`, `from:`, `to:me`.

- Triage both inboxes: `search_gmail_messages` on each instance, then
  `get_gmail_messages_content_batch` for bodies.
- Calendar: `get_events`, `manage_event` (create/update/delete), `query_freebusy`.
- Sheets: `read_sheet_values`, `modify_sheet_values` — the lab notebook and the
  per-student SAT trackers live here.
- Drive/Docs: `search_drive_files`, `get_drive_file_content`, `get_doc_as_markdown`.

> **Standing rule: never auto-send email or share docs.** Draft it
> (`draft_gmail_message`), show Max, wait for an explicit "send". `send_gmail_message`
> and the Drive permission tools are off-limits without that. Also note
> `draft_gmail_message` **cannot attach local files** — paste content inline.

### Decommissioned 2026-07-23
Replaced by the above when Max consolidated every Google API onto one GCP
project: `gmail-home`, `gmail-cmu` (both gongrzhe/Gmail-MCP-Server, node, built
from source by `claude.nix` — that build and its declarative `~/.claude.json`
entries are **gone**), `google-calendar` (cocal), `google-sheets`, and a
forms-scoped workspace-mcp. `gmail-cmu` was already dead (`invalid_grant`) —
the project consolidation had invalidated its refresh token. The old config dirs
were archived, not deleted:
`~/.config/{google-calendar-mcp,google-sheets-mcp,google-forms-mcp}.retired-20260723-014810`.

---

## 2. Beeper — `beeper` (all messaging)

**Server:** the **Beeper Desktop** app exposes a local MCP over HTTP. This is not
a separately-installed server; the desktop app *is* the server.

### Wiring
- `~/.claude.json` entry: `type: http`, `url: http://127.0.0.1:23373/v0/mcp`.
- **Requirement:** the Beeper Desktop app must be **running and logged in** for
  these tools to work. No token on disk — it trusts localhost.

### How to use
Tools `mcp__beeper__*`: `search_messages`, `search_chats`, `list_messages`,
`get_chat`, `send_message`, `search`, `set_chat_reminder`, `clear_chat_reminder`,
`archive_chat`, `get_accounts`, `focus_app`, `search_docs`.
- Covers *every* network Max messages on (iMessage/SMS via BlueBubbles bridge,
  WhatsApp, Signal, etc. — whatever Beeper aggregates). BlueBubbles server
  password is a sops secret `bluebubbles-password` (see `modules/nixos/`).
- `send_message` is outward-facing → **confirm before sending** (same rule as email).

---

## 3. Google Drive — `claude_ai_Google_Drive` (remote connector)

**Not a local MCP.** This is a connector attached through the **claude.ai
account**, so there's nothing in `~/.claude.json` or `~/.config` for it. Auth is
Google OAuth brokered by Anthropic. It only sees files shared/indexed to it.

### How to use
Tools `mcp__claude_ai_Google_Drive__*`: `search_files`, `read_file_content`,
`download_file_content`, `get_file_metadata`, `list_recent_files`,
`get_file_permissions`, `create_file`, `copy_file`.
- Use for cloud Google Docs/Sheets. For **local** files just read the filesystem
  directly — `~/Documents/` (IGB Lab, StudyCore Students, design docs) is already
  reachable with the normal Read tool; no MCP needed.
- `create_file` / anything shareable → outward-facing, confirm first.

---

## 4. Canvas (CMU LMS) — `canvas` MCP + REST API

CMU Canvas is `https://canvas.cmu.edu`, a standard Instructure LMS. Two ways in,
both using the same **personal access token**: the `canvas` MCP server (added
2026-08-20) for anything conversational, and raw REST for one-offs the server
doesn't cover.

**Server:** [vishalsachdev/canvas-mcp](https://github.com/vishalsachdev/canvas-mcp),
python, stdio. Read-only in practice for Max's student account: assignments and
due dates, grades, submission status, peer reviews, syllabus, announcements,
discussions.

### MCP wiring (`canvas`)
Same shape as the python Google servers: a `~/.config/<name>-mcp/` dir with a
`shell.nix` owning the interpreter and a pip `.venv` for the server.

```
~/.config/canvas-mcp/
  shell.nix        # python312 + `setup` fn: makes .venv, pip install -e ./src
  src/             # git clone of vishalsachdev/canvas-mcp (v1.10.0), editable
  .venv/           # pip env; bin/canvas-mcp-server
  .python-gcroot   # symlink pinning the interpreter against nix store GC
  run.sh           # stdio wrapper — the command in ~/.claude.json
  .env             # CANVAS_API_TOKEN + CANVAS_API_URL, mode 600, NOT in git
```

- **Python 3.12, not the system 3.14.** Upstream tests to 3.13 and several deps
  (pydantic-core, cryptography, rpds-py) had no 3.14 wheels at install time.
- **Registered with:** `claude mcp add canvas -s user -- ~/.config/canvas-mcp/run.sh`
  → a `stdio` entry in `~/.claude.json`. Claude Code only spawns MCP servers at
  startup, so **restart the CLI** after adding or changing it.
- **Token resolution in `run.sh`**, in order: `~/.config/canvas-mcp/.env`, then
  `/run/secrets/canvas-token`. **`.env` does not currently exist** — sops is the
  single source of truth, and the `.env` branch is only an escape hatch for
  testing a new token before committing it. Neither path echoes the value.
- **Rebuild after `git pull` in `src/`:**
  `nix-shell ~/.config/canvas-mcp/shell.nix --run setup`
- **Health check:** `~/.config/canvas-mcp/run.sh --test` →
  `✓ API connection successful! Authenticated as: Max Langhorst`

> **Token rotated 2026-08-20.** The previous token expired 2026-07-18 (it had
> been created *with* an expiry — don't do that, see below). The replacement was
> generated, staged in `.env` from the clipboard via `wl-paste` so it never
> passed through a chat transcript, verified, then re-encrypted into sops and
> re-provisioned by a rebuild. `.env` was deleted afterward; sops and
> `/run/secrets/canvas-token` now hold the live value. **The old token still
> needs deleting in Canvas → Approved Integrations.**

### Wiring (REST / the secret)
- Secret: `canvas-token` in `artifacts/sops/secrets/secrets.yaml`, declared in
  `modules/nixos/sops.nix`:
  ```nix
  sops.secrets."canvas-token".owner = config.users.users.${user}.name;
  ```
  Decrypted at activation to `/run/secrets/canvas-token` (owner maxlang).
- Read with `cat /run/secrets/canvas-token`. **Never print the value.**
- Token shape: `<digits>~<64 alnum>` (~69 chars).

### Max's manual steps (redo after wipe / token rotation)
1. Canvas → **Account → Settings → Approved Integrations → + New Access Token**.
   Purpose "Claude assistant". **Leave "Expires" blank** — a past/near expiry
   makes Canvas reject it as `Expired access token` with a bogus
   `expired_at: 0000-…` (this happened on our first attempt; a fresh no-expiry
   token fixed it). Copy the token (shown once).
2. Put it in sops **without it passing through chat**:
   ```
   cd /etc/nixos/artifacts/sops && \
   SOPS_AGE_KEY_FILE=age/keys.txt SOPS_EDITOR='zeditor --wait' \
   nix-shell -p age sops --run 'sops secrets/secrets.yaml'
   ```
   Edit the `canvas-token:` line, **close the tab**, sops re-encrypts.
   - **sops+zeditor gotcha:** plain `$EDITOR=zeditor` returns immediately, so
     sops prints "File has not changed, exiting" and saves nothing. The
     `--wait` flag (and closing the tab) is what makes it work.
3. `sudo nixos-rebuild switch --flake /etc/nixos#Aragorn` to re-provision
   `/run/secrets/canvas-token`.
4. Verify keys landed (names only, no values):
   ```
   cd /etc/nixos/artifacts/sops && SOPS_AGE_KEY_FILE=age/keys.txt \
   nix-shell -p age sops --run 'sops -d secrets/secrets.yaml' 2>/dev/null \
   | grep -oE '^[a-zA-Z_.-]+:'
   ```
5. Optional staging step: to test a new token *before* re-encrypting it, write
   it to `.env` from the clipboard so it never enters a transcript, then delete
   `.env` once sops has it (this is what 2026-08-20's rotation did):
   ```
   umask 077; printf 'CANVAS_API_TOKEN=%s\nCANVAS_API_URL=https://canvas.cmu.edu/api/v1\n' \
     "$(wl-paste)" > ~/.config/canvas-mcp/.env
   ```
   Then `~/.config/canvas-mcp/run.sh --test` and restart Claude Code.
6. **Revoke the old token** in Canvas → Account → Settings → Approved
   Integrations → trash icon on the stale row. An expired token can't
   authenticate, but leaving dead grants listed makes the real one harder to
   spot later.

### How to use
```bash
TOK=$(cat /run/secrets/canvas-token)
curl -s -H "Authorization: Bearer $TOK" https://canvas.cmu.edu/api/v1/<endpoint>
```
Handy endpoints:
- `/users/self/courses?per_page=100&state[]=available&state[]=completed` — course list
- `/courses/{id}/enrollments?user_id=self` → `grades.current_score/current_grade` (overall)
- `/courses/{id}/students/submissions?student_ids[]=self&per_page=100` — per-assignment scores
- `/courses/{id}/assignments?per_page=100` — assignment names / points_possible

Known IDs: **Linalg** "Matrices and Linear Transformations" (21241-A5) = `53809`.

Idea parked (not built): a small tool that syncs Canvas due dates →
`google-workspace-cmu` calendar. Max deferred it.

### Gradescope (open question, not wired)
No official/public API. CMU Gradescope is almost certainly behind CMU SSO
(Shibboleth) + Duo 2FA, which unofficial scrapers can't traverse. A **native**
Gradescope password (email+password login, bypassing SSO) *might* exist — note
there's already a `cmu-pass` sops secret. If Max wants Gradescope: test whether a
native login works at gradescope.com, and if so build a scraper the same shape as
the Canvas flow. Otherwise rely on Gradescope's email notifications (they land in
the CMU inbox, already triaged via `google-workspace-cmu`).

---

## 5. Related declarative pieces (where to look)

- `modules/home_manager/claude.nix` — Claude Code pkg + `~/.claude/CLAUDE.md`
  (symlinked from `artifacts/claude/CLAUDE.md`). It no longer builds any MCP
  server; the old Gmail `buildNpmPackage` and its `~/.claude.json` entry merge
  were removed on 2026-07-23.
- `modules/nixos/sops.nix` — every secret: `cmu-pass`, `canvas-token`,
  `bluebubbles-password`, wireguard keys, navidrome lastfm keys.
- `artifacts/sops/.sops.yaml` — age recipient (public key `age17p9…`). Private
  key at `artifacts/sops/age/keys.txt` (gitignored).
- `artifacts/claude/CLAUDE.md` — the "Admin desk" secretary playbook + operating
  rules (the canonical source; the `~/.claude/CLAUDE.md` is a read-only symlink).

## 6. Fast health check (all integrations)
- Workspace (home): `mcp__google-workspace-home__search_gmail_messages` with
  `newer_than:1d` returns results.
- Workspace (cmu): `mcp__google-workspace-cmu__list_calendars` lists calendars.
  A `ModuleNotFoundError: platformdirs` at startup → see the §1 gotcha.
- Beeper: `mcp__beeper__get_accounts` — **fails if Beeper Desktop isn't running.**
- Drive: `mcp__claude_ai_Google_Drive__list_recent_files`.
- Canvas: `~/.config/canvas-mcp/run.sh --test` prints `✓ API connection
  successful!`. For the REST path, the courses curl above returns a JSON list
  (not an `errors` object). An `Expired access token` error → regenerate the
  token and update **both** `.env` and sops (see §4).
