# Build the Wine prefix Bruker TopSpin runs in.
#
# Three stamped stages, so re-running this is cheap:
#   prefix   wineboot, Windows 10, Mono/Gecko/menubuilder disabled
#   deps     winetricks corefonts tahoma vcrun2022
#   install  run a Bruker TopSpin .exe inside the prefix
#
# Usage:
#   topspin-wine-setup                      prefix + deps, then look for an installer
#   topspin-wine-setup ~/Downloads/TopSpin4.4.1.exe
#   topspin-wine-setup --prefix-only        prefix + deps only (what the user unit runs)
#   topspin-wine-setup --redo deps          forget a stage's stamp and run it again

WINEPREFIX="${TOPSPIN_WINEPREFIX:-${XDG_DATA_HOME:-$HOME/.local/share}/topspin-wine}"
export WINEPREFIX
export WINEARCH=win64
export WINEDEBUG="${WINEDEBUG:--all}"
# Empty override = disabled. Mono and mshtml are only there to nag on first boot;
# TopSpin needs neither. winemenubuilder is disabled because it writes its own
# .desktop files into ~/.local/share/applications, where they would fight the one
# home-manager puts there.
export WINEDLLOVERRIDES="mscoree,mshtml,winemenubuilder.exe="

stamps="$WINEPREFIX/.topspin-setup"

usage() {
  cat <<'EOF'
topspin-wine-setup [--prefix-only] [--redo <stage>] [installer.exe]

Stages: prefix (wineboot + Windows 10), deps (winetricks), install (the .exe).
Each is stamped, so rerunning only does what is missing.
EOF
}

prefix_only=0
installer=""

while [ $# -gt 0 ]; do
  case "$1" in
    --prefix-only) prefix_only=1; shift ;;
    --redo) rm -f "${stamps:?}/${2:?--redo needs a stage name}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "unknown flag: $1" >&2; exit 2 ;;
    *) installer="$1"; shift ;;
  esac
done

done_already() { [ -e "$stamps/$1" ]; }
mark_done() { mkdir -p "$stamps"; : > "$stamps/$1"; }

# Wine wants a display for wineboot and for the silent installers winetricks
# runs. The login-time unit can fire before the compositor has exported one, so
# bail out quietly rather than failing — the launcher retries on demand.
if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
  echo "==> no display yet, leaving the prefix for the next run"
  exit 0
fi

if ! done_already prefix; then
  echo "==> creating Wine prefix at $WINEPREFIX"
  mkdir -p "$WINEPREFIX"
  wineboot -u
  wineserver -w
  winetricks -q win10
  wineserver -w
  mark_done prefix
fi

if ! done_already deps; then
  # vcrun2022 covers the MSVC runtimes CodeMeter and TopSpin's native DLLs link
  # against; the fonts keep the Java UI from falling back to bitmap ugliness.
  echo "==> installing Windows runtime dependencies"
  winetricks -q corefonts tahoma vcrun2022
  wineserver -w
  mark_done deps
fi

if [ "$prefix_only" = 1 ]; then
  echo "==> prefix ready (skipping installer)"
  exit 0
fi

if done_already install && [ -z "$installer" ]; then
  echo "==> TopSpin already installed in this prefix (topspin-wine-setup --redo install to rerun)"
  exit 0
fi

if [ -z "$installer" ]; then
  # Bruker names these things TopSpin<version>.exe / topspin-…-windows.exe.
  installer=$(find "$HOME/Downloads" -maxdepth 2 -type f -iname '*topspin*.exe' 2>/dev/null | sort -V | tail -n1 || true)
fi

if [ -z "$installer" ]; then
  cat >&2 <<'EOF'
No TopSpin installer given and none found in ~/Downloads.

Download the *Windows* TopSpin installer from your Bruker account
(https://www.bruker.com/protected/en/services/software-downloads/nmr/), then:

    topspin-wine-setup ~/Downloads/<installer>.exe

Note the Linux .sh installer will not work here — this prefix is Windows.
EOF
  exit 1
fi

echo "==> running $installer under Wine"
wine "$installer"
wineserver -w
mark_done install

echo "==> done. Launch with: topspin"
