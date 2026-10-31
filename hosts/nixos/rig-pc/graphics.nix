{
  inputs,
  config,
  ...
}: let
  nvidia = config.boot.kernelPackages.nvidiaPackages.latest;
in {
  imports = [
    "${inputs.hardware}/common/gpu/nvidia/ada-lovelace"
  ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true; # 32-bit Proton titles need the i686 GL/Vulkan stack
  };

  hardware.nvidia = {
    # FLAKE-UPDATE: drop the patch once NVIDIA/open-gpu-kernel-modules#1305 ships in the pinned driver;
    # without it RMDisableNoncontigAlloc is ignored on PMA-managed VRAM, i.e. on every modern GPU.
    package =
      nvidia
      // {
        open = nvidia.open.overrideAttrs (old: {
          patches = (old.patches or []) ++ [./nvidia-pma-noncontig.patch];
        });
      };
  };

  boot = {
    # The 7900X's Raphael iGPU is a second DRM card the session's gamescope can pick
    # over the 4080; no display is wired to it.
    kernelParams = ["module_blacklist=amdgpu,amdxcp,snd_hda_codec_atihdmi"];
    # NVIDIA can't scan out scattered VRAM, garbling gamescope at 5120x1440 HDR (gamescope#1593); as Bazzite does.
    extraModprobeConfig = "options nvidia NVreg_RegistryDwords=RMDisableNoncontigAlloc=1";
  };
}
