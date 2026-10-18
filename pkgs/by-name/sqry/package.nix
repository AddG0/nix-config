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
      sqry = "sha256-XszKFLDuGUoM/cptYVxfltCoG8hZ3BJmiIljsmFH5us=";
      sqry-mcp = "sha256-th4a9MSYGyA93XHg7of/b1b01QzofUcmL9eFhwT00ZQ=";
    };
    arm64 = {
      sqry = "sha256-RZV8qaZ61uTb26DnvKswxAYOnycv8L2d9mqboNBoUlY=";
      sqry-mcp = "sha256-Gxs//xTwMfbl0naOp+Mw6S/gyKSYzeQ3ZsTP3dj13hc=";
    };
  };

  fetchBin = name:
    fetchurl {
      url = "https://github.com/verivus-oss/sqry/releases/download/v${finalAttrs.version}/${name}-linux-${arch}-musl";
      hash = hashes.${arch}.${name};
    };
in {
  pname = "sqry";
  version = "33.0.1";

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
