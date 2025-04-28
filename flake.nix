{
  description = "WordPress Theme Development Env";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.devenv.url = "github:cachix/devenv";

  outputs = { self, nixpkgs, devenv, ... }:
    devenv.lib.mkFlake {
      pkgs = import nixpkgs { system = "x86_64-linux"; };

      devShells.default = { pkgs, ... }: {
        packages = with pkgs; [
          php
          nodejs_latest
          yarn
          git
          sass
          tailwindcss
          wordpress-cli
        ];

        env = {
          WP_ENV = "development";
          THEME_DIR = "./wp-content/themes/my-theme";
        };
      };
    };
}
