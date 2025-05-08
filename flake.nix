{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    devenv.url = "github:cachix/devenv";
  };

  nixConfig = {
    extra-trusted-public-keys =
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs = { self, nixpkgs, devenv, ... }@inputs:
    let
      listenPort = 8062;
      serverName = "localhost";
      wordpressRoot = ./html; # Define the WordPress installation directory
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      packages.${system}.devenv-up =
        self.devShells.${system}.default.config.procfileScript;
      packages.${system}.devenv-test =
        self.devShells.${system}.default.config.test;

      networking.firewall.enable = true;
      networking.firewall.allowedTCPPorts = [ 8080 8443 80 443 ];

      devShells.${system}.default = devenv.lib.mkShell {
        inherit inputs pkgs;
        modules = [
          ({ pkgs, config, ... }: {
            # This is your devenv configuration
            packages = with pkgs; [
              caddy
              git
              wp-cli

              phpactor

              dart-sass
              lightningcss

              tailspin
            ];
            env.WORDPRESS_VERSION = "6.8.1";
            env.WORDPRESS_REPO = "https://github.com/WordPress/WordPress";
            env.GREET = "devenv";
            languages.javascript.enable = true;
            languages.php.enable = true;
            languages.php.package = pkgs.php82.buildEnv {
              extensions = { all, enabled }:
                with all;
                enabled ++ [ redis pdo_mysql xdebug ];
              extraConfig = ''
                memory_limit = -1
                xdebug.mode = debug
                xdebug.start_with_request = yes
                xdebug.idekey = vscode
                xdebug.log_level = 0
                max_execution_time = 0
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

            services.caddy.enable = false;
            services.caddy.virtualHosts."http://${serverName}:${
              toString listenPort
            }" = {
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

            enterShell = ''
              hello
            '';

            processes.run.exec = "hello";
          })
        ];
      };
    };
}
