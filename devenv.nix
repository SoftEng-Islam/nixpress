{ pkgs, lib, config, inputs, ... }:
let
  listenPort = 8062;
  serverName = "localhost";
  wordpressRoot = ./html; # Define the WordPress installation directory
in {
  env.WORDPRESS_VERSION = "6.8.1";
  env.WORDPRESS_REPO = "https://github.com/WordPress/WordPress";
  env.GREET = "devenv";

  packages = [ pkgs.git pkgs.wp-cli pkgs.caddy ];

  languages.php.package = pkgs.php83.buildEnv {
    extensions = ({ enabled, all }: enabled ++ (with all; [ yaml ]));
    extraConfig = ''
      sendmail_path = ${config.services.mailpit.package}/bin/mailpit sendmail -S ${serverName}:${
        toString config.services.mailpit.settings.smtpPort
      }
      smtp_port = 1025 # While PHP knows this, Mailpit's port is dynamic in devenv
    '';
  };
  languages.php = {
    enable = true;
    ini = ''
      memory_limit = 256M
    '';
    fpm.pools.web.settings = {
      "pm" = "dynamic";
      "pm.max_children" = 10;
      "pm.start_servers" = 2;
      "pm.min_spare_servers" = 1;
      "pm.max_spare_servers" = 10;
      "access.log" = "/tmp/php-fpm.access.log";
      "slowlog" = "/tmp/php-fpm.slow.log";
      "request_slowlog_timeout" = "5s";
      "catch_workers_output" = "yes";
      "listen" = "/run/php-fpm-web.sock"; # Explicitly define the socket path
    };
    fpm.pools.web.socket =
      "/run/php-fpm-web.sock"; # Make the socket path available
  };

  services.mysql = {
    enable = true;
    settings.mysqld.port = 3307;
    initialDatabases = [{ name = "wordpress"; }];
    ensureUsers = [{
      name = "wordpress";
      password = "wordpress";
      ensurePermissions = { "wordpress.*" = "ALL PRIVILEGES"; };
    }];
  };

  services.caddy.enable = false;
  services.caddy.virtualHosts."http://${serverName}:${toString listenPort}" = {
    root = "${wordpressRoot}"; # Use the defined wordpressRoot
    phpFastCGI =
      "unix:${config.languages.php.fpm.pools.web.socket}"; # Use the explicit socket path
    fileServer = true;
    rewrite = [
      {
        from = "/wp-admin{suffix}";
        to = "/wp-admin{suffix}/";
      }
      {
        from = "{file}";
        to = "{file}";
      }
      {
        from = "{dir}";
        to = "{dir}/";
      }
      {
        from = ".+";
        to = "/index.php?{query}";
      }
    ];
  };

  services.nginx = {
    enable = true;
    httpConfig = ''
      types_hash_max_size 2048;
      types_hash_bucket_size 128;
      keepalive_timeout  65;
      server {
        listen ${toString listenPort};
        root ${wordpressRoot}; # Use the defined wordpressRoot
        index index.php index.html;
        server_name ${serverName};

        # WordPress rewrite rules
        location / {
          try_files $uri $uri/ /index.php?$args;
        }

        location ~ \.php$ {
          try_files $uri =404;
          fastcgi_pass unix:${config.languages.php.fpm.pools.web.socket}; # Use the explicit socket path
          fastcgi_index index.php;
          include ${pkgs.nginx}/conf/fastcgi.conf;
        }
    '' + (builtins.readFile ./conf/nginx/locations) + "}";
  };

  services.mailpit = { enable = true; };

  scripts.hello.exec = ''
    echo hello from $GREET
  '';

  enterShell = ''
    echo "Setting up WordPress environment..."
    test -d ${wordpressRoot} || git clone --depth 1 --branch ${config.env.WORDPRESS_VERSION} ${config.env.WORDPRESS_REPO} ${wordpressRoot}
    cd ${wordpressRoot}
    if [ -f composer.json ]; then
      echo "Running composer install..."
      composer install
    else
      echo "No composer.json found, skipping composer install"
    fi
    wp core config create --dbname=wordpress --dbuser=wordpress --dbpass=wordpress --dbhost=localhost:${
      toString config.services.mysql.settings.mysqld.port
    } --path='.' --url=http://${serverName}:${toString listenPort} --yes
    wp core install --title="Devenv WordPress" --admin_user=admin --admin_password=password --admin_email=admin@example.com --skip-email --yes

    echo ""
    echo "🚀 WordPress is available at: http://${serverName}:${
      toString listenPort
    }"
    echo ""

    if command -v xdg-open > /dev/null; then
      xdg-open http://${serverName}:${toString listenPort}
    elif command -v open > /dev/null; then
      open http://${serverName}:${toString listenPort}
    else
      echo "⚠️ Could not detect a browser command to open the URL."
    fi
  '';

  processes.open-url.exec = ''
    echo ""
    echo "🚀 WordPress is running at: http://${serverName}:${
      toString listenPort
    }"
    echo ""

    if command -v xdg-open > /dev/null; then
      xdg-open http://${serverName}:${toString listenPort}
    elif command -v open > /dev/null; then
      open http://${serverName}:${toString listenPort}
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
