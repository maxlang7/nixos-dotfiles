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
| **AI** | [T3Code](https://zed.dev/) | High-performance and no-frills editor. |
| **Editor** | [Zed](https://t3.codes/) | Best designed AI editor I've ever used for both chat and work |
| **File Manager** | Yazi | Terminal-based file management — also wired in as the system file picker. |
| **Status Bar** | Waybar | Clean and informative, with custom modules (Codex usage meter, run-streak tracker, nixos rebuilder). |
| **Launcher** | Rofi | App launching plus custom menus: bluetooth, audio mixer, timers, lofi beats. |
| **Music** | [Feishin](https://github.com/jeffvli/feishin) + [Navidrome](https://www.navidrome.org/) | Feishin as the player, streaming from a self-hosted Navidrome server with Last.fm scrobbling. |
| **Messaging** | [Chord](https://github.com/maxlang7/chord/) | Custom build way to have all my communication apps in one place (with a declarative gruvbox theme), plus an iMessage bridge to my phone through bluetooth. |
| **Secrets** | [sops-nix](https://github.com/Mic92/sops-nix) | Encrypted secrets committed right in the repo (age-encrypted). |
| **VPN** | WireGuard | Tunnel with DNS pushed via resolvectl. |
| **Sync** | Syncthing | Keeps documents and books in sync across machines. |

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
