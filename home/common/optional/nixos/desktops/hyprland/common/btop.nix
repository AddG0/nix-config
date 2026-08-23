{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.hyprland.btop;

  # Own app-id so the windowrules below can't catch a regular ghostty window.
  appId = "dev.addg.btop";

  toggle = pkgs.writeShellApplication {
    name = "hypr-btop-toggle";
    runtimeInputs = [pkgs.hyprland pkgs.jq pkgs.coreutils];
    text = ''
      appId=${lib.escapeShellArg appId}

      addr=$(
        hyprctl clients -j \
          | jq -r --arg c "$appId" 'first(.[] | select(.class == $c) | .address) // ""'
      )

      if [ -n "$addr" ]; then
        hyprctl dispatch closewindow "address:$addr"
        exit 0
      fi

      # 80x24 is btop's floor; in cells it holds at any font size and gives the
      # clamp below its baseline. confirm-close-surface off: btop counts as a
      # running process, so `closewindow` would only pop a dialog.
      setsid ${lib.getExe pkgs.ghostty} \
        --class="$appId" \
        --title=btop \
        --confirm-close-surface=false \
        --window-width=80 \
        --window-height=24 \
        -e ${config.programs.btop.package}/bin/btop &

      # Ghostty commits its own cell-derived size just after map, clobbering a
      # `size` windowrule — so sizing has to wait for the window. Hyprland
      # resizes around the center point, so `center 1` still holds afterwards.
      floor=""
      for _ in $(seq 1 60); do
        floor=$(
          hyprctl clients -j \
            | jq -r --arg c "$appId" \
                'first(.[] | select(.class == $c) | [.address, .size[0], .size[1]] | @tsv) // ""'
        )
        [ -n "$floor" ] && break
        sleep 0.05
      done

      if [ -z "$floor" ]; then
        echo "hypr-btop-toggle: no $appId window appeared within 3s" >&2
        exit 1
      fi
      IFS=$'\t' read -r addr minWidth minHeight <<<"$floor"

      hyprctl dispatch resizewindowpixel "exact ${cfg.size},address:$addr"

      # A percentage of a small screen can land under btop's floor.
      sized=$(
        hyprctl clients -j \
          | jq -r --arg a "$addr" \
              'first(.[] | select(.address == $a) | [.size[0], .size[1]] | @tsv) // ""'
      )
      [ -n "$sized" ] || exit 0
      IFS=$'\t' read -r width height <<<"$sized"

      if [ "$width" -lt "$minWidth" ] || [ "$height" -lt "$minHeight" ]; then
        hyprctl dispatch resizewindowpixel \
          "exact $((width > minWidth ? width : minWidth)) $((height > minHeight ? height : minHeight)),address:$addr"
      fi
    '';
  };
in {
  options.modules.hyprland.btop = {
    toggleKey = lib.mkOption {
      type = lib.types.str;
      default = "SUPERSHIFT,t";
      example = "CTRL_SHIFT,escape";
      description = ''
        Hyprland bind prefix for the floating btop toggle. Format: "MODS,KEY".
      '';
    };

    size = lib.mkOption {
      type = lib.types.str;
      default = "65% 70%";
      description = ''
        Window size, in `resizewindowpixel exact` syntax (pixels or percentages
        of the monitor). Clamped up to btop's 80x24 minimum.
      '';
    };

    toggleCommand = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = ''
        Command that toggles the floating btop, for bar widgets that want to
        trigger the same action as `toggleKey`.
      '';
    };
  };

  config = {
    modules.hyprland.btop.toggleCommand = lib.getExe toggle;

    wayland.windowManager.hyprland.settings = {
      windowrule = [
        "float on, match:class ^(${lib.escapeRegex appId})$"
        "center 1, match:class ^(${lib.escapeRegex appId})$"
      ];

      bind = ["${cfg.toggleKey},exec,${cfg.toggleCommand}"];
    };
  };
}
