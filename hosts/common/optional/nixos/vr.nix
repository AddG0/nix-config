# Native Linux VR via Monado for the Bigscreen Beyond on NVIDIA.
#
# Per real user reports (r/BigscreenBeyond), SteamVR-for-Linux stutters
# badly on NVIDIA and has trouble routing the Beyond's display. Monado
# uses a different pipeline (DRM lease on the Beyond's DP output for
# rendering, SteamVR's lighthouse driver borrowed for tracking the
# Beyond's internal Tundra-Labs sensor) and is the recommended NVIDIA
# path.
#
# Refs:
#   - https://www.reddit.com/r/BigscreenBeyond/comments/1qalysc/another_linux_thread/
#   - https://wiki.vronlinux.org/docs/hardware/bigscreen-beyond/
#   - https://wiki.nixos.org/wiki/VR
{
  config,
  pkgs,
  ...
}: let
  launcher = "/home/${config.hostSpec.username}/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrcompositor-launcher";
in {
  services.monado = {
    enable = true;
    defaultRuntime = true; # writes /etc/xdg/openxr/1/active_runtime.json
    highPriority = true; # SCHED_RR on the compositor — required for stable framepacing
  };

  systemd.user.services.monado.environment = {
    # Use SteamVR's lighthouse driver. The Beyond's internal tracking is
    # a Tundra Labs lighthouse-2 module; SteamVR's driver knows how to
    # talk to it. libsurvive (Monado's built-in fallback) does not.
    STEAMVR_LH_ENABLE = "1";

    # Compute-pipeline compositor — better on NVIDIA than the default
    # rasterization pipeline.
    XRT_COMPOSITOR_COMPUTE = "1";

    # Fixes Monado stuttering on NVIDIA per r/BigscreenBeyond community.
    XRT_COMPOSITOR_USE_PRESENT_WAIT = "1";
    U_PACING_COMP_TIME_FRACTION_PERCENT = "90";
  };

  # Pressure-vessel (Steam's bubblewrap sandbox) hides host OpenXR
  # runtime registration by default. Without this, VR/XR games inside
  # Steam can't find Monado.
  environment.sessionVariables.PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES = "1";

  # Bigscreen Beyond / Beyond 2 hidraw access. hardware.steam-hardware
  # (enabled transitively by programs.steam) only covers Valve/HTC PIDs,
  # so vendor 35bd needs its own rules.
  # PIDs: 0101 = Beyond, 0202/0105/4004 = Beyond 2 variants / dock / Utility.
  services.udev.extraRules = ''
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="0101", TAG+="uaccess", MODE="0660"
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="0202", TAG+="uaccess", MODE="0660"
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="0105", TAG+="uaccess", MODE="0660"
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="4004", TAG+="uaccess", MODE="0660"
  '';

  # SteamVR's first-run prompt for elevated permissions tries to setcap
  # CAP_SYS_NICE on vrcompositor-launcher via pkexec from inside Steam's
  # pressure-vessel sandbox. That silently fails on NixOS, so the prompt
  # never resolves. Pre-apply the capability ourselves; the path unit
  # re-fires when SteamVR is uninstalled-and-reinstalled (Steam's update
  # path is delete-then-write). Relevant even on the Monado path because
  # Monado loads SteamVR's lighthouse driver via STEAMVR_LH_ENABLE=1.
  #
  # PathChanged is intentionally NOT used: setcap modifies the file's
  # xattrs, which trips inotify's IN_ATTRIB, which would re-fire the
  # service in a loop until start-limit-hit.
  systemd.paths.steamvr-setcap = {
    description = "Watch SteamVR vrcompositor-launcher for capability application";
    pathConfig = {
      PathExists = launcher;
      Unit = "steamvr-setcap.service";
    };
    wantedBy = ["multi-user.target"];
  };

  systemd.services.steamvr-setcap = {
    description = "Apply CAP_SYS_NICE to SteamVR vrcompositor-launcher";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.libcap}/bin/setcap cap_sys_nice+ep ${launcher}";
    };
  };
}
