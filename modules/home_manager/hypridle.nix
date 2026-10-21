{ pkgs, ... }:
let
  # Give the display time to return before reloading Waybar's modules.
  idleControl = "/etc/nixos/artifacts/scripts/hypridle-toggle.sh";
  wakeDisplay = "${idleControl} wake";
in
{
  services.hypridle = {
      enable = true;
      settings = {
        general = [
          {
            # Launch hyprlock through Hyprland so it lives in the compositor's
            # session, not in hypridle.service's cgroup. Otherwise any stop or
            # restart of hypridle (caffeine, home-manager switch) SIGTERMs the
            # locker while the session is locked, leaving a dead lock screen.
            lock_cmd = "pidof hyprlock || hyprctl dispatch exec hyprlock";
            before_sleep_cmd = "loginctl lock-session";    # lock before suspend.
            after_sleep_cmd = wakeDisplay;
          }
        ];
          # set monitor backlight to minimum when timeout has passed, restore monitor backlight when activity detected.
        listener = [
          {
            timeout = 150;
            on-timeout = "${idleControl} dim";
            on-resume = "${idleControl} restore-screen";
          }
          # keyboard backlight when timout has passed, screen on when activity detected.
          {
            timeout = 150;
            on-timeout = "${idleControl} keyboard-off";
            on-resume = "${idleControl} restore-keyboard";
          }
          # lock screen when timeout thas passed.
          {
            timeout = 180;
            on-timeout = "${idleControl} idle-lock";
          }
          # screen off when timeout has passed, screen on when activity detected.
          {
            timeout = 330;
            on-timeout = "${idleControl} display-off";
            on-resume = wakeDisplay;
          }
          {
            timeout = 500;
            on-timeout = "${idleControl} idle-suspend";
          }
        ];
      };
    };

  # All listeners respect audio/browser idle inhibitors. The timeout commands
  # independently skip lock and suspend while caffeine is active.
  # The low-level lid inhibitor applies only while this service is running.
  systemd.user.services.hypridle-caffeine = {
    Unit.Description = "Keep the laptop awake (hypridle caffeine)";
    Service.ExecStart = "${pkgs.systemd}/bin/systemd-inhibit --what=handle-lid-switch --who=caffeine --why='Caffeine toggle' ${pkgs.coreutils}/bin/sleep infinity";
  };

}
