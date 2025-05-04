{ config, pkgs, lib, ... }:

{
  imports = [
    # Enable basic services
    <nixos/modules/services/networking/ssh-server.nix>
    <nixos/modules/services/web-servers/nginx.nix>
    <nixos/modules/services/databases/mysql.nix>
  ];

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  # MySQL Setup
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    ensureDatabases = [ "wordpress" ];
    ensureUsers = [{
      name = "wordpressuser";
      password = "strong_password";
      privileges = { "wordpress.*" = "ALL PRIVILEGES"; };
    }];
  };

  # PHP Setup
  services.phpfpm.enable = true;
  services.phpfpm.pools.web = {
    settings = {
      "pm" = "dynamic";
      "pm.max_children" = 32;
      "pm.max_requests" = 500;
      "pm.start_servers" = 2;
      "pm.min_spare_servers" = 2;
      "pm.max_spare_servers" = 5;
    };
  };

  # NGINX Setup
  services.nginx = {
    enable = true;
    virtualHosts."localhost" = {
      documentRoot = "/var/www/wordpress";
      locations."/" = {
        fastcgiPass = "unix:/run/php-fpm.sock";
        extraConfig = ''
          fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
          include fastcgi_params;
        '';
      };
    };
  };

  # SSL Configuration (optional)
  services.nginx.virtualHosts."localhost".extraConfig = ''
    ssl_certificate /etc/ssl/certs/mydomain.pem;
    ssl_certificate_key /etc/ssl/private/mydomain-key.pem;
  '';
}
