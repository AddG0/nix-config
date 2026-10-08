# Hotkeys for commands; window-manager actions stay in the OmniWM module's own binds.
# Denied the Ghostty Automation prompt? `tccutil reset AppleEvents` (resets every app) makes macOS ask again.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.skhd;
  label = "local.skhd";
  agent = pkgs.writeText "${label}.plist" (lib.generators.toPlist {escape = true;} {
    Label = label;
    ProgramArguments = [(lib.getExe cfg.package) "-c" "${config.xdg.configFile."skhd/skhdrc".source}"];
    RunAtLoad = true;
    KeepAlive = true;
    ProcessType = "Interactive";
    LimitLoadToSessionType = "Aqua";
    StandardOutPath = cfg.outLogFile;
    StandardErrorPath = cfg.errorLogFile;
  });
in {
  assertions = [(lib.hm.assertions.assertPlatform "desktops.macos.skhd" pkgs lib.platforms.darwin)];

  services.skhd = {
    enable = true;
    config = ''
      alt - return : /usr/bin/osascript -e 'tell application "Ghostty"' -e 'new window' -e 'activate' -e 'end tell'
    '';
  };

  # Upstream's agent bootstraps without the headless guard; see lib.custom.darwinGuiAgentActivation.
  launchd.agents.skhd.enable = lib.mkForce false;
  home.activation.skhd = lib.hm.dag.entryAfter ["linkGeneration"] (lib.custom.darwinGuiAgentActivation {
    inherit label;
    plist = agent;
  });
}
