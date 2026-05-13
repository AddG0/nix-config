{
  # keyd remaps keys at the evdev layer (below the compositor), so the mapping
  # applies uniformly to Wayland, X11, XWayland, TTYs, and apps that read raw
  # scancodes (e.g. Minecraft / LWJGL) — which the Hyprland xkb `caps:escape`
  # option does not reach.
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = ["*"];
      settings.main.capslock = "esc";
    };
  };
}
