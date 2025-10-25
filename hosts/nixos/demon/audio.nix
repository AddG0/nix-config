{ pkgs, ... }: {
  # ============================================================================
  # PipeWire Audio Configuration
  # ============================================================================
  # This configuration sets up a complete audio routing system with:
  # 1. Noise gate for microphone input (removes cable static/background noise)
  # 2. Virtual soundboard device for playing audio clips
  # 3. Combined "Main Input" that mixes both mic and soundboard together
  #
  # Audio Flow:
  #   Physical Mic (Scarlett Solo)
  #     → Noise Gate (gate_source, -60dB threshold with 2.3dB makeup gain)
  #     → Main Input Mixer (main_input_sink)
  #
  #   Soundboard Alias (`soundboard` command)
  #     → Soundboard Sink (soundboard_sink)
  #     → Soundboard Source (soundboard_source)
  #     → Main Input Mixer (main_input_sink)
  #
  #   Main Input Mixer → Main Input (main_input) ← Use this in Discord/apps
  # ============================================================================

  # Shell alias for soundboard (use: soundboard file.mp3 [--volume=N])
  # Default 50% volume, override with: soundboard file.mp3 --volume=80
  environment.shellAliases = {
    soundboard = "${pkgs.mpv}/bin/mpv --no-video --audio-device=pipewire/soundboard_sink --volume=50";
  };

  # Grant audio group real-time priority and unlimited memory lock for low-latency audio
  security.pam.loginLimits = [
    { domain = "@audio"; type = "soft"; item = "rtprio"; value = "95"; }
    { domain = "@audio"; type = "hard"; item = "rtprio"; value = "99"; }
    { domain = "@audio"; type = "soft"; item = "memlock"; value = "unlimited"; }
    { domain = "@audio"; type = "hard"; item = "memlock"; value = "unlimited"; }
  ];

  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;

    extraConfig.pipewire = {
      # High-fidelity audio: 96kHz default with support for common sample rates
      "99-hifi.conf" = {
        "context.properties" = {
          "default.clock.rate" = 96000;
          "default.clock.allowed-rates" = [ 44100 48000 88200 96000 192000 ];
          "resample.quality" = 10;
        };
      };

      # Noise Gate: Removes cable static and background noise below -60dB
      # Uses ZamGate LADSPA plugin with 2.3dB makeup gain to boost volume to 1.3x
      # Output: gate_source (use this if you only want gated mic without soundboard)
      "99-noise-gate.conf" = {
        "context.modules" = [
          {
            name = "libpipewire-module-filter-chain";
            args = {
              "node.description" = "Noise Gate";
              "media.name" = "Noise Gate";
              "filter.graph" = {
                nodes = [
                  {
                    type = "ladspa";
                    name = "gate";
                    plugin = "${pkgs.zam-plugins}/lib/ladspa/ZamGate-ladspa.so";
                    label = "ZamGate";
                    control = {
                      "Threshold" = -60.0;  # Audio below this level is muted
                      "Makeup" = 2.3;        # Boost because my mic is quiet (≈1.3x volume)
                    };
                  }
                ];
              };
              "capture.props" = {
                "node.name" = "capture.gate_source";
                "node.passive" = true;
                "audio.rate" = 48000;
                "node.target" = "alsa_input.usb-Focusrite_Scarlett_Solo_4th_Gen_S1YE3VE3790E29-00.HiFi__Mic2__source";
              };
              "playback.props" = {
                "node.name" = "gate_source";
                "media.class" = "Audio/Source";
                "audio.rate" = 48000;
              };
            };
          }
        ];
      };

      # Soundboard: Virtual device for playing audio clips
      # Use with: soundboard /path/to/audio.mp3 (see home/common/core/cli/shells/zsh.nix)
      # Plays audio to soundboard_sink, which becomes available as soundboard_source
      "99-soundboard.conf" = {
        "context.modules" = [
          {
            name = "libpipewire-module-loopback";
            args = {
              "node.description" = "Soundboard";
              "capture.props" = {
                "media.class" = "Audio/Sink";
                "node.name" = "soundboard_sink";
              };
              "playback.props" = {
                "media.class" = "Audio/Source";
                "node.name" = "soundboard_source";
              };
            };
          }
        ];
      };

      # Main Input: Combines gate_source + soundboard_source into one input
      # This is what you select as your microphone in Discord/voice apps
      # node.passive prevents static when nothing is connected
      "99-main-input.conf" = {
        "context.modules" = [
          {
            name = "libpipewire-module-loopback";
            args = {
              "node.description" = "Main Input";
              "audio.position" = [ "MONO" ];
              "capture.props" = {
                "media.class" = "Audio/Sink";
                "node.name" = "main_input_sink";
                "stream.dont-remix" = true;
                "node.passive" = true;  # Don't generate silence when nothing connected
              };
              "playback.props" = {
                "media.class" = "Audio/Source";
                "node.name" = "main_input";
                "stream.dont-remix" = true;
                "node.passive" = true;  # Don't generate silence when nothing connected
              };
            };
          }
        ];
      };
    };

    wireplumber = {
      extraConfig = {
        # Auto-connect physical mic to noise gate input
        # WirePlumber's simple link table only works for node-to-node, not port-level
        "99-auto-connect.lua" = {
          text = ''
            table.insert(links, {
              out_node = "alsa_input.usb-Focusrite_Scarlett_Solo_4th_Gen_S1YE3VE3790E29-00.HiFi__Mic2__source",
              in_node  = "capture.gate_source",
            })
          '';
        };

        # Auto-link soundboard to default audio sink (dynamic - follows default changes)
        "99-soundboard-to-default.lua" = {
          text = ''
            table.insert(links, {
              out_node = "soundboard_source",
              in_node  = "@DEFAULT_AUDIO_SINK@",
            })
          '';
        };
      };

      # Make ZamGate plugin available to PipeWire
      extraLv2Packages = [ pkgs.zam-plugins ];
    };
  };

  # Port-level linking requires pw-link commands since WirePlumber's Lua API
  # doesn't support channel-specific connections in NixOS's extraConfig format.
  # This systemd service runs on boot to link:
  #   - gate_source:capture_MONO → main_input_sink:playback_MONO
  #   - soundboard_source:capture_1 → main_input_sink:playback_MONO
  #   - soundboard_source:capture_2 → main_input_sink:playback_MONO
  systemd.user.services.pipewire-link-main-input = {
    description = "Auto-link gate_source and soundboard to main_input";
    after = [ "pipewire.service" "wireplumber.service" ];
    wants = [ "pipewire.service" "wireplumber.service" ];
    wantedBy = [ "pipewire.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "link-main-input" ''
        # Wait for ports to be available (retry up to 10 times)
        for i in {1..10}; do
          ${pkgs.pipewire}/bin/pw-link gate_source:capture_MONO main_input_sink:playback_MONO 2>/dev/null && break
          sleep 1
        done

        # Link all sources to main_input mixer
        ${pkgs.pipewire}/bin/pw-link gate_source:capture_MONO main_input_sink:playback_MONO || true
        ${pkgs.pipewire}/bin/pw-link soundboard_source:capture_1 main_input_sink:playback_MONO || true
        ${pkgs.pipewire}/bin/pw-link soundboard_source:capture_2 main_input_sink:playback_MONO || true

        # Also link soundboard to default speakers (HugoTT2) so you can hear it
        ${pkgs.pipewire}/bin/pw-link soundboard_source:capture_1 alsa_output.usb-Chord_Electronics_Ltd_HugoTT2_413-001-01.analog-stereo:playback_FL || true
        ${pkgs.pipewire}/bin/pw-link soundboard_source:capture_2 alsa_output.usb-Chord_Electronics_Ltd_HugoTT2_413-001-01.analog-stereo:playback_FR || true
      '';
    };
  };
}
