# ════════════════════════════════════════════════════════════════════════════
#  Claude Code — declarative config
# ────────────────────────────────────────────────────────────────────────────
#  What this manages declaratively:
#    • claude-code package
#    • ~/.claude/CLAUDE.md            (from artifacts/claude/CLAUDE.md)
#
#  What is intentionally NOT managed here (mutable runtime state — leave alone):
#    • ~/.claude/{sessions,history.jsonl,telemetry,...}
#    • ~/.claude.json (mcpServers, project history, etc.)
#
#  MCP servers (retired 2026-07-23): the old per-service setup (gmail-home /
#  gmail-cmu built from source here, plus imperative google-calendar /
#  google-sheets / google-forms servers) was replaced by two workspace-mcp
#  instances — google-workspace-home and google-workspace-cmu — each a pip
#  venv under ~/.config/google-workspace-{home,cmu}/ (shell.nix + run.sh,
#  same imperative pattern as the old Sheets/Forms servers), registered via
#  `claude mcp add -s user`. Not declarative — see MCP-SETUP.md §1 for the
#  redo-after-wipe steps. The shared OAuth client for all Google MCP servers
#  still lives at ~/.config/gmail-mcp/gcp-oauth.keys.json (GCP project
#  gmail-mcp-502104, all relevant Workspace APIs now enabled on it).
# ════════════════════════════════════════════════════════════════════════════
{ config, pkgs, pkgs-unstable, lib, user, ... }:

{
  # 1. Claude Code itself (unstable tracks releases closely).
  home.packages = [ pkgs-unstable.claude-code ];

  # 2. Global instructions — the "Admin desk" / secretary playbook.
  #    Move the live file into the repo first (see wiring notes), then this
  #    symlinks it back read-only:
  home.file.".claude/CLAUDE.md".source = ../../artifacts/claude/CLAUDE.md;
}
