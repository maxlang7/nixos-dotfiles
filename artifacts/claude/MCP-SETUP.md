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
| `gmail-home` | Gmail (max@langhorst.com) | stdio (node) | `~/.claude.json` + `~/.config/gmail-mcp/` | Google OAuth (per-account token file) | server **binary** yes; tokens no |
| `gmail-cmu` | Gmail (mlanghor@andrew.cmu.edu) | stdio (node) | same as above | Google OAuth (test-user on consent screen) | server **binary** yes; tokens no |
| `google-calendar` | Google Calendar | stdio (node) | `~/.config/google-calendar-mcp/` | Google OAuth | no (imperative) |
| `google-sheets` | Google Sheets | stdio (python venv) | `~/.config/google-sheets-mcp/` | Google OAuth | no (imperative) |
| `beeper` | All messaging (Beeper Desktop) | HTTP (localhost:23373) | `~/.claude.json` only | none — trusts the local desktop app | no |
| `claude_ai_Google_Drive` | Google Drive | remote connector | claude.ai account (not on disk) | Google OAuth via Anthropic | n/a |
| Canvas (CMU LMS) | not an MCP — REST API | curl/python ad-hoc | sops secret `canvas-token` | personal access token | secret yes, tool no |

**Two config planes.** Runtime state (OAuth tokens, project history) lives under
`~/.config/*` and `~/.claude.json` and is deliberately *mutable / not in Nix*.
The reproducible pieces (the Claude Code package, the Gmail server binary built
from source, `~/.claude/CLAUDE.md`, and every secret) are declarative in this
repo. See `modules/home_manager/claude.nix` and `modules/nixos/sops.nix`.

**Golden rules that survive any reset:**
- OAuth **tokens** get rewritten on every refresh — never put them in Nix, never
  commit them. Only OAuth *client secrets* and API tokens go in sops.
- Each Google MCP was set up in its own `~/.config/<name>-mcp/` dir with a
  `shell.nix` (nix-shell for node, or a pip `.venv` for python — per Max's global
  convention in `~/.claude/CLAUDE.md`).
- **Never auto-send email / share docs.** Draft, show Max, wait for explicit
  "send". This is a standing operating rule.

---

## 1. Gmail — `gmail-home` and `gmail-cmu`

**Server:** `@gongrzhe/server-gmail-autoauth-mcp` (a.k.a. GongRzhe/Gmail-MCP-Server),
Node. One MCP server *per account*; both share one OAuth client and one wrapper.

**Accounts:**
- `gmail-home` → **max@langhorst.com** (personal: SAT tutoring/StudyCore, family, finances)
- `gmail-cmu` → **mlanghor@andrew.cmu.edu** (CMU: chem research, housing, health insurance)

### How it's wired
- **Binary:** built from source, fully offline/reproducible, in
  `modules/home_manager/claude.nix` via `buildNpmPackage`. It pins commit
  `a890d19…` (repo has no tags; main HEAD == v1.1.11) and **patches upstream's
  broken `package-lock.json`** — the top-level `@modelcontextprotocol/sdk@0.4.0`
  entry is missing `resolved`/`integrity`, which makes `npm ci` hit the network
  (ENOTCACHED). A `runCommand` + `jq` step injects those two fields before the
  build. If you ever bump the rev, expect to replace `lib.fakeHash` /
  `npmDepsHash` via the standard Nix TOFU (build fails, prints real hash, paste
  it back).
- **`~/.claude.json` entries:** deep-merged in non-destructively by a
  `home.activation` jq script in `claude.nix` (`.mcpServers = (old * managed)`),
  so beeper/calendar/sheets entries are never clobbered.
- **One wrapper, many accounts:** the server reads `GMAIL_OAUTH_PATH` and
  `GMAIL_CREDENTIALS_PATH` from env. Each account's `mcpServers` entry points
  `GMAIL_CREDENTIALS_PATH` at its own token file:
  - `~/.config/gmail-mcp/credentials-home.json`
  - `~/.config/gmail-mcp/credentials-cmu.json`
  - shared client: `~/.config/gmail-mcp/gcp-oauth.keys.json`
