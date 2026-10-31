# games.nix entries to steam-config-nix apps: ReShade setups applied always or per host opt-in.
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
  mkApps = import ../apps.nix {inherit lib reshade;};

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
  };

  apps = args:
    mkApps ({
        inherit games;
        reshadeGames = [];
      }
      // args);

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
      (mkApps {
        games.racer = {
          id = 1;
          reshade = setup {packs = ["SweetFX by CeeJay.dk"];};
        };
        reshadeGames = [];
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
}
