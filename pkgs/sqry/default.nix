{
  lib,
  stdenvNoCC,
  fetchurl,
}:
# The musl release binaries are fully static, so no autoPatchelf.
stdenvNoCC.mkDerivation (finalAttrs: let
  arches = {
    x86_64-linux = "x86_64";
    aarch64-linux = "arm64";
  };
  arch = arches.${stdenvNoCC.hostPlatform.system} or (throw "sqry: no published build for ${stdenvNoCC.hostPlatform.system}");

  hashes = {
    x86_64 = {
      sqry = "sha256-qmi045Btbr8/wOqj+Xy3cTeJkVFGw1C/yn+NaqB4zhs=";
      sqry-mcp = "sha256-SV/1sQYT/YVkUj+eaYF6HXXrgJz1Q+aBh90xDQLvopc=";
    };
    arm64 = {
      sqry = "sha256-pfjzUeeQwgJ0PPd6xYbJN3xgTbWDtZCiVe7biD1yzBQ=";
      sqry-mcp = "sha256-zOfLLhJGtTmEwvs8iWrCZPadUVFc+wyzXknO1n9lzPU=";
    };
  };

  fetchBin = name:
    fetchurl {
      url = "https://github.com/verivus-oss/sqry/releases/download/v${finalAttrs.version}/${name}-linux-${arch}-musl";
      hash = hashes.${arch}.${name};
    };
in {
  pname = "sqry";
  version = "30.0.1";

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 ${fetchBin "sqry"} $out/bin/sqry
    install -Dm755 ${fetchBin "sqry-mcp"} $out/bin/sqry-mcp
    runHook postInstall
  '';

  # Prebuilt binaries, so there is no `src` for nix-update to follow.
  passthru.updateScript = [./update.sh];

  meta = {
    description = "Structural semantic code search over ASTs";
    homepage = "https://sqry.dev";
    license = lib.licenses.mit;
    platforms = builtins.attrNames arches;
    mainProgram = "sqry";
  };
})
