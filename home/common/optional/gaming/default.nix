{
  pkgs,
  lib,
  ...
}: let
  # Our Steam Protons (GE-Proton, proton-cachyos) live in the Nix store, and a
  # prefix symlinks its core files into that store path. On a proton update the
  # old path orphans and min-free GC reaps it → the prefix's symlinks dangle.
  # Proton won't rebuild it because every Proton 11.x reports the same prefix
  # version "11.0-100", so the game just crashes on launch.
  pruneBrokenPrefixes = pkgs.writeShellApplication {
    name = "steam-prune-broken-prefixes";
    runtimeInputs = with pkgs; [coreutils procps];
    text = ''
      compatdata="$HOME/.local/share/Steam/steamapps/compatdata"
      [ -d "$compatdata" ] || exit 0

      if pgrep -x steam >/dev/null; then
        echo "Steam is running; skipping prefix prune."
        exit 0
      fi

      shopt -s nullglob
      for dir in "$compatdata"/*/; do
        exe="$dir/pfx/drive_c/windows/system32/steam.exe"
        # Only a dangling symlink is broken; real files and live links are fine.
        if [ -L "$exe" ] && [ ! -e "$exe" ]; then
          echo "Resetting broken Proton prefix (GC'd store path): $(basename "$dir")"
          rm -rf "$dir"
        fi
      done
    '';
  };
in {
  imports = [
    ./steam
    ./sens-convert.nix
  ];

  home.packages = with pkgs; [
    mangohud
  ];

  systemd.user.services.steam-prune-broken-prefixes = {
    Unit.Description = "Reset Proton prefixes whose GC'd Nix-store symlinks dangle";
    Service = {
      Type = "oneshot";
      ExecStart = "${pruneBrokenPrefixes}/bin/steam-prune-broken-prefixes";
    };
    Install.WantedBy = ["default.target"];
  };

  # Forza Horizon's XWayland fullscreen-on-map path crashes Hyprland 0.54.3
  # inside CCompositor::setWindowFullscreenInternal (null deref on the
  # surface-recycling that happens during X11 Activate). Suppress the
  # fullscreen request — the game still renders fine windowed-borderless.
  # mkBefore so `tag +game` sorts ahead of the tag:game consumers in other
  # modules (e.g. the opacity rule in visuals) — Hyprland applies rules in order.
  wayland.windowManager.hyprland.settings.windowrule = lib.mkBefore [
    "suppress_event fullscreen, match:title ^(Forza Horizon \\d+)$"
    "suppress_event fullscreen, match:class ^(steam_app_2483190)$"
    # Scrap Mechanic maps its X11 window as a dialog, so Hyprland auto-floats it tiny.
    "float off, match:class ^(steam_app_387990)$"
    # gamescope's render loop runs off Wayland frame callbacks, which Hyprland
    # stops sending to windows on an inactive workspace — so the game freezes on
    # return until a resize kicks it.
    "render_unfocused on, match:class ^(gamescope)$"
    # Steam games (Proton or native) map as XWayland class steam_app_<id>.
    "tag +game, match:class ^(steam_app_\\d+)$"
    # Gamescoped ones don't: they map on gamescope's Xwayland, not Hyprland's.
    "tag +game, match:class ^(gamescope)$"
  ];

  # Disable the desktop entry for Protontricks since steam gives me that option anyway
  #
  # Written to $XDG_DATA_HOME directly (not via xdg.desktopEntries) because
  # walker's elephant backend dedupes .desktop files by basename and scans
  # $XDG_DATA_HOME before $XDG_DATA_DIRS — so a file here masks the system
  # entry; one in the HM profile share dir doesn't reliably win.
  xdg.dataFile."applications/protontricks.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Protontricks
    NoDisplay=true
  '';
}
