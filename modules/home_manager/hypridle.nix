{ pkgs, ... }:
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
            after_sleep_cmd = "hyprctl dispatch dpms on";  # to avoid having to press a key twice to turn on the display.
          }
        ];
          # set monitor backlight to minimum when timeout has passed, restore monitor backlight when activity detected.
        listener = [
          {
            timeout = 150;
            on-timeout = "brightnessctl -s set 50%-";
            on-resume = "brightnessctl -r";
          }
          # keyboard backlight when timout has passed, screen on when activity detected.
          {
            timeout = 150;
            on-timeout = "brightnessctl -sd rgb:kbd_backlight set 0";
            on-resume = "brightnessctl -rd rgb:kbd_backlight";
          }
          # lock screen when timeout thas passed.
          {
            timeout = 180;
            on-timeout = "loginctl lock-session";
          }
          # screen off when timeout has passed, screen on when activity detected.
          {
            timeout = 330;
            on-timeout = "hyprctl dispatch dpms off";
            on-resume = "hyprctl dispatch dpms on";
          }
          {
            timeout = 500;
            on-timeout = "systemctl suspend";
          }
        ];
      };
    };

  # Caffeine is an idle inhibitor, not a stopped hypridle. hypridle honours
  # systemd idle inhibitors, so its timeouts pause while this runs, but it stays
  # alive to fire on-resume (dpms on) and before_sleep_cmd (lock on lid close).
  # Stopping hypridle instead left the screen DPMS-off with no one to wake it.
  systemd.user.services.hypridle-caffeine = {
    Unit.Description = "Keep the laptop awake (hypridle caffeine)";
    Service.ExecStart = "${pkgs.systemd}/bin/systemd-inhibit --what=idle --who=caffeine --why='Caffeine toggle' ${pkgs.coreutils}/bin/sleep infinity";
  };

  # The Waybar hypridle icon is the manual caffeine toggle. These timers call
  # the same script so the scheduled and clicked states cannot drift apart.
  systemd.user.services.hypridle-caffeine-schedule = {
    Unit.Description = "Apply the scheduled hypridle caffeine state";
    Service = {
      Type = "oneshot";
      ExecStart = "/etc/nixos/artifacts/scripts/hypridle-toggle.sh schedule";
    };
  };

  systemd.user.timers = {
    hypridle-caffeinate = {
      Unit.Description = "Caffeinate the laptop at 01:00";
      Timer = {
        OnCalendar = "*-*-* 01:00:00";
        AccuracySec = "1s";
        Persistent = true;
        Unit = "hypridle-caffeine-schedule.service";
      };
      Install.WantedBy = [ "timers.target" ];
    };

    hypridle-uncaffeinate = {
      Unit.Description = "Uncaffeinate the laptop at 08:30";
      Timer = {
        OnCalendar = "*-*-* 08:30:00";
        AccuracySec = "1s";
        Persistent = true;
        Unit = "hypridle-caffeine-schedule.service";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
