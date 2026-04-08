{
  lib,
  pkgs,
  ...
}: let
  # Host scope:
  # - Machine: Razer Blade 16
  # - Product ID: RZ09-0581
  # - Board name: SO6120
  # Audio mode selector for quick reboot-based testing.
  #
  # Available modes:
  # - "fallback-hda"   : force legacy HDA (snd-intel-dspcfg.dsp_driver=1)
  # - "sof-test"       : SOF enabled + link mask 9 + filename compatibility shim
  # - "sof-test-4ch"   : sof-test plus forced 4ch topology filename override
  # - "hda-verb-fix"   : legacy HDA plus boot-time amp init script (Bug 207423 c94)
  #
  # Known outcomes on this host:
  # - fallback-hda  -> no internal analog endpoints surfaced (HDMI-only, Dummy Output)
  # - sof-test      -> firmware/topology found, but topology wiring fails with ASoC -22
  # - sof-test-4ch  -> topology also fails with ASoC -22 (Playback-SimpleJack path)
  # - hda-verb-fix  -> experimental; applies community hda-verb workaround at boot
  #
  # Change this value, rebuild, and reboot for each test iteration.
  audioMode = "hda-verb-fix";

  # Validation baseline (last checked):
  # - Kernel: 6.18.20
  # - sof-firmware: 2025.12.2

  kernelParamsByMode = {
    "fallback-hda" = ["snd-intel-dspcfg.dsp_driver=1"];
    "sof-test" = ["snd_intel_sdw_acpi.sdw_link_mask=9"];
    "sof-test-4ch" = ["snd_intel_sdw_acpi.sdw_link_mask=9"];
    "hda-verb-fix" = [
      "snd-intel-dspcfg.dsp_driver=1"
      "snd-hda-intel.model=alc298-samsung-amp-v2-4-amps"
    ];
  };

  # Only needed for the explicit 4ch topology experiment.
  extraModprobeConfigByMode = {
    "fallback-hda" = "";
    "sof-test" = "";
    "sof-test-4ch" = ''
      options snd_sof tplg_filename=sof-ptl-rt721-4ch.tplg
    '';
    "hda-verb-fix" = "";
  };

  razerHdaVerbScript = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/joshuagrisham/galaxy-book2-pro-linux/main/sound/necessary-verbs.sh";
    hash = "sha256-vH2jn8rgznzmKZA96DVaLX0wMB+Cu7uIU4cyP1fSqcc=";
  };

  applyRazerHdaVerbFix = pkgs.writeShellScript "apply-razer-hda-verb-fix" ''
    set -euo pipefail

    card_num="$(${pkgs.gawk}/bin/awk '/\[PCH[[:space:]]*\]/{ gsub(/[^0-9]/, "", $1); print $1; exit }' /proc/asound/cards || true)"

    if [ -n "''${card_num}" ] && [ -e "/dev/snd/hwC''${card_num}D0" ]; then
      device="/dev/snd/hwC''${card_num}D0"
    else
      device="$(${pkgs.findutils}/bin/find /dev/snd -maxdepth 1 -type c -name 'hwC*D0' | ${pkgs.coreutils}/bin/sort | ${pkgs.coreutils}/bin/head -n 1 || true)"
    fi

    if [ -z "''${device:-}" ]; then
      echo "ALSA hwC?D0 device not found; skipping hda-verb speaker init" >&2
      exit 1
    fi

    tmp_script="$(${pkgs.coreutils}/bin/mktemp)"
    trap '${pkgs.coreutils}/bin/rm -f "$tmp_script"' EXIT

    ${pkgs.gnused}/bin/sed "s|/dev/snd/hwC0D0|$device|g" "${razerHdaVerbScript}" > "$tmp_script"

    PATH=${pkgs.alsa-tools}/bin:${pkgs.coreutils}/bin:${pkgs.bash}/bin
    ${pkgs.bash}/bin/bash "$tmp_script"
  '';

  selectedKernelParams =
    kernelParamsByMode.${audioMode}
    or (throw "Unknown audioMode '${audioMode}' in audio-workarounds.nix");
  selectedExtraModprobeConfig =
    extraModprobeConfigByMode.${audioMode}
    or (throw "Unknown audioMode '${audioMode}' in audio-workarounds.nix");

  # Audio workaround module for freyr (PTL + RT721).
  #
  # Background:
  # - Kernel machine selection requests: intel/sof-ipc4-tplg/sof-ptl-rt721-2ch.tplg
  # - sof-firmware package provides:   intel/sof-ipc4-tplg/sof-ptl-rt721.tplg
  # - Initial failure mode was missing firmware/topology (-2), followed by
  #   topology wiring failures (-22) with Dummy Output in PipeWire.
  #
  # This compatibility package keeps filename expectations aligned so we can
  # safely test SOF behavior and/or run fallback audio without manual file hacks.
  sofPtlRt721Compat = pkgs.runCommand "sof-ptl-rt721-compat" {} ''
    set -euo pipefail

    src_fw_dir="${pkgs.sof-firmware}/lib/firmware/intel/sof-ipc4/ptl"
    src_tplg_dir="${pkgs.sof-firmware}/lib/firmware/intel/sof-ipc4-tplg"
    out_fw_dir="$out/lib/firmware/intel/sof-ipc4/ptl"
    out_tplg_dir="$out/lib/firmware/intel/sof-ipc4-tplg"

    mkdir -p "$out_fw_dir" "$out_tplg_dir"

    # Keep firmware filename available explicitly in case firmware path ordering
    # does not pick it up from the base sof-firmware package at runtime.
    cp "$src_fw_dir/sof-ptl.ri" "$out_fw_dir/sof-ptl.ri"

    # Provide the 2ch topology filename expected by current kernel machine logic.
    # This is a filename compatibility shim; it does not guarantee topology
    # routing correctness on every board revision.
    cp "$src_tplg_dir/sof-ptl-rt721.tplg" "$out_tplg_dir/sof-ptl-rt721-2ch.tplg"
  '';
in {
  # Base firmware and temporary compatibility payload used for PTL audio bring-up.
  hardware.firmware = with pkgs; [
    linux-firmware
    sof-firmware
    sofPtlRt721Compat
  ];

  # Active mode selected at top of file.
  boot.kernelParams = selectedKernelParams;
  boot.extraModprobeConfig = selectedExtraModprobeConfig;

  systemd.services.razer-hda-verb-fix = lib.mkIf (audioMode == "hda-verb-fix") {
    description = "Apply Razer ALC298 hda-verb speaker workaround";
    wantedBy = ["multi-user.target"];
    after = ["systemd-modules-load.service"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = applyRazerHdaVerbFix;
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  # Quick verification after rebuild/reboot:
  # - `cat /proc/cmdline` -> confirms active audio kernel params
  # - `wpctl status` -> ensure real sinks/sources, not only Dummy Output
  # - `journalctl -b | rg -i "sof-audio|ASoC|Playback-SimpleJack|sof_probe_work"`
  #   to inspect SOF probe/topology status
}
