{ pkgs, inputs, yazi, notificationConfig, notificationStyle }:
{
  yazi-picker-wrapper = pkgs.writeShellScriptBin "yazi-picker-wrapper" ''
    multiple="$1"
    directory="$2"
    save="$3"
    path="$4"
    out="$5"
    export YAZI_CONFIG_HOME="$HOME/.config/yazi"
    # Ghostty requires a reverse-DNS class and separate argv entries after -e.
    if [ "$directory" = "1" ]; then
      ${pkgs.ghostty}/bin/ghostty --class=com.yazi.picker --title=termfilechooser \
        -e ${yazi}/bin/yazi --chooser-file="$out" --cwd-file="$out" "$path"
    else
      ${pkgs.ghostty}/bin/ghostty --class=com.yazi.picker --title=termfilechooser \
        -e ${yazi}/bin/yazi --chooser-file="$out" "$path"
    fi
  '';
  control = pkgs.writeShellApplication {
    name = "notification-control";
    runtimeInputs = [ pkgs.swaynotificationcenter pkgs.jq pkgs.coreutils pkgs.systemd ];
    text = ''
      export NOTIFICATIONS_STYLE=${notificationStyle}
      export NOTIFICATIONS_BASE_CONFIG=${notificationConfig}
    '' + builtins.readFile ../artifacts/scripts/notification-control.sh;
  };
  t3-settings-sync = pkgs.writeShellScriptBin "t3-settings-sync" ''
      exec ${pkgs.python3}/bin/python3 ${../artifacts/scripts/t3-settings-sync.py} sync "$@"
    '';
  waybar-bluetooth = pkgs.writeShellScriptBin "waybar-bluetooth" ''
    exec ${pkgs.python3}/bin/python ${../artifacts/scripts/waybar-bluetooth.py} ${pkgs.systemd}/bin/busctl
  '';
  calendarTui = pkgs.callPackage ./calendar-tui { craneLib = inputs.crane.mkLib pkgs; };
  topspin = pkgs.callPackage ./topspin { };
  blueferry = pkgs.callPackage ./blueferry { };
  bridge = pkgs.callPackage ./blueferry-beeper { };
}
