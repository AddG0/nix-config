# Debugging VS Code Extension Issues:
#   - "Help: Start Extension Bisect" - Binary search to find problematic extension
#   - "Developer: Inspect Editor Tokens and Scopes" - See what's styling an element
#   - "Extensions: Disable All Installed Extensions" - Quick isolation test
#
# Keyring fix (Hyprland/non-standard DEs):
#   Chromium doesn't detect gnome-keyring on Hyprland (upstream bug: github.com/microsoft/vscode/issues/187338).
#   Applied below via --password-store=gnome-libsecret wrapper flag.
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
          ${lib.optionalString hasKubeconfig ''--set KUBECONFIG "${config.home.sessionVariables.KUBECONFIG}"''} \
          ${lib.optionalString pkgs.stdenv.isLinux "--add-flags --password-store=gnome-libsecret"}
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
        default =
          vscodeLib.defaultProfile
          // {
            userSettings = vscodeLib.mkSettingsJson "vscode-user-settings" vscodeLib.defaultProfile.userSettings;
          };
      };
    };
  }
