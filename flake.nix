{
  description = "WordPress dev env with PHP, MySQL, Redis, and Caddy";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
    devenv.url = "github:cachix/devenv";
  };

  outputs = { self, nixpkgs, flake-utils, devenv, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { inherit system; };
      in {
        devShells.default = devenv.lib.mkShell {
          inherit pkgs;

          packages = with pkgs; [ git wp-cli mariadb php82 ];

          languages.php.enable = true;

          languages.php.package = pkgs.php82.buildEnv {
            extensions = { all, enabled }:
              enabled ++ (with all; [ redis pdo_mysql xdebug ]);
            extraConfig = ''
              memory_limit = -1
              max_execution_time = 0
              xdebug.mode = debug
              xdebug.start_with_request = yes
              xdebug.idekey = vscode
            '';
          };

          services.redis.enable = true;

          services.mysql = {
            enable = true;
            initialDatabases = [{ name = "wordpress"; }];
            ensureUsers = [{
              name = "softeng";
              password = "1122";
              ensurePermissions = { "wordpress.*" = "ALL PRIVILEGES"; };
            }];
          };

          services.caddy = {
            enable = true;
            virtualHosts."wp.localhost".extraConfig = ''
              root * .
              php_fastcgi 127.0.0.1:9000
              file_server
            '';
          };

          certificates = [ "wp.localhost" ];
        };
      });
}
