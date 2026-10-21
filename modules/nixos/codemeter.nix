{ pkgs, ... }:
let
  codemeter = pkgs.callPackage ../../packages/codemeter { };
  fhs = "${codemeter}/bin/codemeter-fhs";
  initialConfig = pkgs.writeText "codemeter-Server.ini" ''
    [General]
    ApiCommunicationMode=1
    ApiCommunicationModeServer=1
    BindAddress=127.0.0.1
    NetworkPort=22350
    IsNetworkServer=0
    IsCmWANServer=0
    ExePath=/opt/codemeter/sbin
    HelpFile=/opt/codemeter/share/doc/CodeMeter
    LogPath=/var/log/CodeMeter
    LogCmActDiag=1
    StartDaemon=1
    TimeServerTimeout=20
    TimeServerURL1=cmtime.codemeter.com
    TimeServerURL2=cmtime.codemeter.us
    TimeServerURL3=cmtime.codemeter.de
    TrustedWebSocketOrigins1=https://licensecentral-bbio.bruker.com

    [HTTP]
    Port=22352
    RemoteRead=0
    ReadAuthenticationEnabled=0

    [HTTPS]
    Port=22353
    Enabled=1

    [TripleModeRedundancy]
    TmrEnabled=0
  '';
  serviceConfig = pkgs.writeText "codemeter-cmservices.yaml" ''
    FileVersion: 1
    InterServiceCommunication:
      ExpectedRuntimeServices:
        - CmBackendClassic
      UseTcp: False
  '';
  seedState = pkgs.writeShellScript "codemeter-preserve-activation-state" ''
    set -eu
    source=/home/maxlang/.local/share/topspin-wine-runtime/state/CodeMeter/CmAct
    destination=/var/lib/CodeMeter/CmAct
    # Copy the existing activation context once, retaining the user's original.
    # Never overwrite a container already managed by the native service.
    if [ ! -e "$destination/Catalogue.WibuCmHt" ] && [ -f "$source/Catalogue.WibuCmHt" ]; then
      ${pkgs.coreutils}/bin/cp -an --no-preserve=ownership "$source/." "$destination/"
      ${pkgs.coreutils}/bin/chown -R codemeter-backend-classic:codemeter-backend-classic "$destination"
    fi
  '';
in
{
  environment.systemPackages = [ codemeter ];
  users.groups.codemeter-backend-classic = { };
  users.groups.codemeter-webadmin = { };
  users.users.codemeter-backend-classic = {
    isSystemUser = true;
    group = "codemeter-backend-classic";
  };
  users.users.codemeter-webadmin = {
    isSystemUser = true;
    group = "codemeter-webadmin";
  };
  systemd.tmpfiles.rules = [
    "d /var/lib/CodeMeter 0755 codemeter-backend-classic codemeter-backend-classic -"
    "d /var/lib/CodeMeter/CmAct 0750 codemeter-backend-classic codemeter-backend-classic -"
    "d /var/lib/CodeMeter/CmCloud 0750 codemeter-backend-classic codemeter-backend-classic -"
    "d /var/lib/CodeMeter/WebAdmin 0755 codemeter-webadmin codemeter-webadmin -"
    "d /var/lib/codemeter-config 0755 codemeter-backend-classic codemeter-backend-classic -"
    "C /var/lib/codemeter-config/Server.ini 0644 codemeter-backend-classic codemeter-backend-classic - ${initialConfig}"
    "C /var/lib/codemeter-config/cmservices.yaml 0644 codemeter-backend-classic codemeter-backend-classic - ${serviceConfig}"
    "d /var/log/CodeMeter 0750 codemeter-backend-classic codemeter-backend-classic -"
  ];
  systemd.services.codemeter = {
    description = "CodeMeter licensing backend for TopSpin";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStartPre = [
        "+${seedState}"
        # WIBU's Debian post-install script performs this initialization as root.
        # It exits 2 once the state is already initialized, so "-" keeps that
        # from blocking the backend.
        "-+${fhs} -c 'exec /opt/codemeter/sbin/CodeMeterLin -x'"
      ];
      ExecStart = "${fhs} -c 'exec /opt/codemeter/sbin/CodeMeterLin -v'";
      User = "codemeter-backend-classic";
      Group = "codemeter-backend-classic";
      LimitNOFILE = 99999;
      PrivateUsers = false;
      KeyringMode = "private";
      RemoveIPC = true;
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
  systemd.services.codemeter-webadmin = {
    description = "CodeMeter local WebAdmin and browser activation interface";
    wantedBy = [ "multi-user.target" ];
    requires = [ "codemeter.service" ];
    after = [ "codemeter.service" ];
    serviceConfig = {
      ExecStart = "${fhs} -c 'exec /opt/codemeter/sbin/CmWebAdmin'";
      User = "codemeter-webadmin";
      Group = "codemeter-webadmin";
      IPAddressDeny = "any";
      IPAddressAllow = "localhost";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };
}
