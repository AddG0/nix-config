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
      sqry = "sha256-s7m8m3NzVckt9ahZ8aHpF3as6MUERoBGUTIw40a+J98=";
      sqry-mcp = "sha256-1EatFfxSrLt8fp++YLah1BBNoHx0B17qWZoNivT++ww=";
    };
    arm64 = {
      sqry = "sha256-cGN4ZBZhzthiKYoHa2xY1xXJNFG7TZ3jNuIvjkqXBfs=";
      sqry-mcp = "sha256-jwciMvREEW8lHtsOAMSthmVyXB0AE0GbTY6+mGj3UYs=";
    };
  };

  fetchBin = name:
    fetchurl {
      url = "https://github.com/verivus-oss/sqry/releases/download/v${finalAttrs.version}/${name}-linux-${arch}-musl";
      hash = hashes.${arch}.${name};
    };
in {
  pname = "sqry";
  version = "31.0.0";

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
