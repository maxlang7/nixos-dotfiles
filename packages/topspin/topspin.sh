# Launch Bruker TopSpin out of the Wine prefix topspin-wine-setup built.
#
# On Windows the entry point is topspin.cmd at the install root, not an .exe —
# that is what Bruker's own installer/etc/shortcuts.yaml points its shortcut at.

WINEPREFIX="${TOPSPIN_WINEPREFIX:-${XDG_DATA_HOME:-$HOME/.local/share}/topspin-wine}"
export WINEPREFIX
export WINEARCH=win64
export WINEDEBUG="${WINEDEBUG:--all}"
export WINEDLLOVERRIDES="mscoree,mshtml,winemenubuilder.exe="

# The login-time unit normally has this ready; build it here if it skipped or
# has not run yet. Stages are stamped, so this is a no-op once done.
if [ ! -d "$WINEPREFIX" ]; then
  echo "No Wine prefix yet — building it first (this takes a few minutes)." >&2
  topspin-wine-setup --prefix-only
fi

# Default install root is C:\Bruker\TopSpin<version>; sort -V picks the newest if
# several are installed side by side.
install_root="${TOPSPIN_HOME:-}"
if [ -z "$install_root" ]; then
  install_root=$(find "$WINEPREFIX/drive_c" -maxdepth 4 -type f -name topspin.cmd \
    -printf '%h\n' 2>/dev/null | sort -V | tail -n1 || true)
fi

if [ -z "$install_root" ] || [ ! -f "$install_root/topspin.cmd" ]; then
  echo "No TopSpin install found under $WINEPREFIX/drive_c." >&2
  echo "Run: topspin-wine-setup /path/to/TopSpin<version>.exe" >&2
  exit 1
fi

# CodeMeter holds the license. Bruker's installer bundles it; on Windows it runs as
# a service, which Wine does not start on its own.
if ! pgrep -f 'CodeMeter\.exe' >/dev/null 2>&1; then
  codemeter=$(find "$WINEPREFIX/drive_c" -maxdepth 6 -type f -name CodeMeter.exe 2>/dev/null | head -n1 || true)
  if [ -n "$codemeter" ]; then
    wine start /unix "$codemeter" || echo "warning: CodeMeter did not start" >&2
  fi
fi

cd "$install_root"
exec wine cmd /c topspin.cmd "$@"
