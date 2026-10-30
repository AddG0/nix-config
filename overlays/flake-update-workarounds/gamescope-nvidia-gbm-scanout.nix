# gamescope's DRM backend allocates its scan-out buffers through Vulkan, which
# NVIDIA's driver garbles: Steam's gaming UI shows artifacts, displaced strips and
# wrong colours (open upstream: github.com/ValveSoftware/gamescope/issues/2309,
# #2455). farnoy's nvidia-gbm-wayland commits allocate them through GBM instead;
# this is that diff against 3.16.31, as kept by steamify-gamescope-nvidia. It is
# inert unless gamescope runs with gamescope_drm_gbm_scanout=1 (rig-pc sets it).
# Fixed once a gamescope release scans out cleanly on NVIDIA without it.
# CHECK-RUNTIME: on rig-pc, drop gamescope_drm_gbm_scanout from the session's
# extraEnv and this overlay; upstream is fixed when Steam's Gaming Mode UI shows
# no artifacts after a reboot.
_: final: prev: {
  gamescope = prev.gamescope.overrideAttrs (old: {
    patches =
      (old.patches or [])
      ++ [
        (final.fetchurl {
          url = "https://raw.githubusercontent.com/theupriser/steamify-gamescope-nvidia/c694e8e1bdd99cc1e9601c1ccbc371e839777d9b/gamescope-gbm-scanout.patch";
          hash = "sha256-qz7Gnln7owJLWkY+2zF+KOdxvKBfrs5VI6IoQ90JCRc=";
        })
      ];
  });
}
