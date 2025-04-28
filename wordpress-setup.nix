{ config, pkgs, ... }:

{
  services.nginx = {
    enable = true;
    virtualHosts."yourdomain.com" = {
      root = "/var/www/wordpress";
      index = "index.php index.html index.htm";
      serverName = "yourdomain.com";
      locations."/" = {
        extraConfig = ''
          try_files $uri $uri/ /index.php?$args;
        '';
      };
    };
  };

  services.phpfpm = {
    enable = true;
    poolConfig = ''
      pm = dynamic
      pm.max_children = 50
      pm.start_servers = 5
      pm.min_spare_servers = 5
      pm.max_spare_servers = 35
    '';
  };

  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    ensureDatabases =
      [ "wordpress" ]; # Automatically create the 'wordpress' database
    rootPassword = "your-strong-password"; # Set a root password for MySQL
  };

  environment.systemPackages = with pkgs; [
    wordpress
    nginx
    php82
    php82Packages.mysql
    php82Packages.gd
    php82Packages.mbstring
    php82Packages.xml
    php82Packages.json
  ];

  # Optional SSL/TLS configuration with Let's Encrypt
  security.pki.certificates = [{
    certificateFile = "/etc/letsencrypt/live/yourdomain.com/fullchain.pem";
    keyFile = "/etc/letsencrypt/live/yourdomain.com/privkey.pem";
  }];
}
