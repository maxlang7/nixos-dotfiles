# ❄️ nixos-config

My personal NixOS setup, managed via **Flakes**. It's a modular configuration designed to keep my machines reproducible and consistent across different hardware.

---

## 💻 The Machines

I maintain configurations for two main hosts, each with a specific purpose:

- **`Aragorn`**: My daily driver, a **Framework Laptop**. It's optimized for portability with advanced battery management and a full Hyprland desktop environment.
- **`Gandalf`**: My home server. It handles persistent services, including a Minecraft server and other background utilities.

---

## 🛠️ The Tech Stack

I've curated a set of tools that prioritize speed, efficiency, and aesthetics:

| Component | Choice | Why? |
| :--- | :--- | :--- |
| **Window Manager** | [Hyprland](https://hyprland.org/) | Modern, dynamic tiling with smooth Wayland performance. |
| **Editor** | [Zed](https://zed.dev/) | High-performance, multiplayer-ready code editor. |
| **Shell** | Zsh | Powered by custom plugins for a better CLI experience. |
| **File Manager** | Yazi | Terminal-based file management with a focus on speed. |
| **Status Bar** | Waybar | Clean, informative, and highly configurable. |
| **Music** | 🏗️ *In Progress* | Currently refactoring my audio setup (stay tuned). |

---

## 🚀 Quick Start

To apply this configuration (assuming Nix is installed with flakes enabled):

```bash
# Clone the repository
git clone https://github.com/maxlang/nixos-config

# Navigate into the config
cd nixos-config

# Rebuild the system (replace HOSTNAME with Aragorn or Gandalf)
sudo nixos-rebuild switch --flake .#HOSTNAME
```

---

## 📖 Useful Nix Resources

If you're new to NixOS or just looking for documentation:

- [NixOS Search](https://search.nixos.org/) - The best way to find packages and options.
- [NixOS Wiki](https://nixos.wiki/) - Community-driven documentation.
- [Zero to Nix](https://zero-to-nix.com/) - A great starting point for understanding Flakes.
- [MyNixOS](https://mynixos.com/) - Visual browser for Nix modules and configurations.

---

*“Even a simple config can be a powerful thing.”* 🛠️