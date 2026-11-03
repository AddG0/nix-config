# Secure Boot through Microsoft-signed shim for firmware that won't enter Setup Mode; see docs/guides/secure-boot-tpm.md.
{
  config,
  lib,
  pkgs,
  customPkgs,
  ...
}: let
  esp = config.boot.loader.efi.efiSysMountPoint;
  systemdBoot = "${esp}/EFI/systemd/systemd-bootx64.efi";
  label = "NixOS (shim)";

  sync = pkgs.writeShellApplication {
    name = "secureboot-shim-sync";
    runtimeInputs = with pkgs; [coreutils diffutils efibootmgr gnugrep gnused util-linux];
    text = ''
      exec 9>/run/secureboot-shim.lock
      flock 9

      dir=${esp}/EFI/shim
      mkdir -p "$dir"

      put() {
        if ! cmp -s "$1" "$dir/$2"; then
          cp "$1" "$dir/$2.new"
          sync "$dir/$2.new"
          mv "$dir/$2.new" "$dir/$2"
          echo "secureboot-shim: installed $2"
        fi
      }
      put ${customPkgs.shim-signed}/share/shim/shimx64.efi shimx64.efi
      put ${customPkgs.shim-signed}/share/shim/mmx64.efi mmx64.efi
      # shim starts its second stage by this name.
      put ${systemdBoot} grubx64.efi

      part=$(findmnt -no SOURCE ${esp})
      partuuid=$(lsblk -no PARTUUID "$part")
      disk=/dev/$(lsblk -no PKNAME "$part")
      partnum=$(cat "/sys/class/block/$(basename "$part")/partition")

      find_entry() {
        efibootmgr -v \
          | { grep -iF "$partuuid" || true; } \
          | { grep -iF 'EFI\shim\shimx64.efi' || true; } \
          | sed -nE 's/^Boot([0-9A-F]{4}).*/\1/p' \
          | head -n1
      }

      entry=$(find_entry)
      if [ -z "$entry" ]; then
        efibootmgr --quiet --create --disk "$disk" --part "$partnum" --label "${label}" --loader '\EFI\shim\shimx64.efi'
        entry=$(find_entry)
        [ -n "$entry" ] || { echo "secureboot-shim: created an entry on $disk part $partnum but cannot find it by PARTUUID $partuuid" >&2; exit 1; }
        echo "secureboot-shim: created boot entry $entry"
      fi
      efibootmgr --quiet --bootnum "$entry" --active

      order=$(efibootmgr | sed -n 's/^BootOrder: //p')
      if [ "''${order%%,*}" != "$entry" ]; then
        rest=$(echo "$order" | tr ',' '\n' | { grep -vx "$entry" || true; } | paste -sd, -)
        efibootmgr --quiet --bootorder "$entry''${rest:+,$rest}"
        echo "secureboot-shim: moved $entry to the front of BootOrder"
      fi
    '';
  };

  unit = {
    unitConfig.RequiresMountsFor = [esp];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe sync;
    };
  };
in {
  imports = [./secureboot.nix];

  environment.systemPackages = [pkgs.mokutil];

  systemd = {
    services = {
      secureboot-shim =
        unit
        // {
          wantedBy = ["multi-user.target"];
          serviceConfig = unit.serviceConfig // {RemainAfterExit = true;};
        };
      secureboot-shim-refresh = unit;
    };
    # lanzaboote rewrites systemd-boot on updates; shim's copy has to follow.
    paths.secureboot-shim-refresh = {
      wantedBy = ["multi-user.target"];
      pathConfig.PathChanged = systemdBoot;
    };
  };
}
