# ════════════════════════════════════════════════════════════════════════════
#  Claude Code — declarative config + Gmail MCP server
# ────────────────────────────────────────────────────────────────────────────
#  What this manages declaratively:
#    • claude-code package
#    • ~/.claude/CLAUDE.md            (from artifacts/claude/CLAUDE.md)
#    • the Gmail MCP server *binary*  (built from source with buildNpmPackage)
#    • the gmail-home / gmail-cmu entries in ~/.claude.json (merged, non-destructive)
#
#  What is intentionally NOT managed here (mutable runtime state — leave alone):
#    • ~/.claude/{sessions,history.jsonl,telemetry,...}
#    • the OAuth *tokens* (~/.config/gmail-mcp/credentials-*.json) — created once
#      by `gmail-mcp auth`; they get rewritten on every refresh.
#
#  Companion pieces that live elsewhere (see the block at the bottom):
#    • the immutable OAuth client secret (gcp-oauth.keys.json) → modules/nixos/sops.nix
# ════════════════════════════════════════════════════════════════════════════
{ config, pkgs, pkgs-unstable, lib, user, ... }:

let
  gmailDir = "${config.home.homeDirectory}/.config/gmail-mcp";

  # ── Gmail MCP server, built from source (fully reproducible) ───────────────
  # @gongrzhe/server-gmail-autoauth-mcp. Replace the two `lib.fakeHash`es on
  # first build: `sudo nixos-rebuild switch` will fail and print the real hash
  # to paste in (standard nix TOFU workflow). If `rev = "v${version}"` 404s,
  # the tag scheme differs — pin a commit hash from the repo instead.
  gmailMcp = pkgs.buildNpmPackage rec {
    pname = "gmail-autoauth-mcp";
    version = "1.1.11";

    src = pkgs.fetchFromGitHub {
      owner = "GongRzhe";
      repo = "Gmail-MCP-Server";
      rev = "v${version}";
      hash = lib.fakeHash;
    };

    npmDepsHash = lib.fakeHash;

    # repo's package.json builds TS -> dist (npm run build) and exposes
    # bin `gmail-mcp` -> dist/index.js, so $out/bin/gmail-mcp just works.
  };

  # helper: one Gmail account = one stdio server pointed at its own token file
  mkGmail = credFile: {
    type = "stdio";
    command = "${gmailMcp}/bin/gmail-mcp";
    args = [ ];
    env = {
      GMAIL_OAUTH_PATH = "${gmailDir}/gcp-oauth.keys.json";
      GMAIL_CREDENTIALS_PATH = "${gmailDir}/${credFile}";
    };
  };

  # Only the servers we own here. Merged *over* whatever is already in
  # ~/.claude.json, so beeper / google-sheets / google-calendar stay untouched.
  managedMcpServers = {
    gmail-home = mkGmail "credentials-home.json";
    gmail-cmu = mkGmail "credentials-cmu.json";
  };
in
{
  # 1. Claude Code itself (unstable tracks releases closely).
  home.packages = [ pkgs-unstable.claude-code ];

  # 2. Global instructions — the "Admin desk" / secretary playbook.
  #    Move the live file into the repo first (see wiring notes), then this
  #    symlinks it back read-only:
  home.file.".claude/CLAUDE.md".source = ../../artifacts/claude/CLAUDE.md;

  # 3. Register the Gmail MCP servers without clobbering ~/.claude.json's
  #    mutable state (project history, oauth, other servers). jq deep-merges.
  home.activation.claudeMcpServers =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      cfg="$HOME/.claude.json"
      run() { $DRY_RUN_CMD "$@"; }
      run ${pkgs.coreutils}/bin/mkdir -p "$HOME/.config/gmail-mcp"
      [ -f "$cfg" ] || run ${pkgs.coreutils}/bin/cp ${
        pkgs.writeText "claude-empty.json" "{}"
      } "$cfg"
      run ${pkgs.jq}/bin/jq \
        --argjson s ${lib.escapeShellArg (builtins.toJSON managedMcpServers)} \
        '.mcpServers = ((.mcpServers // {}) * $s)' \
        "$cfg" > "$cfg.hm-tmp" \
        && run ${pkgs.coreutils}/bin/mv "$cfg.hm-tmp" "$cfg"
    '';

  # ── One-time, after `nixos-rebuild switch` provisions the OAuth key: ───────
  #   cd ~/.config/gmail-mcp
  #   GMAIL_OAUTH_PATH=$PWD/gcp-oauth.keys.json \
  #   GMAIL_CREDENTIALS_PATH=$PWD/credentials-home.json ${"\${"}gmailMcp}/bin/gmail-mcp auth
  #   (repeat with credentials-cmu.json, log in as the CMU account)
}
