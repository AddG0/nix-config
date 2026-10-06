{
  config,
  lib,
  pkgs,
  ...
}: let
  # Stylix primary accent, matching Hyprland's col.active_border.
  channel = c: lib.toInt config.lib.stylix.colors."base0D-rgb-${c}" / 255.0;
  accent = {
    red = channel "r";
    green = channel "g";
    blue = channel "b";
    alpha = 1.0;
  };
  # OmniWM 0.7.5's own encoder output: it rejects a file missing any section or hotkey id.
  defaults = lib.importTOML ./settings-defaults.toml;

  # Hyprland SUPER is Option: the key in the Windows/Super position on a Mac keyboard.
  binds =
    {
      "focus.left" = "Option+H";
      "focus.down" = "Option+J";
      "focus.up" = "Option+K";
      "focus.right" = "Option+L";
      "move.left" = "Option+Shift+H";
      "move.down" = "Option+Shift+J";
      "move.up" = "Option+Shift+K";
      "move.right" = "Option+Shift+L";

      "setContainerPrimarySpan.decrease10Percent" = "Control+Option+Shift+H";
      "setWindowSecondarySpan.increase10Percent" = "Control+Option+Shift+J";
      "setWindowSecondarySpan.decrease10Percent" = "Control+Option+Shift+K";
      "setContainerPrimarySpan.increase10Percent" = "Control+Option+Shift+L";

      "toggleFullscreen" = "Option+F";
      "toggleNativeFullscreen" = "Option+Shift+F";
      "toggleFocusedWindowFloating" = "Option+B";
      "closeFocusedWindow" = "Option+Shift+Q";

      # hy3 groups map onto niri columns.
      "consumeWindowIntoColumn" = "Option+V";
      "expelWindowFromColumn" = "Option+Shift+V";
      "toggleSplit" = "Option+S";
      "toggleColumnTabbed" = "Option+G";
      "focusWindowDownOrTop" = "Option+Quote";
      "focusWindowUpOrBottom" = "Option+Shift+Quote";

      "toggleScratchpad.1" = "Option+Y";
      "assignFocusedWindowToScratchpad.1" = "Option+Shift+Y";
      "toggleOverview" = "Option+Grave";

      "focusMonitorPrevious" = "Option+Comma";
      "focusMonitorNext" = "Option+Period";
      "moveWorkspaceToMonitor.left" = "Control+Option+H";
      "moveWorkspaceToMonitor.down" = "Control+Option+J";
      "moveWorkspaceToMonitor.up" = "Control+Option+K";
      "moveWorkspaceToMonitor.right" = "Control+Option+L";

      # OmniWM extras displaced by the binds above.
      "toggleWorkspaceLayout" = "Option+Shift+Space";
      "cycleSizeForward" = "Option+Shift+Period";
      "cycleSizeBackward" = "Option+Shift+Comma";
      "toggleQuakeTerminal" = "Option+Shift+Grave";
      "toggleContainerFullPrimarySpan" = "Unassigned";
    }
    // lib.listToAttrs (lib.concatMap (n: [
      (lib.nameValuePair "switchWorkspace.${toString (n - 1)}" "Option+${toString n}")
      (lib.nameValuePair "moveToWorkspace.${toString (n - 1)}" "Option+Shift+${toString n}")
    ]) (lib.range 1 9));

  hotkeys = map (h: h // lib.optionalAttrs (binds ? ${h.id}) {binding = binds.${h.id};}) defaults.hotkeys;

  knownIDs = map (h: h.id) defaults.hotkeys;
  unknownIDs = lib.subtractLists knownIDs (lib.attrNames binds);
  chords = lib.filter (b: b != "Unassigned") (map (h: h.binding) hotkeys);
  duplicateChords = lib.unique (lib.filter (c: lib.count (x: x == c) chords > 1) chords);
in {
  assertions = [
    (lib.hm.assertions.assertPlatform "desktops.omniwm" pkgs lib.platforms.darwin)
    {
      assertion = unknownIDs == [];
      message = "omniwm: hotkey ids not in settings-defaults.toml: ${lib.concatStringsSep ", " unknownIDs}";
    }
    {
      assertion = duplicateChords == [];
      message = "omniwm: chords bound to more than one action: ${lib.concatStringsSep ", " duplicateChords}";
    }
  ];

  programs.omniwm = {
    enable = true;
    settings = lib.recursiveUpdate defaults {
      general = {
        updateChecksEnabled = false;
        ipcEnabled = true;
      };
      # Hyprland gaps_in 4 pads each window side, so 8 between windows; gaps_out 8.
      gaps = {
        size = 8.0;
        outer = lib.genAttrs ["top" "bottom" "left" "right"] (_: 8.0);
        fullscreenUsesOuterGaps = true;
      };
      borders = {
        width = 2.0;
        color = accent;
        # Flat gradient: its ring follows the window radius; the native solid rim draws square corners.
        gradient = {
          enabled = true;
          start = accent;
          end = accent;
          direction = "topLeftToBottomRight";
        };
      };
      inherit hotkeys;
    };
  };
}
