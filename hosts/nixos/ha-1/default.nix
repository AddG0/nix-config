{
  inputs,
  lib,
  config,
  ...
}: {
  imports = lib.flatten [
    (lib.custom.scanPaths ./.)

    #################### hardware ####################
    inputs.hardware.nixosModules.common-cpu-intel
    inputs.hardware.nixosModules.common-pc-ssd

    #################### misc inputs ####################

    (with lib.custom.optional.hosts.nixos.services; [
      home-assistant-oci
      nginx # nginx
      openssh # allow remote ssh access
    ])
  ];

  services.homeAssistantOci = {
    autoUpdate.enable = true;
    hostName = "home-assistant-1.${config.hostSpec.domain}";
  };

  networking = {
    networkmanager.enable = true;
    enableIPv6 = false;
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      timeout = 3;
    };
    # ha-1 freezes powered-on: lockups and stuck disk I/O panic into efi_pstore, then reboot.
    kernel.sysctl = {
      "kernel.panic" = 10;
      "kernel.panic_on_oops" = 1;
      "kernel.softlockup_panic" = 1;
      "kernel.hardlockup_panic" = 1;
      "kernel.hung_task_panic" = 1;
    };
    # Leaves iTCO_wdt as watchdog0; an OC-watchdog reset can stop at a BIOS prompt.
    blacklistedKernelModules = ["intel_oc_wdt"];
  };

  # A vanished NVMe errors instead of hanging, so that has to panic too.
  fileSystems."/".options = ["errors=panic"];

  # Reboots a freeze too hard to panic.
  systemd.settings.Manager.RuntimeWatchdogSec = "30s";

  hostSpec = {
    hostName = "ha-1";
    hostType = "server";
    hostPlatform = "x86_64-linux";
    colmena.enable = true;
  };

  time.timeZone = "America/Chicago";
}
