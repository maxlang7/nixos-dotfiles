# Miracast permissions and P2P RTSP access for the local Roku launcher.
{ pkgs, ... }: {
  services.dbus.packages = [ (pkgs.writeTextDir
    "share/dbus-1/system.d/zz-dev.fluxcast.wpa-supplicant.conf" ''
<!DOCTYPE busconfig PUBLIC
 "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <!--
    FluxCast needs Properties.Set for P2PDeviceConfig (device name + GO intent).
    D-Bus cannot limit that grant to a single property, so scope who may send it:
    wheel on Arch/Fedora, sudo on Debian/Ubuntu. Do not use context="default" —
    that would override wpa_supplicant's intentional deny for every local account.
  -->
  <policy group="wheel">
    <allow send_destination="fi.w1.wpa_supplicant1"
           send_interface="org.freedesktop.DBus.Properties"
           send_member="Get"/>
    <allow send_destination="fi.w1.wpa_supplicant1"
           send_interface="org.freedesktop.DBus.Properties"
           send_member="Set"/>
    <allow receive_sender="fi.w1.wpa_supplicant1"/>
  </policy>
  <policy group="sudo">
    <allow send_destination="fi.w1.wpa_supplicant1"
           send_interface="org.freedesktop.DBus.Properties"
           send_member="Get"/>
    <allow send_destination="fi.w1.wpa_supplicant1"
           send_interface="org.freedesktop.DBus.Properties"
           send_member="Set"/>
    <allow receive_sender="fi.w1.wpa_supplicant1"/>
  </policy>

  <!--
    Unlike NetworkManager, wpa_supplicant has no polkit integration, so it
    can never consult a polkit action at call time - all of its D-Bus
    authorization comes from this static, group-based policy.

    No netdev block here on purpose. Debian/Ubuntu already ship a
    <policy group="netdev"> in their own wpa_supplicant.conf with a bare
    send_destination and no member restriction, so netdev members have
    unrestricted access to the service there and this file, which only
    contains allow rules, cannot narrow that. Arch has no netdev group at
    all, so a block here would only make dbus-daemon log "unknown group".

    Everything else - the P2PDevice actions the wpas backend calls, and its
    IP-layer work (raw ip/dnsmasq/dhcpcd, not D-Bus) - needs real root.
    _gdbus_call retries those under sudo after an AccessDenied.
  -->
</busconfig>
    '') ];
  # Limit incoming Miracast RTSP to the dynamically named P2P interfaces.
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -i p2p-+ -p tcp --dport 7236 -j nixos-fw-accept
  '';
  networking.firewall.extraStopCommands = ''
    iptables -D nixos-fw -i p2p-+ -p tcp --dport 7236 -j nixos-fw-accept 2>/dev/null || true
  '';
  services.udev.packages = [
    (pkgs.writeTextDir "lib/udev/rules.d/zz-roku-p2p.rules" ''
      # Run after 99-local.rules. Clear queued hotplug programs for P2P
      # interfaces so creating one cannot restart wpa_supplicant.
      # Physical Wi-Fi interfaces keep their normal hotplug behavior.
      ACTION=="add|remove", SUBSYSTEM=="net", KERNEL=="p2p-*", RUN="${pkgs.coreutils}/bin/true"
    '')
  ];
}
