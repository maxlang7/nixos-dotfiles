{config, pkgs, ...}:
{
  # Very very in progress
  services.nginx = {
    enable = true;
    virtualHosts."localhost" = {
      root = "/home/maxlang/fish";
      locations."~ \\.php$".extraConfig = '' 
        fastcgi_pass 127.0.0.1:9000
        fastfgi_index index.php;
        include ${pkgs.nginx}/conf/fastcgi_params;
      '';
    };
  };
  
  virtualisation = {
    podman = {
      enable = true;
      # Enable Docker compatibility
      dockerCompat = true;
    };
    oci-containers.containers = {
      fish = {
        image = "php:8.2-fpm";
        autoStart = true;
        ports = [ "127.0.0.1:9000:9000" ];
        volumes = [ "/home/maxlang/fish:/var/www/html" ];
        extraOptions = [
          "--network=host"
        ];
      };
    };

  };

}