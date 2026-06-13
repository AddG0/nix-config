# MediaTek MT7927 (Filogic 380, chip variant MT6639) Bluetooth enablement.
#
# demon's onboard BT (USB 13d3:3588 on the ASUS ROG Crosshair X870E Hero) is an
# MT7927. Bluetooth support landed in the kernel only in 7.1 (btusb device ID +
# btmtk 0x6639 variant + firmware section-filtering fix, merged via
# bluetooth-next 2026-03-31). The shared cachyos-kernel.nix pins the stable BORE
# line (7.0.11), which predates that support, so force the RC line (7.1-rc6+)
# here — verified to carry the 13d3:3588 entry and the 0x6639 firmware path.
{
  lib,
  pkgs,
  ...
}: let
  # The driver loads its firmware via request_firmware() at the exact path
  # MODULE_FIRMWARE() declares in 7.1: mediatek/mt7927/BT_RAM_CODE_MT6639_2_1_hdr.bin.
  # That blob isn't in linux-firmware yet (redistribution MR !946 closed
  # unmerged), so fetch it from that MR's fork branch, pinned to an immutable
  # commit SHA. If GitLab ever GCs the fork, repin to a later source (upstream
  # linux-firmware once MediaTek clears redistribution).
  mt7927-bt-firmware =
    pkgs.runCommandLocal "mt7927-bt-firmware" {
      src = pkgs.fetchurl {
        name = "BT_RAM_CODE_MT6639_2_1_hdr.bin";
        url = "https://gitlab.com/api/v4/projects/80012974/repository/files/mediatek%2Fmt7927%2FBT_RAM_CODE_MT6639_2_1_hdr.bin/raw?ref=77ad2a92acf2ac3e5ea47432b43d925ff99db909";
        hash = "sha256-ZpxcmaDFnIXBKF09G4sxkVwtMTQaIkT07dy/1g/7vHY=";
      };
    } ''
      install -Dm444 "$src" "$out/lib/firmware/mediatek/mt7927/BT_RAM_CODE_MT6639_2_1_hdr.bin"
    '';
in {
  boot.kernelPackages = lib.mkForce pkgs.cachyosKernels.linuxPackages-cachyos-rc;

  hardware.firmware = [mt7927-bt-firmware];
}
