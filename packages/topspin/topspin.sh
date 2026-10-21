# Launch Bruker TopSpin out of the Wine prefix topspin-wine-setup built.
#
# On Windows the entry point is topspin.cmd at the install root, not an .exe —
# that is what Bruker's own installer/etc/shortcuts.yaml points its shortcut at.

# ~/.wine-topspin-5 is the prefix the working TopSpin 5 install lives in.
WINEPREFIX="${TOPSPIN_WINEPREFIX:-$HOME/.wine-topspin-5}"
export WINEPREFIX
export WINEARCH=win64
export WINEDEBUG="${WINEDEBUG:--all}"
export WINEDLLOVERRIDES="winemenubuilder.exe="
# wineWow64Packages.waylandFull ships only the Wayland driver (no winex11), so
# WAYLAND_DISPLAY must stay as the session set it — clearing it leaves TopSpin
# running with no window at all.

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

# The license comes from the native CodeMeter service (modules/nixos/codemeter.nix),
# which the Windows client reaches on localhost:22350. Do not start the bundled
# Windows CodeMeter.exe: it would fight the native one for that port.

cd "$install_root"
exec wine cmd /c topspin.cmd "$@"
