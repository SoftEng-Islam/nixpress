{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ wget ];

  # Install WordPress
  environment.etc."wordpress".source = pkgs.fetchurl {
    url = "https://wordpress.org/latest.tar.gz";
    sha256 = "0baf3a564b8d3f07865b82d3e3b4b362cfec9b5f4cf562e4d4d204bcd98c5cd6";
  };

  # Unpack WordPress
  systemd.tmpfiles.rules = [
    "d /var/www/wordpress"
    "f /var/www/wordpress/index.php - - - - <?php phpinfo(); ?>"
  ];
}
