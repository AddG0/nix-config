# Unlike the rest of pkgs/decky this is source in-tree, not a store artifact:
# it drives gamescope-set-display, which only exists in this config.
{
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation {
  pname = "gamescope-display";
  version = "1.0.0";

  src = ./.;

  dontConfigure = true;
  dontBuild = true;

  # Nothing to build: index.js is the frontend as decky loads it. It sits at the
  # root because a global gitignore rule would keep a tracked dist/ out of the
  # flake source.
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/dist"
    cp plugin.json package.json main.py "$out/"
    cp index.js "$out/dist/index.js"
    runHook postInstall
  '';

  # In-tree source: no upstream release to track.
  passthru.nixUpdate.version = "skip";

  meta = {
    description = "Choose which monitor the gamescope session runs on, from the Quick Access menu";
    license = lib.licenses.mit;
    platforms = ["x86_64-linux"];
  };
}
