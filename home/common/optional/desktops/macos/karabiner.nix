# Linux-style Ctrl app shortcuts through Karabiner-Elements (installed as a cask on the host); see ADR 0004.
{
  config,
  lib,
  pkgs,
  ...
}: let
  configFile = "${config.xdg.configHome}/karabiner/karabiner.json";

  upstream = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/rux616/karabiner-windows-mode/289c4d5444b03347e4d99d75a9f0b99f0ce42fca/json/windows_shortcuts.json";
    hash = "sha256-afrUZ6FBc0T9pN6MUefc/SGe22kvL8j/5HrJQWAC9b8=";
  };

  # Upstream assumes a PC keyboard (Alt = Option, Win = Command); here Option is Super and Command sits where Alt does.
  drop =
    [
      # F1/F3 are brightness-down and Mission Control here; the rules matched them before the media mapping.
      "F1"
      "F3"
      "Insert (Ctrl)"
      "Insert (Shift)"
      "Space (Ctrl)"
      "Tab (Alt) [+IDEs, Remote Desktops, and Terminal Emulators]"
      "Win [Open Spotlight] [Always]"
      "L (Win) [Lock Screen] [Always]"
      "L (Win) [Sleep] [Always]"
      "L (Alt+Ctrl) [Lock Screen] [Always]"
      "L (Alt+Ctrl) [Sleep] [Always]"
    ]
    ++ map (n: "${toString n} (Cmd) [Open ${lib.elemAt ["first" "second" "third" "fourth" "fifth" "sixth" "seventh" "eighth" "ninth"] (n - 1)} pinned Dock app${lib.optionalString (n == 1) " (Finder)"}; +IDEs and Terminal Emulators]") (lib.range 1 9);
  altF4 = "F4 (Alt) [+Terminal Emulators]";
  # Upstream lets any modifier ride along, so Ctrl+Cmd+Shift+H/L (OmniWM resize) would become Cmd+Y/L in browsers.
  shiftOnly = ["H (Ctrl) [Only Web Browsers]" "L (Ctrl) [Only Web Browsers]"];
  zen = "^app\\.zen-browser\\.zen$";

  # Karabiner grabs keyboards past System Settings' per-device modifier swaps; this one makes the Win key Option (Super).
  pcKeyboards = [
    {
      name = "Mode 75S";
      vendor_id = 222;
      product_id = 30083;
    }
  ];
  swap = a: b: {
    from.key_code = a;
    to = [{key_code = b;}];
  };
  devices =
    map (k: {
      identifiers = {
        is_keyboard = true;
        inherit (k) vendor_id product_id;
      };
      simple_modifications = [
        (swap "left_command" "left_option")
        (swap "left_option" "left_command")
        (swap "right_command" "right_option")
        (swap "right_option" "right_command")
      ];
    })
    pcKeyboards;
  # nix-darwin's remapCapsLockToEscape is a hidutil mapping, which Karabiner's grab bypasses.
  capsToEscape = swap "caps_lock" "escape";

  rules = pkgs.runCommand "karabiner-linux-rules.json" {nativeBuildInputs = [pkgs.jq];} ''
    jq --argjson drop ${lib.escapeShellArg (builtins.toJSON drop)} \
       --arg altF4 ${lib.escapeShellArg altF4} --arg zen ${lib.escapeShellArg zen} \
       --argjson shiftOnly ${lib.escapeShellArg (builtins.toJSON shiftOnly)} '
      [.rules[].description] as $have
      | ($drop + [$altF4] + $shiftOnly | map(select(. as $d | $have | index($d) | not))) as $missing
      | if $missing != [] then error("karabiner-windows-mode no longer has: \($missing)") else . end
      | .rules
      | map(select(.description as $d | $drop | index($d) | not))
      | map(if .description as $d | $shiftOnly | index($d) then .manipulators[].from.modifiers.optional = ["shift"] else . end)
      | map(if .description == $altF4 then
          .description = "F4 (Cmd, Alt position) [+Terminal Emulators]"
          | .manipulators[].from.modifiers.mandatory = ["command"]
        else . end)
      | map(.manipulators[].conditions[]? |= (
          if .type == "frontmost_application_if" and ((.bundle_identifiers // []) | index("^com\\.apple\\.Safari$"))
          then .bundle_identifiers += [$zen] else . end))
      | if any(.[].manipulators[].conditions[]?; (.bundle_identifiers // []) | index($zen)) then .
        else error("karabiner-windows-mode has no browser rule keyed on Safari to add Zen to") end
    ' ${upstream} >$out
  '';
in {
  assertions = [(lib.hm.assertions.assertPlatform "desktops.macos.karabiner" pkgs lib.platforms.darwin)];

  # Mission Control's Ctrl(+Shift)+arrow Space switching eats word jumps before terminals see them.
  home.activation.freeCtrlArrowHotkeys = lib.hm.dag.entryAfter ["writeBoundary"] ''
    for id in 79 80 81 82; do
      run /usr/bin/defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$id" '<dict><key>enabled</key><false/></dict>'
    done
    run /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  '';

  # Not a symlink: Karabiner writes its own settings into the same file, so only the rule list is replaced.
  home.activation.karabinerRules = lib.hm.dag.entryAfter ["writeBoundary"] ''
    (
      current='{}'
      if [ -s ${lib.escapeShellArg configFile} ]; then current=$(cat ${lib.escapeShellArg configFile}); fi
      merged=$(${lib.getExe pkgs.jq} -S --slurpfile r ${rules} --argjson devs ${lib.escapeShellArg (builtins.toJSON devices)} \
        --argjson caps ${lib.escapeShellArg (builtins.toJSON capsToEscape)} '
        def id: .identifiers | {is_keyboard, vendor_id, product_id};
        if (.profiles // []) == [] then .profiles = [{name: "Default profile", selected: true}] else . end
        | if any(.profiles[]; .selected) then . else .profiles[0].selected = true end
        | (.profiles[] | select(.selected) | .complex_modifications.rules) = $r[0]
        | (.profiles[] | select(.selected) | .simple_modifications) |= ([.[]? | select(.from.key_code != "caps_lock")] + [$caps])
        | (.profiles[] | select(.selected) | .devices) |=([.[]? | select(id as $i | $devs | map(id) | index($i) | not)] + $devs)
      ' <<<"$current") && [ -n "$merged" ] || { echo "karabiner: invalid JSON in ${configFile}" >&2; exit 1; }
      if [ "$merged" != "$(${lib.getExe pkgs.jq} -S . <<<"$current")" ]; then
        tmp=$(mktemp)
        printf '%s\n' "$merged" >"$tmp"
        run install -Dm644 -T "$tmp" ${lib.escapeShellArg configFile}
        rm -f "$tmp"
      fi
    )
  '';
}