- **OAuth client:** shared "desktop app" client, GCP project `gmail-mcp-502104`
  (owned by max@langhorst.com). Scopes: `gmail.modify` + `gmail.settings.basic`.
  The auth listener uses `localhost:3000`.

### What Max had to do by hand (and would redo after a wipe)
1. Create the GCP project + OAuth desktop client, download `gcp-oauth.keys.json`.
2. `sudo nixos-rebuild switch` to build the server + register the entries
   (passwordless sudo is **off** — Max runs switch himself, fingerprint prompt).
3. **First-time auth per account** (writes the token file):
   ```
   GMAIL_OAUTH_PATH=~/.config/gmail-mcp/gcp-oauth.keys.json \
   GMAIL_CREDENTIALS_PATH=~/.config/gmail-mcp/credentials-home.json \
     <gmailMcp>/bin/gmail-mcp auth
   ```
   Browser opens → log into that account → token written.
4. **CMU gotcha:** mlanghor@andrew.cmu.edu is a *managed org* account. Auth only
   succeeded after adding it as a **test user** on the OAuth consent screen
   (Google Auth Platform → Audience). The project-owner account (home) is exempt,
   which is why home "just worked". CMU's admin does permit third-party OAuth.

### How to use it
Tools are `mcp__gmail-home__*` and `mcp__gmail-cmu__*`:
`search_emails`, `read_email`, `draft_email`, `send_email`, `modify_email`,
`list_email_labels`, `create_filter`, `batch_modify_emails`, `download_attachment`, …
- Gmail search syntax works in `search_emails`:
  `in:inbox category:primary is:unread newer_than:14d`, `from:`, `to:me`, etc.
- **Triage request** ("what's on my docket") → scan **both** inboxes (Primary +
  unread), report actionable items + deadlines, separate home vs CMU, flag
  money/time-sensitive, skip marketing. Convert relative dates to absolute.
- **Drafting only** unless Max says "send".

Full historical detail is also in auto-memory `reference_gmail_mcp`.

---

## 2. Google Calendar — `google-calendar`

**Server:** `@cocal/google-calendar-mcp` (Node), pinned `^2.6.2`.
Installed imperatively into `~/.config/google-calendar-mcp/` (node_modules there).

### Wiring
- `~/.claude.json` entry: `type: stdio`, `command: node`, `args:
  [~/.config/google-calendar-mcp/node_modules/@cocal/google-calendar-mcp/build/index.js]`.
- Env:
  - `GOOGLE_OAUTH_CREDENTIALS = ~/.config/google-calendar-mcp/gcp-oauth.keys.json`
  - `GOOGLE_CALENDAR_MCP_TOKEN_PATH = <token file path>` (runtime token, chmod 600)
- `shell.nix` in that dir just provides full `nodejs` (system only has
  `nodejs-slim`, which lacks npm/npx). `tokens.json` = the OAuth token, mutable.

### Max's manual steps (redo after wipe)
1. `cd ~/.config/google-calendar-mcp && nix-shell` then `npm install @cocal/google-calendar-mcp`.
2. Provide `gcp-oauth.keys.json` (can reuse a Google OAuth desktop client with the
   Calendar scope enabled).
3. First run triggers the browser OAuth flow → writes `tokens.json`.

### How to use
Tools `mcp__google-calendar__*`: `list-events`, `search-events`, `create-event`,
`create-events` (batch), `update-event`, `delete-event`, `get-freebusy`,
`list-calendars`, `get-current-time`, `respond-to-event`.
- Use for putting **deadlines** on the calendar (from email triage / Canvas).
- `default calendar` hint file exists at `~/.config/defaultcalendarrc`.
- Timezone care: StudyCore invites go out in EDT even when a student is in
  another TZ (see memory `reference_studycore_student_timezones`).

---

## 3. Google Sheets — `google-sheets`

**Server:** `mcp-google-sheets` (Python), installed in a **pip venv** per Max's
convention. Dir: `~/.config/google-sheets-mcp/`.

