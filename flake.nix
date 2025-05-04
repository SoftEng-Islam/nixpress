{
  description = "WordPress + PHP + MySQL + Caddy dev environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    devenv.url = "github:cachix/devenv";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, devenv, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { inherit system; };
      in {
        devShells.default = devenv.lib.mkShell {
          inherit pkgs;

          languages.php.enable = true;

          languages.php.package = pkgs.php82.buildEnv {
            extensions = { all, enabled }:
              enabled ++ (with all; [ redis pdo_mysql xdebug ]);
            extraConfig = ''
              memory_limit = -1
              xdebug.mode = debug
              xdebug.start_with_request = yes
              xdebug.idekey = vscode
              xdebug.log_level = 0
              max_execution_time = 0
            '';
          };

          services.mysql = {
            enable = true;
            initialDatabases = [{ name = "wordpress"; }];
            ensureUsers = [{
              name = "softeng";
              password = "1122";
              ensurePermissions = { "wordpress.*" = "ALL PRIVILEGES"; };
            }];
          };

          services.redis.enable = true;

          services.caddy = {
            enable = true;
            virtualHosts."wp.localhost".extraConfig = ''
              root * .
              php_fastcgi 127.0.0.1:9000
              file_server
            '';
          };

          certificates = [ "wp.localhost" ];

          packages = with pkgs; [ git wp-cli mariadb php82 caddy ];
        };
      });
}
