#############################################################
#
#  mt7927 - MediaTek MT7927 / MT6639 (Filogic 380) Wi-Fi 7 + Bluetooth
#
#  demon's X870E Hero onboard radio (PCI 14c3:6639) has no mainline driver:
#  the in-tree mt7925e only binds 14c3:7925/0717. This builds the patched
#  mt76/mt7925e (Wi-Fi) and btusb/btmtk (Bluetooth) out-of-tree — jetm's
#  MT7927 patches over mainline 7.1.3 source — against demon's running
#  kernel, plus the MT6639 Wi-Fi+BT firmware extracted from ASUS's driver
#  package (not in linux-firmware).
#
#  The firmware ZIP is fetched from ASUS behind an expiring signed URL, so it
#  can't live in a Nix fetcher — supply it once (see requireFile message).
#
###############################################################
{
  inputs,
  config,
  pkgs,
  lib,
  ...
}: let
  kernel = config.boot.kernelPackages.kernel;

  # Mainline version whose mt76/bluetooth source jetm's patches apply onto.
  mt76Kver = "7.1.3";
  kernelSrc = pkgs.fetchurl {
    url = "mirror://kernel/linux/kernel/v7.x/linux-${mt76Kver}.tar.xz";
    hash = "sha256-vkHAaOiPUkKhm8zb/74HexjEe0X2J+IyVQS0+red0dw=";
  };

  # ASUS Windows driver package — used only for MT6639 firmware extraction.
  driverZip = pkgs.requireFile {
    name = "DRV_WiFi_MTK_MT7925_MT7927_TP_W11_64_V5603998_20250709R.zip";
    sha256 = "sha256-s3f/+iggi7FnGg6yGchMYvukzW+SFht05LCQlHYwfMg=";
    message = ''
      MT7927 firmware ZIP not in the store. Fetch it once (expiring ASUS URL):

        curl -fsSL https://raw.githubusercontent.com/jetm/mediatek-mt7927-dkms/master/download-driver.sh | bash

      then add it and record its hash:

        nix store add-file DRV_WiFi_MTK_MT7925_MT7927_TP_W11_64_V5603998_20250709R.zip
        nix hash file DRV_WiFi_MTK_MT7925_MT7927_TP_W11_64_V5603998_20250709R.zip

      Put that hash in the `sha256` above.
    '';
  };

  mt7927 = pkgs.stdenv.mkDerivation {
    pname = "mt7927-mt76";
    version = "2.13-${kernel.modDirVersion}";
    src = inputs.mt7927-driver;

    # CachyOS kernel is clang-built but moduleBuildDependencies omits the
    # compiler. Unwrapped clang — the cc-wrapper's flags (--target,
    # -nostdlibinc) break kbuild, which supplies its own.
    nativeBuildInputs =
      kernel.moduleBuildDependencies
      ++ [pkgs.python3]
      ++ (with pkgs.llvmPackages_21; [clang-unwrapped lld llvm]);

    buildPhase = ''
      runHook preBuild
      mkdir -p _build/mt76 _build/bluetooth _build/firmware

      tar -xf ${kernelSrc} --strip-components=6 -C _build/mt76 \
        linux-${mt76Kver}/drivers/net/wireless/mediatek/mt76
      tar -xf ${kernelSrc} --strip-components=3 -C _build/bluetooth \
        linux-${mt76Kver}/drivers/bluetooth

      for p in "$src"/mt7927-wifi-*.patch; do patch -d _build/mt76 -p1 <"$p"; done
      for p in "$src"/mt6639-bt-[0-9]*.patch "$src"/mt6639-bt-compat-*.patch; do
        patch -d _build/bluetooth -p1 <"$p"
      done

      cp "$src"/bluetooth.Makefile _build/bluetooth/Makefile
      cp "$src"/mt76.Kbuild _build/mt76/Kbuild
      cp "$src"/mt7921.Kbuild _build/mt76/mt7921/Kbuild
      cp "$src"/mt7925.Kbuild _build/mt76/mt7925/Kbuild
      mkdir -p _build/mt76/compat/include/linux/soc/airoha
      cp "$src"/compat-airoha-offload.h \
        _build/mt76/compat/include/linux/soc/airoha/airoha_offload.h

      python3 "$src"/extract_firmware.py ${driverZip} _build/firmware

      kdir=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build
      llvm=$(grep -qs '^CONFIG_CC_IS_CLANG=y' "$kdir/.config" && echo LLVM=1 || true)
      make -j$NIX_BUILD_CORES $llvm -C "$kdir" M="$PWD/_build/bluetooth" modules
      make -j$NIX_BUILD_CORES $llvm -C "$kdir" M="$PWD/_build/mt76" modules
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      # updates/ so depmod outranks the in-tree mt7925e/mt76 of the same name
      inst=$out/lib/modules/${kernel.modDirVersion}/updates
      install -dm755 "$inst"
      find _build -name '*.ko' -exec install -m644 {} "$inst/" \;

      fw=$out/lib/firmware/mediatek/mt7927
      install -dm755 "$fw"
      install -m644 _build/firmware/*.bin "$fw/"
      runHook postInstall
    '';

    meta = {
      description = "Patched mt76/mt7925e + firmware for MediaTek MT7927 (Filogic 380)";
      platforms = ["x86_64-linux"];
    };
  };
in {
  boot.extraModulePackages = [mt7927];
  hardware.firmware = [mt7927];
  boot.kernelModules = ["mt7925e" "btusb"];
}
