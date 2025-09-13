{ pkgs, lib, config, inputs, ... }:
let
  listen_port = 8012;
  server_name = "localhost";
in {
  # https://devenv.sh/basics/
  env.WORDPRESS_VERSION = "6.8.2";
  env.WORDPRESS_REPO = "https://github.com/WordPress/WordPress";
  env.GREET = "devenv";

  # https://devenv.sh/packages/
  packages = [ pkgs.git pkgs.wp-cli ];

  # https://devenv.sh/languages/
  # Configure PHP
  languages.php.package = pkgs.php83.buildEnv {
    extensions = ({ enabled, all }: enabled ++ (with all; [ yaml ]));
    extraConfig = ''
      sendmail_path = ${config.services.mailpit.package}/bin/mailpit sendmail
      smtp_port = 1025
      upload_max_filesize = 64M
      post_max_size = 64M
      max_execution_time = 300
    '';
  };
  languages.php.fpm.pools.web = {
    settings = {
      "clear_env" = "no";
      "pm" = "dynamic";
      "pm.max_children" = 10;
      "pm.start_servers" = 2;
      "pm.min_spare_servers" = 1;
      "pm.max_spare_servers" = 10;
    };
  };
  languages.php.enable = true;

  # https://devenv.sh/processes/
  # processes.cargo-watch.exec = "cargo-watch";

  # https://devenv.sh/services/
  # MySQL
  services.mysql = {
    enable = true;
    initialDatabases = [{ name = "wordpress"; }];
    ensureUsers = [{
      name = "wordpress";
      password = "wordpress";
      ensurePermissions = { "wordpress.*" = "ALL PRIVILEGES"; };
    }];
  };

  # NGINX
  services.nginx = {
    enable = true;
    httpConfig = ''
      server {
      listen ${toString listen_port};
      root ${config.devenv.root}/html;
      index index.php index.html;
      server_name ${server_name};

      # ✅ Increase max upload size
      client_max_body_size 64M;

      # Rewrite rules
      if (!-e $request_filename) {
          rewrite /wp-admin$ $scheme://$host$request_uri/ permanent;
          rewrite ^(/[^/]+)?(/wp-.*) $2 last;
          rewrite ^(/[^/]+)?(/.*\.php) $2 last;
      }

      location ~ \.php$ {
          try_files $uri =404;
          fastcgi_pass unix:${config.languages.php.fpm.pools.web.socket};
          include ${pkgs.nginx}/conf/fastcgi.conf;
      }
    '' + (builtins.readFile ./conf/nginx/locations) + "}";
  };

  # Mailpit
  services.mailpit = { enable = true; };

  # Sets up local WordPress core
  enterShell = ''
    # Clone WordPress core into html/ if not present
    test -d html || git clone --depth 1 --branch ${config.env.WORDPRESS_VERSION} ${config.env.WORDPRESS_REPO} html

    # Ensure we are working inside html/ for WordPress setup
    pushd html > /dev/null
    # Only create wp-config.php if it doesn't exist
    if [ ! -f wp-config.php ]; then
    wp config create \
        --dbname=wordpress \
        --dbuser=wordpress \
        --dbpass=wordpress \
        --dbhost=127.0.0.1 \
        --skip-check
    wp core install \
        --url="http://${server_name}:${toString listen_port}" \
        --title="My Dev Site" \
        --admin_user=admin \
        --admin_password=admin \
        --admin_email=admin@example.com
    fi
    # return to project root.
    popd > /dev/null


    # Run Composer from project root
    composer install

    composer -V
    php --version
    code .
  '';

  processes.open-url.exec = ''

    echo "🚀 WordPress is running at: http://${server_name}:${
      toString listen_port
    }"

    if command -v xdg-open > /dev/null; then
        xdg-open http://${server_name}:${toString listen_port}
    elif command -v open > /dev/null; then
        open http://${server_name}:${toString listen_port}
    else
        echo "⚠️ Could not auto-open browser."
    fi

    # Prevent the process from exiting immediately so it's visible in logs
    sleep 600
  '';

  # https://devenv.sh/tasks/
  # tasks = {
  #   "myproj:setup".exec = "mytool build";
  #   "devenv:enterShell".after = [ "myproj:setup" ];
  # };

  # https://devenv.sh/tests/
  enterTest = ''
    echo "Running tests"
    git --version | grep --color=auto "${pkgs.git.version}"
  '';

  # https://devenv.sh/pre-commit-hooks/
  # pre-commit.hooks.shellcheck.enable = true;

  # See full reference at https://devenv.sh/reference/options/
}
