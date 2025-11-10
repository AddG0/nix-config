# https://github.com/sharkdp/bat
# https://github.com/eth-p/bat-extras
{
  pkgs,
  lib,
  nur-ryan4yin,
  ...
}: {
  programs.bat = {
    enable = true;
    config = {
      # Show line numbers, Git modifications and file header (but no grid)
      style = "numbers,changes,header";
      theme = lib.mkDefault "catppuccin-mocha";
    };
    extraPackages = [
      pkgs.bat-extras.batdiff # Diff a file against the current git index, or display the diff between to files
      pkgs.bat-extras.batman # read manpages using bat as the formatter
      pkgs.stable.bat-extras.batgrep # search through and highlight files using ripgrep
    ];
    themes = {
      # https://raw.githubusercontent.com/catppuccin/bat/main/Catppuccin-mocha.tmTheme
      catppuccin-mocha = {
        src = nur-ryan4yin.packages.${pkgs.stdenv.hostPlatform.system}.catppuccin-bat;
        file = "Catppuccin-mocha.tmTheme";
      };
    };
  };
}
