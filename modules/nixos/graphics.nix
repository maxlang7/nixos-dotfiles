# ════════════════════════════════════════════════════════════════════════════
#  Graphics / GPU — Intel Iris Xe (TGL GT2) on the Framework 13
# ────────────────────────────────────────────────────────────────────────────
#  Before this module existed, `hardware.graphics` was never configured
#  anywhere in the flake, so the system got mesa and nothing else:
#  /run/opengl-driver contained only mesa's own *_dri.so files and
#  `vainfo` failed with `va_openDriver() returns -1` — iHD_drv_video.so was
#  simply absent. OpenGL worked, but *every* video decode ran on the CPU.
# ════════════════════════════════════════════════════════════════════════════
{ pkgs, ... }:
{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver # iHD — the VAAPI driver for Gen8+ (this is the fix)
      vpl-gpu-rt # oneVPL runtime, successor to intel-media-sdk
      libvdpau-va-gl # VDPAU -> VAAPI shim for the odd app that wants VDPAU
    ];
  };

  # iHD is the modern driver; without pinning this, libva probes i965 (which
  # does not support this GPU) and falls back to software.
  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

  # Brave/Chromium poll UPower over D-Bus for battery status. It was never
  # enabled, so every Chromium start logged
  #   "org.freedesktop.UPower was not provided by any .service files".
  services.upower.enable = true;

  environment.systemPackages = with pkgs; [
    libva-utils # `vainfo` — verify the driver actually loads
  ];
}
