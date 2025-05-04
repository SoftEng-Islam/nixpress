{
  description =
    "WordPress + PHP + NGINX + MySQL development environment on NixOS";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nixos.url = "github:NixOS/nixos";
  };

  outputs = { self, nixpkgs, flake-utils, nixos, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShell = pkgs.mkShell {
          buildInputs = [
            pkgs.php
            pkgs.php82
            pkgs.php82.extensions.pdo_mysql
            pkgs.php82.extensions.redis
            pkgs.wp-cli
            pkgs.mysql
            pkgs.nginx
          ];

          shellHook = ''
            echo "Welcome to your WordPress development environment!"
            export WORDPRESS_DIR=${toString ./wordpress}
          '';
        };

        nixosConfigurations = {
          wpHost = nixos.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [ ./nix/config.nix ./nix/wordpress.nix ./nix/mysql.nix ];
            specialArgs = { inherit system; };
          };
        };
      });
}
