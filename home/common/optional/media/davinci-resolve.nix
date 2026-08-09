# during activation, for some reason it only uses the wifi link, so even being connected to ethernet will fail to validate the key
{pkgs, ...}: let
  # DaVinci Resolve's bundled Qt lacks Wayland support, force XWayland
  davinci = pkgs.symlinkJoin {
    name = "davinci-resolve-studio";
    paths = [pkgs.unstable.davinci-resolve-studio];
    buildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/davinci-resolve-studio \
        --set QT_QPA_PLATFORM xcb
    '';
  };
in {
  home.packages = [davinci];

  # No frame callbacks on inactive workspaces stalls Resolve's loop mid-render.
  wayland.windowManager.hyprland.settings.windowrule = [
    "render_unfocused on, match:class ^(resolve)$"
  ];
}
