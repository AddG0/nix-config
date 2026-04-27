{pkgs, ...}: let
  # Device identifiers - update these if your hardware changes
  micDevice = "alsa_input.usb-Focusrite_Scarlett_Solo_4th_Gen_S1YE3VE3790E29-00.HiFi__Mic2__source";
  headsetDevice = "alsa_output.usb-Chord_Electronics_Ltd_HugoTT2_413-001-01.analog-stereo";
in {
  # ============================================================================
  # Virtual Audio Devices
  # ============================================================================
  # Creates the audio routing pipeline:
  #   Physical Mic → Noise Gate → Main Input Mixer
  #   Soundboard → Main Input Mixer
  #   Music Sink → music_input + Hugo TT2 (Spotify/Zen → own mic + speakers)
  #   Main Input Mixer → main_input (use this in Discord/apps)
  # ============================================================================

  services.pipewire = {
    # Auto-route Spotify and Zen Browser to Music Sink
    extraConfig.pipewire-pulse."99-music-routing" = {
      "pulse.rules" = [
        {
          matches = [
            {"application.name" = "spotify";}
          ];
          actions.update-props = {
            "target.object" = "music_sink";
          };
        }
        {
          matches = [
            {"application.name" = "Zen";}
          ];
          actions.update-props = {
            "target.object" = "music_sink";
          };
        }
      ];
    };

    extraConfig.pipewire = {
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
                    plugin = "ZamGate-ladspa";
                    label = "ZamGate";
                    control = {
                      # Was -62, Needs testing at lower levels
                      "Threshold" = -55.0; # Audio below this level is muted
                      "Makeup" = 2.3; # Boost because my mic is quiet (≈1.3x volume)
                    };
                  }
                ];
              };
              "capture.props" = {
                "node.name" = "capture.gate_source";
                "node.passive" = true;
                "node.target" = micDevice;
              };
              "playback.props" = {
                "node.name" = "gate_source";
                "media.class" = "Audio/Source";
                "audio.position" = ["MONO"];
              };
            };
          }
        ];
      };

      # Soundboard: Virtual device for playing audio clips
      # Use with: soundboard /path/to/audio.mp3
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

      # Music Sink: Route Spotify/Zen here to send audio to speakers + its own mic
      # Set Spotify/Zen output to "Music Sink" in pavucontrol
      # Select "Music Input" as the mic in a Discord music bot account
      "99-music-sink.conf" = {
        "context.modules" = [
          {
            name = "libpipewire-module-loopback";
            args = {
              "node.description" = "Music Sink";
              "capture.props" = {
                "media.class" = "Audio/Sink";
                "node.name" = "music_sink";
              };
              "playback.props" = {
                "media.class" = "Audio/Source";
                "node.name" = "music_source";
              };
            };
          }
        ];
      };

      # Music Input: Dedicated mic source for music audio
      # Select this as mic input in Discord for the music bot
      "99-music-input.conf" = {
        "context.modules" = [
          {
            name = "libpipewire-module-loopback";
            args = {
              "node.description" = "Music Input";
              "capture.props" = {
                "media.class" = "Audio/Sink";
                "node.name" = "music_input_sink";
                "node.passive" = true;
              };
              "playback.props" = {
                "media.class" = "Audio/Source";
                "node.name" = "music_input";
                "node.passive" = true;
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
              "audio.position" = ["MONO"];
              "capture.props" = {
                "media.class" = "Audio/Sink";
                "node.name" = "main_input_sink";
                "stream.dont-remix" = true;
                "node.passive" = true; # Don't generate silence when nothing connected
              };
              "playback.props" = {
                "media.class" = "Audio/Source";
                "node.name" = "main_input";
                "stream.dont-remix" = true;
                "node.passive" = true; # Don't generate silence when nothing connected
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
              out_node = "${micDevice}",
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
    };

    # Make ZamGate (LADSPA) available on LADSPA_PATH for filter-chain
    extraLadspaPackages = [pkgs.zam-plugins];
  };

  # Port-level linking requires pw-link commands since WirePlumber's Lua API
  # doesn't support channel-specific connections in NixOS's extraConfig format.
  # This systemd service runs on boot to link:
  #   - gate_source:capture_MONO → main_input_sink:playback_MONO
  #   - soundboard_source:capture_1 → main_input_sink:playback_MONO
  #   - soundboard_source:capture_2 → main_input_sink:playback_MONO
  #   - music_source:capture_1/2 → music_input_sink (dedicated music mic for Discord)
  #   - music_source:capture_1/2 → HugoTT2:playback_FL/FR (you hear music)
  systemd.user.services.pipewire-link-main-input = {
    description = "Auto-link gate_source and soundboard to main_input";
    after = ["pipewire.service" "wireplumber.service"];
    wants = ["pipewire.service" "wireplumber.service"];
    wantedBy = ["pipewire.service"];
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

        # Also link soundboard to default speakers (HugoTT2) so I can hear it
        ${pkgs.pipewire}/bin/pw-link soundboard_source:capture_1 ${headsetDevice}:playback_FL || true
        ${pkgs.pipewire}/bin/pw-link soundboard_source:capture_2 ${headsetDevice}:playback_FR || true

        # Music sink → music_input (dedicated music mic for Discord)
        ${pkgs.pipewire}/bin/pw-link music_source:capture_1 music_input_sink:playback_1 || true
        ${pkgs.pipewire}/bin/pw-link music_source:capture_2 music_input_sink:playback_2 || true

        # Music sink → HugoTT2 (you hear music)
        ${pkgs.pipewire}/bin/pw-link music_source:capture_1 ${headsetDevice}:playback_FL || true
        ${pkgs.pipewire}/bin/pw-link music_source:capture_2 ${headsetDevice}:playback_FR || true
      '';
    };
  };
}
