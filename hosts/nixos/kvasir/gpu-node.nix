# Offers the 2080 Ti to asgard: CDI devices for generic-cdi-plugin to advertise.
{
  hardware.nvidia-container-toolkit = {
    enable = true;
    mount-nvidia-executables = true;
  };

  # generic-cdi-plugin's DaemonSet selects on this.
  services.k3s.nodeLabel = ["nixos-nvidia-cdi=enabled"];

  # 6 cores and 16 GiB: only pods that tolerate this land here.
  services.k3s.nodeTaint = ["dedicated=kvasir:NoSchedule"];
}
