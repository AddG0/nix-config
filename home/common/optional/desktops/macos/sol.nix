{
  config,
  lib,
  pkgs,
  customPkgs,
  ...
}: let
  label = "local.sol";
  configFile = "${config.xdg.configHome}/sol/config.json";

  # Merged into config.json, which Sol also writes its own state to. Any key here also marks onboarding done.
  settings = {
    globalShortcut = "command";
    launchAtLogin = false;
  };

  agent = pkgs.writeText "${label}.plist" (lib.generators.toPlist {escape = true;} {
    Label = label;
    ProgramArguments = ["/usr/bin/open" "-a" "${config.home.homeDirectory}/${config.targets.darwin.copyApps.directory}/Sol.app"];
    RunAtLoad = true;
    LimitLoadToSessionType = "Aqua";
  });
in {
  assertions = [(lib.hm.assertions.assertPlatform "desktops.macos.sol" pkgs lib.platforms.darwin)];

  home.packages = [customPkgs.sol];

  # Nix owns updates; Sparkle can't replace a copied store app.
  targets.darwin.defaults."com.ospfranco.sol".SUEnableAutomaticChecks = false;

  # Sol rewrites config.json from memory, so it is stopped before the merge and the agent restarts it.
  home.activation.solConfig = lib.hm.dag.entryAfter ["linkGeneration"] ''
    (
      current='{}'
      if [ -s ${lib.escapeShellArg configFile} ]; then current=$(cat ${lib.escapeShellArg configFile}); fi
      merged=$(${lib.getExe pkgs.jq} -S --argjson s ${lib.escapeShellArg (builtins.toJSON settings)} '. * $s' <<<"$current") \
        || { echo "sol: invalid JSON in ${configFile}" >&2; exit 1; }
      if [ "$merged" != "$(${lib.getExe pkgs.jq} -S . <<<"$current")" ]; then
        if /usr/bin/pgrep -xq sol; then
          run /usr/bin/pkill -x sol
          for _ in $(seq 50); do /usr/bin/pgrep -xq sol || break; sleep 0.1; done
          if /usr/bin/pgrep -xq sol; then echo "sol: still running after 5s, not touching ${configFile}" >&2; exit 1; fi
        fi
        tmp=$(mktemp)
        printf '%s\n' "$merged" >"$tmp"
        run install -Dm644 -T "$tmp" ${lib.escapeShellArg configFile}
        rm -f "$tmp"
      fi
    )
  '';

  # -dict-add, not targets.darwin.defaults: import would replace the whole AppleSymbolicHotKeys dict.
  home.activation.freeSpotlightHotkey = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run /usr/bin/defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 \
      '<dict><key>enabled</key><false/><key>value</key><dict><key>parameters</key><array><integer>32</integer><integer>49</integer><integer>1048576</integer></array><key>type</key><string>standard</string></dict></dict>'
    run /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  '';

  home.activation.sol = lib.hm.dag.entryAfter ["solConfig" "setDarwinDefaults" "freeSpotlightHotkey"] (lib.custom.darwinGuiAgentActivation {
    inherit label;
    plist = agent;
    rerunOnSwitch = true;
  });
}
