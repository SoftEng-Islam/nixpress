{ config, pkgs, lib, ... }:

{
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    ensureDatabases = [ "wordpress" ];
    ensureUsers = [{
      name = "wordpressuser";
      password = "strong_password";
      privileges = { "wordpress.*" = "ALL PRIVILEGES"; };
    }];
  };
}
