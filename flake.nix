{ pkgs ? import <nixpkgs> { } }:
let
  phpEnv = pkgs.php.buildEnv {
    extensions = { enabled, all }: enabled ++ (with all; [ xsl ]);
    extraConfig = "memory_limit=-1";
  };
in pkgs.mkShell {
  buildInputs = with pkgs; [ phpEnv phpEnv.packages.composer symfony-cli ];
}
