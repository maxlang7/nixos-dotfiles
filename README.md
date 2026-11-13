# ❄️ nixos-config

My personal NixOS setup, managed via **Flakes**. It's a modular configuration designed to keep my machines reproducible and consistent across different hardware. For a deeper tour of how it's wired together, see [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

---

## 💻 The Machines

I maintain configurations for three hosts, each with a specific purpose:

- **`Aragorn`**: My daily driver, a **Framework Laptop 13**. Optimized for portability with battery management and a full, heaivly bespoke Hyprland desktop environment.
- **`Gandalf`**: My home server. It runs a Minecraft server and other background services.
- **`simple`**: A minimal fallback/testing host for trying things without the full stack.

---

## 🛠️ The Stack

I've curated a set of tools that prioritize speed, efficiency, and aesthetics (gruvbox everywhere):

| Component | Choice | Why? |
| :--- | :--- | :--- |
| **Window Manager** | [Hyprland](https://hyprland.org/) | Modern, dynamic tiling and easy customizability. The bedrock of my system. |
| **Terminal** | [Ghostty](https://ghostty.org/) | Fast, simple, configurable. |
| **Browser** | [Brave](https://brave.com/) | My daily browser. |
| **AI** | [T3Code](https://t3.codes/) | High-performance and no-frills editor. |
| **Editor** | [Zed](https://zed.dev/) | Best designed AI editor I've ever used for both chat and work |
| **File Manager** | [Yazi](https://yazi-rs.github.io/) | Terminal-based file management — also wired in as the system file picker. |
| **Status Bar** | [Waybar](https://github.com/Alexays/Waybar) | Clean and informative, with custom modules (Codex usage meter, run-streak tracker, nixos rebuilder). |
| **Launcher** | [Rofi](https://github.com/davatorium/rofi) | App launching plus custom menus: bluetooth, audio mixer, timers, lofi beats. |
| **Music** | [Feishin](https://github.com/jeffvli/feishin) + [Navidrome](https://www.navidrome.org/) | Feishin as the player, streaming from a self-hosted Navidrome server with Last.fm scrobbling. |
| **Messaging** | [Chord](https://github.com/maxlang7/chord/) | Custom build way to have all my communication apps in one place (with a declarative gruvbox theme), plus an iMessage bridge to my phone through bluetooth. |
| **Secrets** | [sops-nix](https://github.com/Mic92/sops-nix) | Encrypted secrets committed right in the repo (age-encrypted). |
| **VPN** | [WireGuard](https://www.wireguard.com/) | Tunnel with DNS pushed via resolvectl. |
| **Sync** | [Syncthing](https://syncthing.net/) | Keeps documents and books in sync across machines. |

---

## Desktop workflow

### Keyboard shortcuts

`Super` is the Windows key. These are a few of the shortcuts I use most:

| Shortcut | Action |
| :--- | :--- |
| `Super + Enter` | Open Ghostty |
| `Super + Space` | Open the Rofi app launcher |
| `Super + Y` | Open Yazi |
| `Super + B` | Open Brave |
| `Super + V` | Toggle clipboard history |
| `Super + M`, `D`, `C`, `K`, or `L` | Toggle the music, Chord, calendar, terminal, or T3 Code scratchpad |
| `Super + 1` through `0` | Switch workspaces |
| `Print` / `Alt + Print` | Copy / save a selected screenshot area |

### Clipboard

[Clipse](https://github.com/savedra1/clipse) listens for clipboard changes when Hyprland starts. `Super + V` opens its floating history popup, and pressing the shortcut again closes it. Select an earlier entry to put it back on the clipboard, then paste it in the destination app.

### Menus and file picker

Rofi handles app launching and custom menus for Bluetooth, audio, timers, and music. `Super + Ctrl + Alt + M` opens the music menu.

Application file dialogs use Yazi through `xdg-desktop-portal-termfilechooser`. The picker opens in a Ghostty window and uses the same Yazi configuration as the regular file manager.

### Waybar

The NixOS icon opens the rebuild popup on left click, opens the update action on right click, and shows the popup on middle click. Separate Codex meters track the CMU and personal profiles; clicking a meter refreshes it, and right-clicking opens Codex with that profile. The bar also displays Grok usage and my run streak.

---

## 📁 Layout

```
flake.nix              # inputs + nixosConfigurations (Aragorn, Gandalf, simple)
hosts/<host>/          # per-machine: configuration.nix, home.nix, hardware config
modules/nixos/         # system modules (maxlang.nix is the main aggregator)
modules/home_manager/  # home-manager modules (hyprland, waybar, yazi, zed, ...)
artifacts/             # plain config files & assets referenced by modules
images/                # wallpapers
docs/                  # architecture notes
```

The convention: anything that's just an app's own config format (hyprland.conf, rofi themes, waybar CSS, shell scripts…) lives in `artifacts/` and gets referenced from a module, rather than being generated in Nix.

---

## 🚀 Quick Start

To apply this configuration (assuming Nix is installed with flakes enabled):

```bash
# Clone the repository
git clone https://github.com/maxlang7/nixos-dotfiles /etc/nixos

# Rebuild the system (replace HOSTNAME with Aragorn, Gandalf, or simple)
sudo nixos-rebuild switch --flake /etc/nixos#HOSTNAME

# Or just validate without switching
nixos-rebuild dry-build --flake /etc/nixos#HOSTNAME
```

> **Note on secrets:** `sops-nix` expects an age private key at `artifacts/sops/age/keys.txt` (gitignored — bring your own). To build without secrets entirely, comment out the two `sops-nix` input lines in `flake.nix` and the `./sops.nix` import in `modules/nixos/maxlang.nix`.

*“Brevity is the soul of wit”*
