# ReShade for a D3D10–12 game: ReShade64.dll beside the exe as dxgi.dll, loaded ahead of Proton's DXVK dxgi.
# Usage: `reshade {preset = …; presetName = "Foo.ini"; packs = ["SweetFX-by-CeeJay.dk"];}`; packs are reshadeShaders attr names.
{
  lib,
  runCommand,
  reshadePkgs,
}: {
  preset,
  presetName,
  packs,
}: let
  # reshade-shaders silently skips names it doesn't know.
  unknownPacks = lib.filter (pack: !(reshadePkgs.reshadeShaders ? ${pack})) packs;
  shaders = reshadePkgs.reshade-shaders.override {
    includeEnabled = false;
    includeByName = packs;
  };
  # nix-reshade lowercases shader file names and ReShade matches a preset's `@File.fx` and `[File.fx]` case-sensitively.
  lowercasedPreset = runCommand presetName {inherit preset;} ''
    sed -E 's/@([^,]+\.fx)/@\L\1/g; s/^\[([^]]+\.fx)\]/[\L\1]/' "$preset" >"$out"
  '';
in
  lib.throwIf (unknownPacks != [])
  "steam/reshade.nix: no shader pack named ${lib.concatStringsSep ", " unknownPacks} in nix-reshade's reshadeShaders"
  {
    files.game.place = {
      "dxgi.dll".source = "${reshadePkgs.reshade}/lib/reshade/ReShade64.dll";
      # Wine's builtin compiler can't handle the HLSL ReShade generates.
      "d3dcompiler_47.dll".source = "${reshadePkgs.d3dcompiler_47-dll}/lib/d3dcompiler_47.dll";
      "reshade-shaders".source = "${shaders}/reshade-shaders";
      # seed: ReShade rewrites both files as you tweak in its overlay.
      "ReShade.ini" = {
        text = ''
          [GENERAL]
          EffectSearchPaths=.\reshade-shaders\shaders\**
          TextureSearchPaths=.\reshade-shaders\textures\**
          PresetPath=.\${presetName}
        '';
        mode = "seed";
      };
      ${presetName} = {
        source = lowercasedPreset;
        mode = "seed";
      };
    };
    dllOverrides = {
      dxgi = "n,b";
      d3dcompiler_47 = "n";
    };
  }
