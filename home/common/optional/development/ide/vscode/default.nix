# Debugging VS Code Extension Issues:
#   - "Help: Start Extension Bisect" - Binary search to find problematic extension
#   - "Developer: Inspect Editor Tokens and Scopes" - See what's styling an element
#   - "Extensions: Disable All Installed Extensions" - Quick isolation test
{
  lib,
  pkgs,
  config,
  hostSpec,
  ...
}: let
  # Import shared extension library
  vscodeLib = import ./lib.nix {inherit lib pkgs config hostSpec;};

  # Wrap VS Code with env vars
  hasKubeconfig = config.home.sessionVariables ? KUBECONFIG;
  wrappedVscode =
    (pkgs.symlinkJoin {
      name = "vscode-wrapped";
      paths = [pkgs.vscode];
      buildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/code \
          ${lib.optionalString hasKubeconfig ''--set KUBECONFIG "${config.home.sessionVariables.KUBECONFIG}"''}
      '';
    })
    // {
      inherit (pkgs.vscode) pname version;
      meta = pkgs.vscode.meta // {mainProgram = "code";};
    };
in
  vscodeLib.extraAttrs
  // {
    programs.vscode = {
      enable = true;
      package = wrappedVscode;
      # Must be true - some extensions (vscode-java-debug) write to their own directory
      mutableExtensionsDir = true;
      profiles = {
        default = vscodeLib.defaultProfile;
      };
    };
  }
