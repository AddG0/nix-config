{lib, ...}: {
  # Hook for any module that wants to override the lock-screen background
  # for a single output — e.g. oled-care pinning an OLED panel to black.
  # Consumed by ../personal/hyprlock.nix when it assembles the per-monitor
  # background list. Keyed by compositor output name; values are merged
  # onto `{ monitor = <output>; }` and REPLACE the default background
  # block (so don't include `monitor` in the value).
  options.programs.hyprlock.backgroundOverrides = lib.mkOption {
    type = lib.types.attrsOf lib.types.attrs;
    default = {};
    example = lib.literalExpression ''{ "eDP-1" = { color = "rgb(0,0,0)"; }; }'';
    description = ''
      Per-output overrides for hyprlock's `background` block. Lets a
      module replace a single monitor's lock background without knowing
      what the other monitors look like.
    '';
  };

  config = {
    programs.hyprlock = {
      enable = true;
      settings.general.hide_cursor = true;
    };

    wayland.windowManager.hyprland.settings.bind = [
      "SUPER,escape,exec,pidof hyprlock || hyprlock"
    ];
  };
}
