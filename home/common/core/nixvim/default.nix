{
  inputs,
  lib,
  config,
  pkgs,
  self,
  osConfig ? null,
  ...
}: let
  textEditorDesktop = "nvim-ghostty.desktop";
  textTypes = [
    "text/plain"
    "text/markdown"
    "application/json"
    "application/yaml"
    "application/toml"
    "application/xml"
    "text/xml"
    "text/x-shellscript"
  ];
in {
  imports = [inputs.nixvim.homeModules.nixvim];

  # The nvim config itself is a set of prefix-less nixvim modules (core.nix +
  # siblings), shared verbatim with the standalone `packages.nvim` build that
  # feeds the same modules to `evalNixvim`. Here they're imported under the
  # `programs.nixvim` submodule; _module.args supplies the host/stylix context
  # they need (the standalone build passes its own equivalents).
  programs.nixvim = {
    enable = true;
    imports = lib.custom.scanPaths ./.;
    # Use the host's (overlaid, allowUnfree) pkgs instead of nixvim's own
    # instance, so custom packages like kotlin-lsp resolve in the submodule.
    nixpkgs.useGlobalPackages = true;
    _module.args = {
      # nixvim auto-provides `nixvimLib` (host lib + nixvim overlay, with our
      # lib.custom) to submodule modules; that's what they use for lib.custom.
      inherit self osConfig;
      colors = config.lib.stylix.colors.withHashtag;
      fonts = config.stylix.fonts;
      sshSettings = config.programs.ssh.settings or {};
    };
  };

  # The GitHub Global/Vim gitignore template ships an over-broad swap-file
  # glob `[._]s[a-rt-v][a-z]` that also matches `.sdd` (our spec-driven-
  # development folder), silently untracking the whole directory. The other
  # swap patterns in the template already cover real vim swap files, so
  # filtering this one out loses no coverage.
  programs.git.ignores =
    lib.filter (line: line != "[._]s[a-rt-v][a-z]")
    (lib.custom.gitignoreFromTemplates inputs.github-gitignore-templates ["Global/Vim"])
    ++ [
      "kls_database.db" # Created by the kls
    ];

  home.shellAliases = {
    vim = "nvim";
    v = "nvim";
    vi = "nvim";
  };

  # Personal cspell words shared across every repo — cspell auto-loads this
  # global config from the configstore path. Repo-specific words still go in a
  # cspell.json at that repo's root.
  xdg.configFile."configstore/cspell.json".text = builtins.toJSON {
    version = "0.2";
    words = [
      "getenv"
      "healthcheck"
      "herdr"
      "keybind"
      "keybinds"
      "worktree"
    ];
  };

  xdg.desktopEntries.nvim-ghostty = lib.mkIf (pkgs.stdenv.isLinux && config.hostSpec.hostType != "server") {
    name = "Neovim in Ghostty";
    genericName = "Text Editor";
    comment = "Edit text and config files in Neovim";
    exec = "${pkgs.ghostty}/bin/ghostty -e ${config.programs.nixvim.build.package}/bin/nvim %F";
    terminal = false;
    noDisplay = true;
    icon = "nvim";
    categories = [
      "Utility"
      "TextEditor"
    ];
    mimeType = textTypes;
  };

  xdg.mimeApps.defaultApplications =
    lib.mkIf (pkgs.stdenv.isLinux && config.hostSpec.hostType != "server")
    (lib.genAttrs textTypes (_: [textEditorDesktop]));
}
