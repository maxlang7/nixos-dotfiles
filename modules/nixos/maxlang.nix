{pkgs, pkgs-unstable, user, inputs, ...}:
let
  # Pin only OpenCode until nixpkgs-unstable catches up with this release.
  opencodeLatest = pkgs-unstable.stdenv.mkDerivation {
    pname = "opencode";
    version = "2.2.6";
    src = pkgs-unstable.fetchurl {
      url = "https://github.com/anomalyco/opencode/releases/download/v2.2.6/opencode-linux-x64.tar.gz";
      hash = "sha256-CLsh1jJs50DZHM5+voimU2kz9uHjA1O5GgawHyXaMGw=";
    };
    sourceRoot = ".";
    nativeBuildInputs = with pkgs-unstable; [ autoPatchelfHook makeWrapper ];
    buildInputs = with pkgs-unstable; [ stdenv.cc.cc.lib wayland ];
    dontStrip = true;
    installPhase = ''
      runHook preInstall
      install -Dm755 opencode $out/bin/opencode
      wrapProgram $out/bin/opencode \
        --set OPENCODE_DISABLE_AUTOUPDATE true \
        --suffix PATH : ${pkgs-unstable.lib.makeBinPath [ pkgs-unstable.ripgrep ]} \
        --prefix LD_LIBRARY_PATH : ${pkgs-unstable.lib.makeLibraryPath [ pkgs-unstable.wayland ]}
      runHook postInstall
    '';
    meta.mainProgram = "opencode";
  };
  xournalppGruvbox = pkgs.symlinkJoin {
    name = "xournalpp-gruvbox";
    paths = [ pkgs-unstable.xournalpp ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/xournalpp --set GTK_THEME Gruvbox-Dark
      wrapProgram $out/bin/xournalpp-wrapper --set GTK_THEME Gruvbox-Dark
    '';
  };
in
{
  imports =
    [
      ./user.nix
      ./desktop_environment_apps.nix
      #./website.nix
      #./hibernate.nix
      # ./spicetify.nix
      ./navidrome.nix
      ./imessage-bridge.nix
      ./wireguard.nix
      ./syncthing.nix
      ./autoupgrade.nix
      # ./ampache.nix
      ./sops.nix # secrets — comment to disable (see header in sops.nix)
    ];
  boot.loader.timeout = 0;

  programs.dconf.profiles.user.databases = [{
     settings = {
       "org/gnome/desktop/interface".color-scheme = "prefer-dark";
       "org/gnome/desktop/sound" = {
         event-sounds = false;
         input-feedback-sounds = false;
       };
     };
   }];

  nix.settings.download-buffer-size = 524288000;

  environment.variables.EDITOR = "zeditor";

  programs.steam.enable = true;
  programs.gpu-screen-recorder.enable = true;
  users.users.${user}.packages =
      (with pkgs; [
        kitty
        (pkgs.callPackage ../../packages/audio-select {})
        (pkgs.callPackage ../../packages/capture-select {})
        (pkgs.callPackage ../../packages/popup-launch {})
        audacity
        mpv
        inkscape
        gimp
        nemo-with-extensions
        #activitywatch
        #aw-watcher-window-wayland
        #awatcher
        wineWow64Packages.waylandFull
        winetricks
        evince #pdf
        fastfetch
        cbonsai
        dconf-editor # For Gnome Theming
        gruvbox-dark-gtk
        sway-audio-idle-inhibit
        libreoffice
        uair # timer utility
        upower
        easyeffects
        shtris
        sops
        yubikey-manager
        ghostty
        qdirstat
        opustags
        # obs-studio
        kdePackages.okular
        pymol
        python314
        typst
        foliate
        wl-clipboard
        video-trimmer
        nodejs-slim_latest
        btop
        clipse
        imv
        zip
        nix-search-tv
        at
        parted
        bitwarden-desktop
        zathura
        (pkgs.callPackage ../../packages/msga.nix {})
        qbittorrent
        google-chrome
        anki
        cloudflared
      ])


    ++

    (with pkgs-unstable; [
      obs-studio
      claude-code
      grok-build
      yt-dlp-light
      feishin
      yazi
      picard
      beeper
      codex
      vesktop
      discord
      slack
      # bluebubbles
      lunar-client
      obsidian
      remnote
      kiro-fhs
      ffmpeg
      imagemagick
      gh
      rclone
      nixd
      nil
      vscode
      # xournalppGruvbox
      opencodeLatest
      t3code
    ]);
}
