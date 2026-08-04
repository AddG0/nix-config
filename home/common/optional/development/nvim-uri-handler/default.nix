{
  config,
  lib,
  pkgs,
  ...
}: let
  nvim-uri-handler = pkgs.writeShellApplication {
    name = "nvim-uri-handler";
    runtimeInputs = [
      # Launched by the desktop file, not a login shell, so nvim can't come from PATH.
      config.programs.nixvim.build.package
      pkgs.ghostty
      pkgs.libnotify
      pkgs.jq
      pkgs.procps
      pkgs.coreutils
    ];
    text = builtins.readFile ./nvim-uri-handler.sh;
  };
in
  lib.mkIf (pkgs.stdenv.isLinux && config.hostSpec.hostType != "server") {
    home.packages = [nvim-uri-handler];

    # nvim://file/{path}:{line}:{column} — paste as DevTools' "Open in Editor URL".
    xdg.desktopEntries.nvim-uri-handler = {
      name = "Open in Neovim";
      genericName = "Text Editor";
      comment = "Jump to a file:line:column from browser devtools";
      exec = "${nvim-uri-handler}/bin/nvim-uri-handler %u";
      terminal = false;
      noDisplay = true;
      icon = "nvim";
      categories = ["Development"];
      mimeType = ["x-scheme-handler/nvim"];
    };

    xdg.mimeApps.defaultApplications."x-scheme-handler/nvim" = ["nvim-uri-handler.desktop"];
  }
