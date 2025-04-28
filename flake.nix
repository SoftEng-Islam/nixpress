{
  description = "Learnify - WordPress Online Courses Platform";

  inputs = {
    nixpkgs.url =
      "github:NixOS/nixpkgs/nixos-24.05"; # Or use the latest stable branch
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

        # For NixOS configurations, you can include services directly in the `nixosConfigurations`:
        nixosConfigurations = {
          myWordPressHost = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              # Enable Nginx and other services here
              ./wordpress-setup.nix # Path to your service configuration
            ];
            configuration = {
              networking.hostName = "wordpress-server";
              services.nginx.enable = true;
              services.phpfpm.enable = true;
              services.mysql.enable = true;
              environment.systemPackages = with pkgs; [
                wordpress
                nginx
                php82
                mariadb
                php82Packages.mysql
                php82Packages.gd
                php82Packages.mbstring
                php82Packages.xml
                php82Packages.json
              ];
              # Additional WordPress setup
            };
          };
        };
      });
}
