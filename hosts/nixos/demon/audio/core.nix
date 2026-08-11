_: {
  # ============================================================================
  # Core Audio Configuration (demon-specific layer)
  # ============================================================================
  # Base PipeWire/WirePlumber enablement, quality defaults, and the AirPods
  # A2DP-forcing WirePlumber hook come from the shared
  # common/optional/nixos/audio.nix (imported by this host). This file only adds
  # demon-only tweaks: real-time priority for the @audio group and the Hugo TT2
  # high-fidelity / suspend-resilience settings.
  # ============================================================================

  # Grant audio group real-time priority and unlimited memory lock for low-latency audio
  security.pam.loginLimits = [
    {
      domain = "@audio";
      type = "soft";
      item = "rtprio";
      value = "95";
    }
    {
      domain = "@audio";
      type = "hard";
      item = "rtprio";
      value = "99";
    }
    {
      domain = "@audio";
      type = "soft";
      item = "memlock";
      value = "unlimited";
    }
    {
      domain = "@audio";
      type = "hard";
      item = "memlock";
      value = "unlimited";
    }
  ];

  services.pipewire = {
    extraConfig.pipewire = {
      # audio.rate on the Hugo node below is what holds the DAC at 96kHz — not
      # clock.force-rate, which pipewire 1.6.8 parses but never applies.
      "99-hifi.conf" = {
        "context.properties" = {
          "default.clock.rate" = 96000;
          "default.clock.allowed-rates" = [44100 48000 88200 96000 176400 192000];
          "resample.quality" = 14;
        };
      };
    };

    # NOTE: Do NOT pin this DAC open with `session.suspend-timeout-seconds = 0`.
    # Doing so makes WirePlumber eagerly open the device the instant its node
    # appears, which races the pipewire-link-main-input service's pw-link to
    # HugoTT2:playback (virtual-devices.nix). The link forces the node RUNNING
    # mid set_hw_params → EBADFD, and a pinned device can never reopen, so audio
    # dies until `systemctl --user restart wireplumber`. Letting it suspend
    # normally keeps the link service the sole opener and restores self-recovery.

    wireplumber.extraConfig."51-demon-audio-driver-priority" = {
      "monitor.alsa.rules" = [
        {
          matches = [
            {
              "node.name" = "alsa_output.usb-Chord_Electronics_Ltd_HugoTT2_413-001-01.analog-stereo";
            }
          ];
          actions.update-props = {
            "priority.driver" = 3000;
            "audio.rate" = 96000;
            # Underruns at the default 512 — shares an xHCI controller with the Scarlett.
            "api.alsa.headroom" = 2048;
          };
        }
        {
          matches = [
            {
              "node.name" = "alsa_input.hw_Gen_0";
            }
          ];
          actions.update-props = {
            "priority.driver" = 100;
            # Don't let this negotiate its own rate: it opened at 48kHz against a
            # 96kHz group timebase and then waited a full cycle every cycle,
            # starving the whole mic chain.
            "audio.rate" = 96000;
          };
        }
      ];
    };
  };
}
