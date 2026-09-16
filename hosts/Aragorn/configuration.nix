{pkgs, pkgs-unstable, lib, user, hostName, ... }:
let
  wacomUsbPower = pkgs.writeShellApplication {
    name = "wacom-usb-power";
    text = ''
      set -euo pipefail

      case "''${1:-}" in
        enable) authorized=1 ;;
        disable) authorized=0 ;;
        *)
          echo "usage: wacom-usb-power enable|disable" >&2
          exit 2
          ;;
      esac

      found=false
      for device in /sys/bus/usb/devices/*; do
        [[ -r "$device/idVendor" && -r "$device/idProduct" ]] || continue
        [[ $(<"$device/idVendor") == 056a ]] || continue
        [[ $(<"$device/idProduct") == 03c7 ]] || continue
        printf '%s\n' "$authorized" >"$device/authorized"
        found=true
      done

      [[ $found == true ]] || {
        echo "Wacom Intuos USB device not found" >&2
        exit 1
      }
    '';
  };
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../modules/nixos/battery_management.nix
      ../../modules/nixos/graphics.nix
      ../../modules/nixos/terminal_utils.nix
      #../../modules/nixos/bwlang.nix
      ../../modules/nixos/maxlang.nix
      # ../../modules/nixos/sddm.nix
      ../../modules/nixos/regreet.nix
      #../../modules/nixos/firefox.nix
      ../../modules/nixos/brave.nix
      ../../modules/nixos/hyprland.nix
      ../../modules/nixos/networking.nix
      ../../modules/nixos/bluetooth.nix
      # ../../modules/nixos/minecraft_server.nix
    ];

  networking.hostName = hostName;

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      # Hardlink identical files in the store. The store had grown to ~132G;
      # this is the single biggest space win and costs nothing at runtime.
      auto-optimise-store = true;
    };

    gc = {
      automatic = true;
      dates = "weekly";
      # WAS `--delete-older-than 3d`, which was actively dangerous: it wiped
      # every system generation older than three days, so the "boot the
      # config from last week" rollback that saved us on 2026-08-12 was only
      # available by luck. 30d keeps a real rollback window; the store is on
      # a 916G disk that is 45% full, so the space is not worth the risk.
      options = "--delete-older-than 30d";
    };

    # `nix.gc` runs nix-collect-garbage as root, which only ever touches root
    # profiles — it does not know about ~/.local/state/nix/profiles. That is
    # why 452 home-manager generations dating back to March 2025 had piled up
    # and were pinning their whole closures against collection. See
    # modules/home_manager/gc.nix for the matching per-user timer.
    optimise.automatic = true;
  };

    # Bootloader.
  boot.loader.systemd-boot.enable = true;  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  environment.sessionVariables = {
    TERMINAL = "ghostty"; # Replace with your terminal
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

  # Framework firmware
  services.fwupd.enable = true;

  # Timezone is resolved automatically by services.automatic-timezoned below.
  # (There used to be a timezones.nix module referenced here; it no longer
  # exists — the geoclue-based service is the whole implementation now.)
  time.timeZone = lib.mkForce null; # allow TZ to be set by desktop user
  services.automatic-timezoned.enable = true;
  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };


  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji # renamed in 25.11
    font-awesome
    fira-code
    fira-code-symbols
    liberation_ttf
    proggyfonts
  ]
  ++ builtins.filter lib.attrsets.isDerivation (builtins.attrValues pkgs.nerd-fonts);


  # Enable CUPS to print documents.
  services.printing.enable = true;

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  # Enable sound with pulseaudio.
  services.pulseaudio.enable = false;

  security.rtkit.enable = true;
  services.pipewire = {
    wireplumber.enable = true;
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    jack.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput = {
    enable = true;
    touchpad.naturalScrolling = true;
  };

  # A newly connected Wacom starts deauthorized. Waybar is the only control
  # allowed to authorize this exact USB vendor/product pair.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="056a", ATTR{idProduct}=="03c7", ATTR{authorized}="0"
    ACTION=="add|change", SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_VENDOR_ID}=="056a", ENV{ID_MODEL_ID}=="03c7", ENV{ID_INPUT_TABLET}=="1", ENV{LIBINPUT_CALIBRATION_MATRIX}="0 -1 1 1 0 0"
  '';

  environment.systemPackages = [ wacomUsbPower ];
  security.sudo.extraRules = [
    {
      users = [ user ];
      commands = [
        {
          command = "/run/current-system/sw/bin/wacom-usb-power";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # Fingerprint Sensor
  services.fprintd.enable = true;

  # Setup portals (for interapplication workflows)
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Enable auto-detecting of usb drives
  services.udisks2.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

}
