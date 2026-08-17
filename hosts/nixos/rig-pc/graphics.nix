{
  inputs,
  config,
  ...
}: {
  imports = [
    "${inputs.hardware}/common/gpu/nvidia/ada-lovelace"
  ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true; # 32-bit Proton titles need the i686 GL/Vulkan stack
  };

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # The 7900X's Raphael iGPU is a second DRM card the session's gamescope can pick
  # over the 4080; no display is wired to it.
  boot.kernelParams = ["module_blacklist=amdgpu,amdxcp,snd_hda_codec_atihdmi"];
}
