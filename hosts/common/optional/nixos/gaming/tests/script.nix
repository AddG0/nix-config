# The shared-library placer: places declared game files, restores a file the game shipped, and an empty list reverts; ./library-files.bats.
{
  harness,
  pkgs,
  self,
  ...
}: let
  patcher = pkgs.python3Packages.toPythonModule (
    pkgs.python3Packages.callPackage "${self.inputs.steam-config-nix}/pkgs/steam-config-patcher/package.nix" {}
  );
  place = pkgs.writers.writePython3 "library-files" {
    libraries = [patcher];
    flakeIgnore = ["E501"];
  } (builtins.readFile ../library-files.py);

  op = target: source: {
    appId = 10;
    inherit target;
    source = "${source}";
    mode = "enforce";
    executable = null;
  };
  reshade = pkgs.writeText "dxgi.dll" "reshade";
  shaders = pkgs.writeTextDir "sweetfx/dpx.fx" "technique DPX {}";
  preset = pkgs.writeText "Look.ini" "Techniques=DPX@dpx.fx";
  declared = pkgs.writeText "ops.json" (builtins.toJSON [
    (op "dxgi.dll" reshade)
    (op "reshade-shaders" shaders)
    ((op "Look.ini" preset) // {mode = "seed";})
  ]);
  nothing = pkgs.writeText "ops.json" "[]";
  # A source that isn't there makes apply_file_ops report a failure, which systemd must see.
  unplaceable = pkgs.writeText "ops.json" (builtins.toJSON [(op "missing.dll" "/nonexistent/missing.dll")]);
in
  harness.bats "steam-library-files" [./library-files.bats] {
    place = "${place}";
    inherit declared nothing unplaceable;
  }
