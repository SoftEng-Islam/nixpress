{
  description = "Learnify - WordPress Online Courses Platform";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05"; # Use the latest stable
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { inherit system; };
      in {
        devShells.default = pkgs.mkShell {
          name = "learnify-dev-shell";

          packages = with pkgs; [
            wordpress
            php82
            php82Packages.mysql
            php82Packages.gd
            php82Packages.mbstring
            php82Packages.xml
            php82Packages.json
            mariadb
            nginx
            openssl
            curl
          ];

          shellHook = ''
            echo "🚀 Welcome to the Learnify Development Environment!"
            echo "✔ PHP Version: $(php -v | head -n 1)"
            echo "✔ MariaDB Version: $(mysql --version)"
            echo "✔ WordPress Path: ${pkgs.wordpress}"
            echo "🛠️ Remember to start your database and nginx manually if needed."
          '';
        };
      });
}
