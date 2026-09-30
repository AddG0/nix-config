# modules/flake-module.nix - Custom NixOS, Darwin, and Home-manager modules, listed explicitly so importers need only a stock lib.
{
  self,
  lib,
  ...
}: let
  # For `{customPkgs, customLib, ...}: module` files; customPkgs is built from the evaluating host's own pkgs.
  importWithLocal = path: let
    withLocal = pkgs:
      import path {
        # Importers without our overlay get the set without our workarounds.
        customPkgs = pkgs.addg or (import ../pkgs/packages.nix pkgs);
        customLib = self.lib.custom;
      };
  in
    lib.setDefaultModuleLocation path (lib.setFunctionArgs
      (args: withLocal args.pkgs args)
      (lib.functionArgs (withLocal null) // {pkgs = false;}));

  common = [
    ./common/desktops.nix
    ./common/host-spec.nix
  ];
in {
  flake = {
    nixosModules.default = {
      imports =
        common
        ++ [
          ./hosts/nixos/decky-plugins.nix
          (importWithLocal ./hosts/nixos/nix/git-sync.nix)
          ./hosts/nixos/security/allow-poweroff.nix
          ./hosts/nixos/security/allow-suspend.nix
          ./hosts/nixos/semi-active-av.nix
          (importWithLocal ./hosts/nixos/services/bt-proximity.nix)
          ./hosts/nixos/services/deskflow.nix
          ./hosts/nixos/services/greetd.nix
          (importWithLocal ./hosts/nixos/services/ip-timezone.nix)
          ./hosts/nixos/services/jellyfin.nix
          ./hosts/nixos/services/k3s/kube-vip.nix
          ./hosts/nixos/services/obsbot-camera.nix
          ./hosts/nixos/services/power-state-manager
          (importWithLocal ./hosts/nixos/services/pterodactyl/panel)
          ./hosts/nixos/services/pterodactyl/wings.nix
          (importWithLocal ./hosts/nixos/services/wifiman-desktop.nix)
          ./hosts/nixos/warnings.nix
          ./hosts/nixos/yubikey.nix
        ];
    };

    darwinModules.default = {
      imports =
        common
        ++ [
          ./hosts/darwin/misc/ids.nix
          ./hosts/darwin/services/databases/mysql.nix
          ./hosts/darwin/services/monitoring/grafana.nix
          ./hosts/darwin/services/monitoring/loki.nix
          ./hosts/darwin/services/monitoring/prometheus.nix
          ./hosts/darwin/services/web-servers/nginx.nix
        ];
    };

    homeModules.default = {
      imports =
        common
        ++ [
          ./home/copyq.nix
          ./home/directory-env
          ./home/direnv/1password-direnv
          ./home/direnv/lastpass-direnv
          ./home/direnv/sops-direnv
          (importWithLocal ./home/fusion360.nix)
          ./home/gradle
          ./home/jetbrains
          ./home/lnav.nix
          ./home/monitors.nix
          (importWithLocal ./home/nixos/rlbot.nix)
          ./home/nixos/services/gpu-screen-recorder.nix
          ./home/nixos/services/hass-agent.nix
          ./home/prismlauncher
          (importWithLocal ./home/programs/claude-code)
          (importWithLocal ./home/programs/code-assistant-profiles)
          ./home/programs/codex
          ./home/programs/t3code-theme
          ./home/services/playerctl-rules
          ./home/services/rclone-mount.nix
        ];
    };

    homeModules.plasma6 = {
      imports = [
        (importWithLocal ./home/nixos/desktops/plasma6/kwin.nix)
        ./home/nixos/desktops/plasma6/workspace/cursors.nix
        ./home/nixos/desktops/plasma6/workspace/icons.nix
        (importWithLocal ./home/nixos/desktops/plasma6/workspace/splash-screens.nix)
        (importWithLocal ./home/nixos/desktops/plasma6/workspace/themes/sweet.nix)
        ./home/nixos/desktops/plasma6/workspace/themes/whitesur.nix
      ];
    };
  };
}
