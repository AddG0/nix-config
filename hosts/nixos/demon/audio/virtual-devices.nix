{pkgs, ...}: let
  # Device identifiers - update these if your hardware changes
  micDevice = "alsa_input.usb-Focusrite_Scarlett_Solo_4th_Gen_S1YE3VE3790E29-00.HiFi__Mic2__source";

  # Patch cable from `source` into `sink`, for fan-out: a stream can name only one
  # target. Not passive — the mic must reach the mixer even when nothing listens.
  # node.dont-fallback here and in mkTap stops a missing target from silently
  # landing on some other device.
  mkPatchModule = {
    name,
    description,
    source,
    sink,
    position,
  }: {
    name = "libpipewire-module-loopback";
    args = {
      "node.description" = description;
      "audio.position" = position;
      "capture.props" = {
        "node.name" = "capture.${name}";
        "target.object" = source;
        "node.dont-fallback" = true;
      };
      "playback.props" = {
        "node.name" = name;
        "target.object" = sink;
        "node.dont-fallback" = true;
      };
    };
  };

  # Pulls from `source` and re-exposes it as `name`. Passive: nothing runs until
  # something consumes `name`.
  mkTap = {
    name,
    description,
    source,
    position,
  }: {
    "context.modules" = [
      {
        name = "libpipewire-module-loopback";
        args = {
          "node.description" = description;
          "audio.position" = position;
          "capture.props" = {
            "node.name" = "capture.${name}";
            "target.object" = source;
            "node.dont-fallback" = true;
            "node.passive" = true;
          };
          "playback.props" = {
            "media.class" = "Audio/Source";
            "node.name" = name;
            "node.passive" = true;
          };
        };
      }
    ];
  };
in {
  # ============================================================================
  # Virtual Audio Devices
  # ============================================================================
  # Creates the audio routing pipeline:
  #   Physical Mic → Noise Gate → Main Input Mixer
  #   Soundboard → Main Input Mixer
  #   Music Sink → music_input + Hugo TT2 (Spotify/Zen → own mic + speakers)
  #   Main Input Mixer → main_input (use this in Discord/apps)
  #
  # Every link here is declared on the node that wants it (target.object), so the
  # session manager makes and remakes them. Deliberately no pw-link service — a
  # one-shot link at boot races the USB probe and stays unmade when it loses.
  #
  # A node feeding both the mixer and the DAC merges them into one driver group,
  # making the Scarlett follow the DAC clock — safe only while both are pinned to
  # the same rate (core.nix). Anything heard *and* sent to Discord plays two streams.
  # ============================================================================

  services.pipewire = {
    extraConfig.pipewire = {
      # Microphone → Discord

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
              # Only ever feeds the MONO mixer — what you hear is a separate stream
              # the script plays to the default device. The sink downmixes, so
              # neither channel is lost.
              "audio.position" = ["MONO"];
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

      # Combines gate_source + soundboard_source into the mic you pick in Discord.
      # A summing point has to be a real sink, since a stream can target only one
      # object — which is why the two producers arrive as patch cables below.
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
                "node.passive" = true;
              };
            };
          }
        ];
      };

      # main_input sums two producers, so each needs its own patch cable in.
      "99-main-input-patches.conf" = {
        "context.modules" = [
          (mkPatchModule {
            name = "gate_to_main_input";
            description = "Noise Gate → Main Input";
            source = "gate_source";
            sink = "main_input_sink";
            position = ["MONO"];
          })
          (mkPatchModule {
            name = "soundboard_to_main_input";
            description = "Soundboard → Main Input";
            source = "soundboard_source";
            sink = "main_input_sink";
            position = ["MONO"];
          })
        ];
      };

      # The mic feed on a node that mic-mute doesn't touch (it mutes main_input),
      # for apps that should keep capturing while the mic is muted for everyone else.
      "99-direct-input.conf" = mkTap {
        name = "direct_input";
        description = "Direct Input";
        source = "gate_source";
        position = ["MONO"];
      };

      # Music → Discord + speakers

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
      "99-music-input.conf" = mkTap {
        name = "music_input";
        description = "Music Input";
        source = "music_source";
        position = ["FL" "FR"];
      };

      # Music Monitor: Adjusts the music you HEAR on the Hugo TT2 (see "Mult" below)
      # WITHOUT touching the music_input feed sent to Discord.
      # Path: music_source → capture.music_monitor → [linear gain] → music_monitor → Hugo
      # The builtin "linear" plugin applies new = old * Mult + Add per sample.
      "99-music-monitor.conf" = {
        "context.modules" = [
          {
            name = "libpipewire-module-filter-chain";
            args = {
              "node.description" = "Music Monitor";
              "media.name" = "Music Monitor";
              "filter.graph" = {
                nodes = [
                  {
                    type = "builtin";
                    name = "vol";
                    label = "linear";
                    control = {
                      "Mult" = 1.2; # gain applied to what you hear (1.0 = unchanged)
                      "Add" = 0.0;
                    };
                  }
                ];
              };
              "capture.props" = {
                "node.name" = "capture.music_monitor";
                "audio.position" = ["FL" "FR"];
                "target.object" = "music_source";
                "node.dont-fallback" = true;
                "node.passive" = true; # Don't generate silence when no music plays
              };
              # A stream, not an Audio/Source: only streams get routed.
              "playback.props" = {
                "node.name" = "music_monitor";
                "media.class" = "Stream/Output/Audio";
                "audio.position" = ["FL" "FR"];
                # Unpinned on purpose: follows the default sink, so choosing an
                # output (eq.nix) also chooses its correction for music. A
                # target.object here silently bypasses the EQ sinks, and
                # node.dont-fallback would block the default routing that
                # replaces it. Reconnect stays on (not dont-reconnect, which
                # would destroy the node) so it reattaches when the DAC returns.
              };
            };
          }
        ];
      };
    };

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

    # Make ZamGate (LADSPA) available on LADSPA_PATH for filter-chain
    extraLadspaPackages = [pkgs.zam-plugins];
  };
}
