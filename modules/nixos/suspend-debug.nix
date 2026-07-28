{ pkgs, ... }:
{
  # Verbose PM debug messages + keep consoles alive across suspend so
  # printk output during the s2idle resume path actually reaches the
  # kernel ring buffer / journal instead of being silently dropped.
  boot.kernelParams = [
    "pm_debug_messages"
    "no_console_suspend"
  ];

  # Bigger ring buffer so an early-resume hang doesn't wrap out the
  # suspend-entry messages before journald can read them.
  boot.kernel.sysctl."kernel.printk" = "7 4 1 7";

  environment.etc."systemd/system-sleep/dump-pm-state.sh" = {
    mode = "0755";
    text = ''
      #!/bin/sh
      # Snapshots PM/idle-residency state around every suspend cycle so a
      # hung resume (blank screen, LED stuck flashing, needs a hard reboot)
      # has something to compare against afterwards. Logs to a plain file
      # (not just the journal) and fsyncs, since a hard power-cycle can
      # lose unsynced journal writes even with Storage=persistent.
      LOG=/var/log/suspend-debug.log
      TS=$(date -Iseconds)
      {
        echo "=== $TS action=$1 stage=$2 ==="
        if [ "$1" = "pre" ]; then
          echo "-- pmc_core substate residencies (before) --"
          cat /sys/kernel/debug/pmc_core/substate_residencies 2>/dev/null
          echo "-- wakeup sources --"
          cat /sys/kernel/debug/wakeup_sources 2>/dev/null
          echo "-- mem_sleep --"
          cat /sys/power/mem_sleep 2>/dev/null
        else
          echo "-- pmc_core substate residencies (after) --"
          cat /sys/kernel/debug/pmc_core/substate_residencies 2>/dev/null
          echo "-- suspend_stats --"
          cat /sys/power/suspend_stats/* 2>/dev/null | paste -sd' ' -
        fi
      } >> "$LOG" 2>&1
      sync "$LOG" 2>/dev/null || sync
    '';
  };
}
