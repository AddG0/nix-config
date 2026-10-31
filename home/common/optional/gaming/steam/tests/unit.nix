# games.nix entries to steam-config-nix apps: ReShade setups applied always or per host opt-in, and game-folder
# files handed to the host on a shared library.
{lib, ...}: let
  reshade = import ../reshade.nix {
    inherit lib;
    runCommand = name: _: _: "/fake/lowercased/${name}";
    reshadePkgs = {
      reshade = "/fake/reshade";
      d3dcompiler_47-dll = "/fake/d3dcompiler";
      reshade-shaders.override = _: "/fake/shaders";
      reshadeShaders.SweetFX = "/fake/sweetfx";
    };
  };
  mkApps = import ../apps.nix {
    inherit lib reshade;
    writeText = _: text: "/fake/text/${text}";
  };

  setup = extra:
    {
      preset = "/fake/preset.ini";
      presetName = "Look.ini";
      packs = ["SweetFX"];
    }
    // extra;

  games = {
    racer = {
      id = 1;
      reshade = setup {};
    };
    licensed = {
      id = 2;
      reshade = setup {optIn = true;};
    };
    # Forcing this preset means a host that never opted in still pulls the file into its build.
    unlicensed = {
      id = 3;
      reshade = setup {
        optIn = true;
        preset = throw "unlisted opt-in preset was evaluated";
      };
    };
    plain.id = 4;
    modded = {
      id = 5;
      files.game = {
        place = {
          "mods/a.dll" = {
            source = "/fake/a.dll";
            mode = "seed";
          };
          "./mods//b.cfg".text = "b";
          "off.dll" = {
            source = "/fake/off.dll";
            enable = false;
          };
        };
        patch."cfg.ini".content.Video.Fullscreen = 1;
      };
    };
  };

  build = args:
    mkApps ({
        inherit games;
        reshadeGames = [];
        sharedLibrary = false;
      }
      // args);
  apps = args: (build args).apps;

  placed = app: lib.attrNames (app.files.game.place or {});
in {
  "test a setup without optIn applies on a host that lists nothing" = {
    expr = {
      inherit ((apps {}).racer) dllOverrides;
      dxgi = (apps {}).racer.files.game.place."dxgi.dll".source;
    };
    expected = {
      dllOverrides = {
        dxgi = "n,b";
        d3dcompiler_47 = "n";
      };
      dxgi = "/fake/reshade/lib/reshade/ReShade64.dll";
    };
  };

  "test an opt-in setup stays off on a host that does not list it" = {
    expr = (apps {}).licensed;
    expected = {id = 2;};
  };

  "test an unlisted opt-in setup never evaluates its preset" = {
    expr = builtins.deepSeq (apps {}).unlicensed (apps {}).unlicensed;
    expected = {id = 3;};
  };

  "test a listed opt-in setup places ReShade, its shaders and the preset" = {
    expr = placed (apps {reshadeGames = ["licensed"];}).licensed;
    expected = ["Look.ini" "ReShade.ini" "d3dcompiler_47.dll" "dxgi.dll" "reshade-shaders"];
  };

  "test the reshade setup is not passed through to steam-config-nix" = {
    expr = (apps {reshadeGames = ["licensed"];}).licensed ? reshade;
    expected = false;
  };

  "test a shader pack name nix-reshade does not have is rejected by name" = {
    expr =
      (apps {
        games.racer = {
          id = 1;
          reshade = setup {packs = ["SweetFX by CeeJay.dk"];};
        };
      }).racer.dllOverrides;
    expectedError = {
      type = "ThrownError";
      msg = "no shader pack named SweetFX by CeeJay.dk";
    };
  };

  "test listing a game with no reshade setup is rejected by name" = {
    expr = apps {reshadeGames = ["plain" "typo"];};
    expectedError = {
      type = "ThrownError";
      msg = "no reshade setup in steam/games.nix for plain, typo";
    };
  };

  "test without a shared library each user keeps placing game files and hands the host nothing" = {
    expr = {
      placed = placed (apps {}).modded;
      inherit (build {}) libraryFiles;
    };
    expected = {
      placed = ["./mods//b.cfg" "mods/a.dll" "off.dll"];
      libraryFiles = [];
    };
  };

  "test on a shared library game-folder placements go to the host as steam-config-nix file operations" = {
    expr = let
      shared = build {sharedLibrary = true;};
    in {
      userPlaced = placed shared.apps.modded;
      userPatches = shared.apps.modded.files.game.patch;
      host = lib.filter (op: op.appId == 5) shared.libraryFiles;
    };
    expected = {
      userPlaced = [];
      userPatches."cfg.ini".content.Video.Fullscreen = 1;
      host = [
        {
          appId = 5;
          target = "mods/b.cfg";
          source = "/fake/text/b";
          mode = "enforce";
          executable = null;
        }
        {
          appId = 5;
          target = "mods/a.dll";
          source = "/fake/a.dll";
          mode = "seed";
          executable = null;
        }
      ];
    };
  };

  "test on a shared library a placement with both source and text is rejected by app and target" = {
    expr =
      (build {
        sharedLibrary = true;
        games.broken = {
          id = 6;
          files.game.place."x.ini" = {
            source = "/fake/x.ini";
            text = "x";
          };
        };
      }).libraryFiles;
    expectedError = {
      type = "ThrownError";
      msg = "app 6 files.game.place.\"x.ini\": set exactly one of source or text";
    };
  };

  "test on a shared library a placement with an unknown mode is rejected" = {
    expr =
      (build {
        sharedLibrary = true;
        games.broken = {
          id = 6;
          files.game.place."x.ini" = {
            text = "x";
            mode = "keep";
          };
        };
      }).libraryFiles;
    expectedError = {
      type = "ThrownError";
      msg = "mode must be enforce, seed or lock, not keep";
    };
  };

  "test on a shared library a ReShade setup is placed by the host and its DLL overrides stay with the user" = {
    expr = let
      shared = build {sharedLibrary = true;};
    in {
      inherit (shared.apps.racer) dllOverrides;
      host = map (op: op.target) (lib.filter (op: op.appId == 1) shared.libraryFiles);
    };
    expected = {
      dllOverrides = {
        dxgi = "n,b";
        d3dcompiler_47 = "n";
      };
      host = ["Look.ini" "ReShade.ini" "d3dcompiler_47.dll" "dxgi.dll" "reshade-shaders"];
    };
  };
}
