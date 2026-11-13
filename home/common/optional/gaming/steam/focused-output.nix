# Prints "<connector> <width> <height> <refresh>" for the desktop's focused output (or GAME_OUTPUT_OVERRIDE), via Hyprland or KWin.
{
  lib,
  pkgs,
  hyprctl,
  busctl,
  kscreenDoctor,
}:
lib.getExe (pkgs.writeShellApplication {
  name = "focused-output";
  runtimeInputs = [pkgs.jq];
  text = ''
    log() { printf 'focused-output: %s\n' "$*" >&2; }

    hyprland_output() {
      local mons want
      mons=$("${hyprctl}" monitors -j) || { log "hyprctl monitors failed"; return 1; }
      want=''${GAME_OUTPUT_OVERRIDE:-}
      # The active workspace's monitor is where the window lands; .focused can disagree.
      [ -n "$want" ] || want=$("${hyprctl}" activeworkspace -j | jq -r '.monitor // empty') || want=""
      jq -er --arg n "$want" '
        (if $n == "" then map(select(.focused)) else map(select(.name == $n)) end)[0] // empty
        | "\(.name) \(.width) \(.height) \(.refreshRate | round)"' <<<"$mons" \
        || { log "output '$want' not found"; return 1; }
    }

    kwin_output() {
      local outs want
      outs=$("${kscreenDoctor}" -j) || { log "kscreen-doctor -j failed"; return 1; }
      want=''${GAME_OUTPUT_OVERRIDE:-}
      [ -n "$want" ] || want=$("${busctl}" --user --json=short call org.kde.KWin /KWin org.kde.KWin activeOutputName \
        | jq -r '.data[0] // empty') || { log "KWin activeOutputName failed"; want=""; }
      jq -er --arg n "$want" '
        (.outputs | map(select(.name == $n))[0] // empty)
        | .currentModeId as $id
        | (.modes[] | select(.id == $id)) as $m
        | "\(.name) \($m.size.width) \($m.size.height) \($m.refreshRate | round)"' <<<"$outs" \
        || { log "output '$want' not found"; return 1; }
    }

    if [[ ''${XDG_CURRENT_DESKTOP:-} == *KDE* ]]; then
      kwin_output
    else
      hyprland_output
    fi
  '';
})
