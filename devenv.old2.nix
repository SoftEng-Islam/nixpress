{ pkgs, config, lib, ... }:

let hostname = "wordpress.local";
in {
  # ENV Vars
  env = {
    WORDPRESS_VERSION = "6.8";
    WORDPRESS_REPO = "https://github.com/WordPress/WordPress";
    DB_NAME = "wordpress1";
    DB_USER = "wordpress";
    DB_PASS = "wordpress"; # In real setup: generate this securely
  };

  packages = with pkgs; [
    git
    wordpress
    mariadb
    openssl
    gnused
    curl
    wp-cli
    caddy
    firefox
  ];

  languages.php = {
    enable = true;
    version = "8.3";
    fpm.pools.wordpress = {
      settings = {
        listen = "127.0.0.1:9000";
        "pm" = "dynamic";
        "pm.max_children" = 10;
        "pm.start_servers" = 2;
        "pm.min_spare_servers" = 1;
        "pm.max_spare_servers" = 4;
      };
    };
  };

  services.mysql = {
    enable = true;
    initialDatabases = [{ name = config.env.DB_NAME; }];
    ensureUsers = [{
      name = config.env.DB_USER;
      password = config.env.DB_PASS;
      ensurePermissions = { "${config.env.DB_NAME}.*" = "ALL PRIVILEGES"; };
    }];
  };

  services.caddy = {
    enable = true;
    virtualHosts."${hostname}" = {
      listenPort = 80;
      extraConfig = ''
        root * html
        index index.php
        try_files {path} {path}/ /index.php?{query}
        php_fastcgi 127.0.0.1:9000
        file_server
      '';
    };
  };

  # Hosts override for local domain resolution
  enterShell = ''
    echo "127.0.0.1 ${hostname}" | sudo tee -a /etc/hosts
    test -d html || git clone --depth 1 --branch ${config.env.WORDPRESS_VERSION} ${config.env.WORDPRESS_REPO} html

    cp html/wp-config-sample.php html/wp-config.php
    sed -i "s/database_name_here/${config.env.DB_NAME}/" html/wp-config.php
    sed -i "s/username_here/${config.env.DB_USER}/" html/wp-config.php
    sed -i "s/password_here/${config.env.DB_PASS}/" html/wp-config.php
    echo "define('FS_METHOD', 'direct');" >> html/wp-config.php

    echo ""
    echo "✅ WordPress ready at: http://${hostname}"
    if command -v xdg-open > /dev/null; then
      xdg-open http://${hostname}
    elif command -v open > /dev/null; then
      open http://${hostname}
    fi
  '';

  # Pre-test
  enterTest = ''
    echo "Checking PHP version..."
    php --version
    echo "Checking MySQL..."
    mysql --version
  '';
}
