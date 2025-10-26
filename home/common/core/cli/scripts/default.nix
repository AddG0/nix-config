# TODO: add more scripts here
{
  pkgs,
  ...
}: let
  ns = pkgs.writeShellApplication {
    name = "ns";
    runtimeInputs = with pkgs; [
      nix-search-tv # Required by nixpkgs.sh
      fzf # Required by nixpkgs.sh
      gawk # Required by nixpkgs.sh
    ];
    text = builtins.readFile ./nixpkgs.sh;
  };
in {
  home.packages = [
    ns
  ];
}
