{pkgs, pkgs-unstable, lib, user, hostName, ... }:
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../modules/nixos/desktop-common.nix
      ../../modules/nixos/aragorn-packages.nix
      ../../modules/nixos/battery_management.nix
      ../../modules/nixos/graphics.nix
      ../../modules/nixos/terminal_utils.nix
      ../../modules/nixos/codemeter.nix
      ../../modules/nixos/maxlang.nix
      # ../../modules/nixos/sddm.nix
      ../../modules/nixos/regreet.nix
      #../../modules/nixos/firefox.nix
      ../../modules/nixos/brave.nix
      ../../modules/nixos/hyprland.nix
      ../../modules/nixos/networking.nix
      ../../modules/nixos/wifi-subatomic.nix
      ../../modules/nixos/roku-cast.nix
      ../../modules/nixos/bluetooth.nix
      # ../../modules/nixos/minecraft_server.nix
    ];

  networking.hostName = hostName;

  # Distrust roots involved in the eMudhra intermediate CA compromise.
  security.pki.caCertificateBlacklist = [
    "Comodo AAA Services root"
    # emSign ECC Root CA - G3 is absent from NSS 3.131.1.
    # Listing an absent root makes buildcatrust fail.
  ];

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      # Deduplicate identical store files.
      auto-optimise-store = true;
    };

    gc = {
      automatic = true;
      dates = "weekly";
      # Retain a month of system generations for rollback.
      options = "--delete-older-than 30d";
    };

    # User-profile retention is handled by modules/home_manager/gc.nix.
    optimise.automatic = true;
  };

    # Bootloader.
  boot.loader.systemd-boot.enable = true;  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  environment.sessionVariables = {
    TERMINAL = "ghostty";
    EDITOR = "zeditor";
    # libnewt applications such as nmtui use the terminal's Gruvbox ANSI
    # palette, with green for focused controls and headings.
    NEWT_COLORS = lib.concatStringsSep ";" [
      "root=lightgray,black"
      "border=green,black"
      "window=lightgray,black"
      "shadow=black,black"
      "title=green,black"
      "button=lightgray,black"
      "actbutton=black,green"
      "checkbox=lightgray,black"
      "actcheckbox=green,black"
      "entry=lightgray,black"
      "label=lightgray,black"
      "listbox=lightgray,black"
      "actlistbox=black,green"
      "textbox=lightgray,black"
      "acttextbox=black,green"
      "helpline=black,lightgray"
      "roottext=green,black"
      "emptyscale=gray,black"
      "fullscale=green,black"
      "disentry=gray,black"
      "compactbutton=lightgray,black"
      "sellistbox=lightgray,black"
      "actsellistbox=black,green"
    ];
  };

  services.pipewire.wireplumber = {
    extraConfig."90-silent-notifications"."stream.rules" = [
      {
        matches = [
          { "media.role" = "~(?i)^(notification|event)$"; }
        ];
        actions.update-props = {
          "state.restore-props" = false;
          "state.default-volume" = 0.0;
        };
      }
    ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

}