### Wiring
- `~/.claude.json` entry: `command: ~/.config/google-sheets-mcp/run.sh` (a wrapper).
- `run.sh` sets `CREDENTIALS_PATH` + `TOKEN_PATH` and `exec`s
  `.venv/bin/mcp-google-sheets` (the venv shebang points at nix-store Python 3.12).
- `shell.nix` pins **python312** (deps don't all support 3.14 yet), creates
  `.venv`, `pip install mcp-google-sheets`.
- `credentials.json` = OAuth desktop client (`installed` block); `token.json` =
  runtime token (chmod 600).

### Max's manual steps (redo after wipe)
1. `cd ~/.config/google-sheets-mcp && nix-shell` → shellHook builds the `.venv`.
2. Drop the OAuth `credentials.json` in place (Sheets + Drive scope).
3. First run → browser OAuth → writes `token.json`.

### How to use
Tools `mcp__google-sheets__*`: `list_spreadsheets`, `search_spreadsheets`,
`get_sheet_data`, `get_multiple_sheet_data`, `find_in_spreadsheet`,
`update_cells`, `batch_update_cells`, `add_rows`, `add_columns`, `create_sheet`,
`create_spreadsheet`, `share_spreadsheet`, `add_chart`, …
- Two big uses: **lab notebook** (chem reactions, see `user_role` memory) and
  **per-student SAT trackers** (`~/Documents/StudyCore Students/`, project
  `project_sat_tutoring`).
- `share_spreadsheet` is outward-facing → **draft/confirm with Max first.**

---

## 4. Beeper — `beeper` (all messaging)

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

## 5. Google Drive — `claude_ai_Google_Drive` (remote connector)

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

## 6. Canvas (CMU LMS) — REST API via token in sops

**Not an MCP** (yet). CMU Canvas is `https://canvas.cmu.edu`, a standard
Instructure LMS with a full REST API. We authenticate with a **personal access
token** stored in sops.

### Wiring
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
`google-calendar`. Max deferred it; he just wanted to confirm access works.

### Gradescope (open question, not wired)
No official/public API. CMU Gradescope is almost certainly behind CMU SSO
(Shibboleth) + Duo 2FA, which unofficial scrapers can't traverse. A **native**
Gradescope password (email+password login, bypassing SSO) *might* exist — note
there's already a `cmu-pass` sops secret. If Max wants Gradescope: test whether a
native login works at gradescope.com, and if so build a scraper the same shape as
the Canvas flow. Otherwise rely on Gradescope's email notifications (they land in
`gmail-cmu`, already triaged).

---

## 7. Related declarative pieces (where to look)

- `modules/home_manager/claude.nix` — Claude Code pkg, `~/.claude/CLAUDE.md`
  (symlinked from `artifacts/claude/CLAUDE.md`), Gmail server build + entry merge.
- `modules/nixos/sops.nix` — every secret: `cmu-pass`, `canvas-token`,
  `bluebubbles-password`, wireguard keys, navidrome lastfm keys.
- `artifacts/sops/.sops.yaml` — age recipient (public key `age17p9…`). Private
  key at `artifacts/sops/age/keys.txt` (gitignored).
- `artifacts/claude/CLAUDE.md` — the "Admin desk" secretary playbook + operating
  rules (the canonical source; the `~/.claude/CLAUDE.md` is a read-only symlink).

## 8. Fast health check (all integrations)
- Gmail: `mcp__gmail-home__search_emails` with `newer_than:1d` returns results.
- Calendar: `mcp__google-calendar__list-calendars` lists calendars.
- Sheets: `mcp__google-sheets__list_spreadsheets` returns sheets.
- Beeper: `mcp__beeper__get_accounts` — **fails if Beeper Desktop isn't running.**
- Drive: `mcp__claude_ai_Google_Drive__list_recent_files`.
- Canvas: the courses curl above returns a JSON list (not an `errors` object).
  An `Expired access token` error → regenerate the token (see §6).
