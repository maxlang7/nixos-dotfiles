# Sleep, hibernate and resume.
#
# Layout of the night, assuming the lid closes in the evening:
#   lid close  -> S3 (deep suspend, ~0.5-1%/hr)
#   03:00      -> RTC alarm wakes the machine, nixos-upgrade runs
#   after run  -> hibernate (~0%/hr for the rest of the night)
#
# HibernateDelaySec is deliberately longer than a normal evening-to-3am gap.
# RTC wake pulls the machine out of S3 but cannot power the board back on from
# S4, so hibernating before 03:00 would silently cancel the nightly upgrade.
# Staying in S3 until the job runs costs a few percent of charge and keeps the
# wake working; autoupgrade.nix then hibernates once it is done.
{ ... }:
{
  boot.kernel.sysctl = {
    # Default kernel value. Only relevant here because a swapfile now exists.
    "vm.swappiness" = 60;
  };

  # 32 GiB for 31 GiB of RAM, so a full memory image always fits.
  swapDevices = [{
    device = "/var/lib/swapfile";
    size = 32 * 1024;
  }];

  boot.kernelParams = [
    # Physical block offset of /var/lib/swapfile, from:
    #   sudo filefrag -v /var/lib/swapfile | awk 'NR==4 {print $4}'
    # This MUST be recomputed if the swapfile is ever deleted and recreated,
    # or the machine will fail to resume and silently cold-boot instead.
    "resume_offset=@RESUME_OFFSET@"

    # Use S3 rather than s2idle. On this 11th-gen Intel board S3 roughly halves
    # idle drain, and the RTC alarm still wakes from it.
    "mem_sleep_default=deep"
  ];

  # Root ext4 filesystem holding the swapfile. The previous value here was the
  # vfat EFI partition (2870-2353), which could never have resumed.
  boot.resumeDevice = "/dev/disk/by-uuid/c13c896f-2532-44ae-a99d-114d8b67ac83";

  services.logind = {
    lidSwitch = "suspend-then-hibernate";
    lidSwitchExternalPower = "lock";
    powerKey = "hibernate";
    powerKeyLongPress = "poweroff";
  };

  systemd.sleep.extraConfig = ''
    HibernateDelaySec=5h
    SuspendState=mem
  '';
}
