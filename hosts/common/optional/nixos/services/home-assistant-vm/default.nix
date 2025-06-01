{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  haosFile = /home/ashley/VM-Storage/haos.qcow2;
  storageDir = "${config.hostSpec.home}/VM-Storage";
in {
  virtualisation.libvirt.enable = true;
  virtualisation.libvirt.swtpm.enable = true;
  virtualisation.libvirt.connections."qemu:///system".pools = [
    {
      definition = ./MyPool.xml;
      active = true;
      restart = false;
      volumes = [];
    }
  ];

  virtualisation.libvirt.connections."qemu:///system".domains = [
    {
      definition = inputs.nixvirt.lib.domain.writeXML (
        inputs.nixvirt.lib.domain.templates.linux {
          name = "homeassistant";
          uuid = "b2c12e8a-1234-5678-9abc-def012345678"; # <----- ensure this is present
          memory = {
            count = 2;
            unit = "GiB";
          };

          storage_vol = {
            pool = "MyPool";
            volume = "haos.qcow2";
          };

          bridge_name = "virbr0";
          virtio_net = true;
          firmware = "ovmf";
          machineType = "q35";
          graphics = null;
          consoleDevices = [
            {
              type = "pty";
              target = "hvc0";
            }
          ];
          virtio_drive = true;
          virtio_video = true;
        }
      );
      active = true;
      restart = false;
    }
  ]; # services.nginx.virtualHosts."home-assistant.addg0.com" = {
  #   forceSSL = true;
  #   useACMEHost = "addg0.com";
  #   extraConfig = ''
  #     proxy_buffering off;
  #   '';
  #   locations."/" = {
  #     proxyPass = "http://[::1]:8123";
  #     proxyWebsockets = true;
  #   };
  # };
}
