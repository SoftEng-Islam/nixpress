{ pkgs, lib, config, inputs, ... }:
let
  listenPort = 9000;
  serverName = "localhost";
  wordpressRoot = "${config.devenv.root}/html";
in {
  env.WORDPRESS_VERSION = "6.8";
  env.WORDPRESS_REPO = "https://github.com/WordPress/WordPress";
  env.GREET = "devenv";

  packages = [ pkgs.git pkgs.wp-cli pkgs.caddy pkgs.mariadb pkgs.composer ];

  languages.php = {
    enable = true;
    version = "8.3";
    extensions = [ "yaml" ];
    ini = ''
      memory_limit = 256M
      upload_max_filesize = 64M
      post_max_size = 64M
    '';
    fpm.pools.web = {
      settings = {
        listen = "127.0.0.1:${toString listenPort}";
        "pm" = "dynamic";
        "pm.max_children" = 10;
        "pm.start_servers" = 2;
        "pm.min_spare_servers" = 1;
        "pm.max_spare_servers" = 10;
        "access.log" = "/tmp/php-fpm.access.log";
        "slowlog" = "/tmp/php-fpm.slow.log";
        "request_slowlog_timeout" = "5s";
        "catch_workers_output" = "yes";
      };
    };
  };

  processes.php-fpm.exec =
    "${config.languages.php.fpm.pools.web.phpPackage}/bin/php-fpm --nodaemonize --fpm-config ${config.languages.php.fpm.pools.web.finalConfig}";

  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    settings.mysqld.port = 3306;
    initialDatabases = [{ name = "wordpress"; }];
    ensureUsers = [{
      name = "wordpress";
      password = "wordpress";
      ensurePermissions = { "wordpress.*" = "ALL PRIVILEGES"; };
    }];
  };

  services.caddy = {
    enable = true;
    virtualHosts."${serverName}" = {
      extraConfig = ''
        root * ${wordpressRoot}
        php_fastcgi 127.0.0.1:${toString listenPort}
        file_server
      '';
    };
  };

  services.mailpit = {
    enable = true;
    openFirewall = true;
  };

  scripts.hello.exec = ''
    echo hello from $GREET
  '';

  scripts.wp.exec = ''
    ${pkgs.wp-cli}/bin/wp --path=${wordpressRoot} "$@"
  '';

  enterShell = let
    wpConfig = pkgs.writeText "wp-config.php" ''
      <?php
      define('DB_NAME', 'wordpress');
      define('DB_USER', 'wordpress');
      define('DB_PASSWORD', 'wordpress');
      define('DB_HOST', '127.0.0.1');
      define('DB_CHARSET', 'utf8');
      define('DB_COLLATE', "");

      define('WP_DEBUG', true);
      define('WP_DEBUG_LOG', true);

      if (!defined('ABSPATH')) {
        define('ABSPATH', __DIR__ . '/');
      }

      require_once ABSPATH . 'wp-settings.php';
    '';
  in ''
    # Clone WordPress if not already present
    if [ ! -d "${wordpressRoot}" ]; then
      git clone --depth 1 --branch "$WORDPRESS_VERSION" "$WORDPRESS_REPO" "${wordpressRoot}"
      chmod -R 755 "${wordpressRoot}"
      chmod -R 777 "${wordpressRoot}/wp-content"
    fi

    # Install composer dependencies if composer.json exists
    if [ -f "${wordpressRoot}/composer.json" ]; then
      composer install --working-dir="${wordpressRoot}"
    else
      echo "No composer.json found, skipping composer install"
    fi

    # Create wp-config.php if it doesn't exist
    if [ ! -f "${wordpressRoot}/wp-config.php" ]; then
      cp ${wpConfig} "${wordpressRoot}/wp-config.php"
      chmod 644 "${wordpressRoot}/wp-config.php"
    fi

    php --version

    echo ""
    echo "🚀 WordPress is available at: http://${serverName}:80"
    echo "MySQL credentials:"
    echo "  Database: wordpress"
    echo "  Username: wordpress"
    echo "  Password: wordpress"
    echo ""

    # Open in browser (cross-platform)
    if command -v xdg-open > /dev/null; then
      xdg-open http://${serverName}
    elif command -v open > /dev/null; then
      open http://${serverName}
    else
      echo "⚠️ Could not detect a browser command to open the URL."
    fi
  '';

  processes.open-url.exec = ''
    echo ""
    echo "🚀 WordPress is running at: http://${serverName}"
    echo ""

    if command -v xdg-open > /dev/null; then
      xdg-open http://${serverName}
    elif command -v open > /dev/null; then
      open http://${serverName}
    else
      echo "⚠️ Could not detect a browser command to open the URL."
    fi

    sleep 300
  '';

  enterTest = ''
    echo "Running tests"
    git --version | grep --color=auto "${pkgs.git.version}"
  '';
}
