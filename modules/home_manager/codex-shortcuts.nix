# Translate Codex model/effort shortcuts into native presets inside its own PTY.
{ pkgs, ... }:
let
  launcher = pkgs.writeShellScript "codex-shortcuts" ''
    exec ${pkgs.python3}/bin/python3 ${../../artifacts/scripts/codex-shortcuts.py} "$(command -v codex)" "$@"
  '';
in {
  programs.zsh.initContent = ''
    codex() { ${launcher} "$@"; }
  '';
}
