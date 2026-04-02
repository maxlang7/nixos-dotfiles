{ config, pkgs, lib, ... }:

let
  ampacheRoot = "/var/www/ampache";
  ampacheUser = "ampache";
  ampacheVersion = "7.8.0";
  phpPackage = pkgs.php84.withExtensions ({ enabled, all }: enabled ++ [
    all.curl
    all.gd
    all.intl
    all.mbstring
    all.mysqlnd
    all.pdo
    all.pdo_mysql
    all.xml
    all.zip
    all.exif
  ]);

  # Fetch the pre-bundled release zip declaratively
  ampacheSrc = pkgs.fetchzip {
    url = "https://github.com/ampache/ampache/releases/download/${ampacheVersion}/ampache-${ampacheVersion}_all_php8.4_squashed.zip";
    sha256 = lib.fakeSha256; # Run once, replace with actual hash from error output
    stripRoot = false;
  };
in
{
  # ── Declarative file deployment ───────────────────────────────
  # Ampache lives in the nix store; symlink into web root
  systemd.tmpfiles.rules = [
    "d ${ampacheRoot} 0750 ${ampacheUser} nginx -"
    "L+ ${ampacheRoot}/public - - - - ${ampacheSrc}/public"
  ];

  # Use a systemd oneshot to copy (not symlink) so Ampache can write config
  systemd.services.ampache-setup = {
    description = "Deploy Ampache web app";
    wantedBy = [ "multi-user.target" ];
    before = [ "phpfpm-ampache.service" "nginx.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "root";
    };
    script = ''
      if [ ! -f ${ampacheRoot}/index.php ]; then
        cp -r ${ampacheSrc}/. ${ampacheRoot}/
        chown -R ${ampacheUser}:nginx ${ampacheRoot}
        chmod -R 750 ${ampacheRoot}
        chmod -R 770 ${ampacheRoot}/config
      fi
    '';
  };

  # ── User & group ──────────────────────────────────────────────
  users.users.${ampacheUser} = {
    isSystemUser = true;
    group = "nginx";
    home = ampacheRoot;
  };

  # ── MariaDB ───────────────────────────────────────────────────
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    ensureDatabases = [ "ampache" ];
    ensureUsers = [{
      name = ampacheUser;
      ensurePermissions = {
        "ampache.*" = "ALL PRIVILEGES";
      };
    }];
  };

  # ── PHP-FPM ───────────────────────────────────────────────────
  services.phpfpm.pools.ampache = {
    user = ampacheUser;
    group = "nginx";
    inherit phpPackage;
    settings = {
      "pm"                   = "dynamic";
      "pm.max_children"      = 10;
      "pm.start_servers"     = 2;
      "pm.min_spare_servers" = 1;
      "pm.max_spare_servers" = 4;
      "listen.owner"         = config.services.nginx.user;
      "listen.group"         = config.services.nginx.group;
      "php_admin_value[upload_max_filesize]" = "100M";
      "php_admin_value[post_max_size]"       = "100M";
      "php_admin_value[memory_limit]"        = "256M";
      "php_admin_value[max_execution_time]"  = "360";
    };
  };

  # ── Nginx ─────────────────────────────────────────────────────
  services.nginx = {
    enable = true;
    virtualHosts."ampache.yourdomain.com" = {
      root = "${ampacheRoot}/public";
      # enableACME = true;
      # forceSSL = true;

      locations."/" = {
        index = "index.php";
        extraConfig = ''
          try_files $uri $uri/ /index.php?$query_string;
        '';
      };

      locations."~ \\.php$" = {
        extraConfig = ''
          fastcgi_pass unix:${config.services.phpfpm.pools.ampache.socket};
          fastcgi_index index.php;
          fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
          include ${pkgs.nginx}/conf/fastcgi_params;
        '';
      };

      locations."~* \\.(env|json|lock)$" = {
        extraConfig = "deny all;";
      };
    };
  };

  # ── Firewall ──────────────────────────────────────────────────
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  # ── Optional transcoding ──────────────────────────────────────
  environment.systemPackages = with pkgs; [ ffmpeg lame flac vorbis-tools ];
}
