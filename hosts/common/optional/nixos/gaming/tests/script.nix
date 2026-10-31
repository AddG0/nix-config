# The shared-library placer: places declared game files, restores a file the game shipped, and an empty list reverts.
{
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
  pkgs.runCommand "steam-library-files" {} ''
    fail() { echo "FAIL: $*" >&2; exit 1; }
    export XDG_DATA_HOME=$PWD/state
    library=$PWD/library game=$PWD/library/steamapps/common/Game
    mkdir -p "$game"
    printf '"AppState"\n{\n\t"appid"\t\t"10"\n\t"installdir"\t\t"Game"\n}\n' >"$library/steamapps/appmanifest_10.acf"
    echo shipped >"$game/dxgi.dll"

    ${place} "$library" ${declared} || fail "placing the declared files failed"
    [ "$(cat "$game/dxgi.dll")" = reshade ] || fail "declared dxgi.dll not placed over the shipped one"
    [ -f "$game/reshade-shaders/sweetfx/dpx.fx" ] || fail "declared shader directory not placed"
    [ "$(stat -c %a "$game/Look.ini")" = 664 ] || fail "seed file not group-writable for the player: $(stat -c %a "$game/Look.ini")"
    [ "$(stat -c %a "$game/dxgi.dll")" = 644 ] || fail "enforce file mode changed: $(stat -c %a "$game/dxgi.dll")"

    ${place} "$library" ${declared} || fail "a second run with the same list failed"
    [ "$(cat "$game/dxgi.dll")" = reshade ] || fail "a rerun changed a placed file"

    ${place} "$library" ${nothing} || fail "reverting with an empty list failed"
    [ "$(cat "$game/dxgi.dll")" = shipped ] || fail "the game's own dxgi.dll was not restored: $(cat "$game/dxgi.dll")"
    [ ! -e "$game/reshade-shaders/sweetfx/dpx.fx" ] || fail "placed shader left behind after its removal from the list"

    rm -rf "$game" && mkdir -p "$game"
    ${place} "$library" ${declared} || fail "placing into a reinstalled game failed"
    [ "$(cat "$game/dxgi.dll")" = reshade ] || fail "a reinstalled game did not get its files back"

    if ${place} "$library" ${unplaceable} 2>err; then fail "a file that could not be placed exited 0"; fi
    grep -q "library-files: " err || fail "the failure was not reported on stderr: $(cat err)"

    touch "$out"
  ''
