# RLBotServer: the v5 framework's match server.
#
# Framework-dependent .NET build, so the binary is just the apphost and needs
# DOTNET_ROOT. It also starts Rocket League with a bare `proton run`, outside
# Steam's pressure-vessel container; every Proton build is generic-linux, so that
# exec needs an FHS. steam-run supplies one and child processes inherit it.
{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  autoPatchelfHook,
  dotnet-runtime_10,
  steam-run,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "rlbot-server";
  version = "5.0.0-rc17";

  src = fetchurl {
    url = "https://github.com/RLBot/core/releases/download/v${finalAttrs.version}/RLBotServer";
    hash = "sha256-bs9JBed32qTRwL0J6YK8NEkIPBaXeJQL51L/I7P6EVQ=";
  };

  dontUnpack = true;

  # Only libm/libc are NEEDED; autoPatchelf just fixes the interpreter.
  nativeBuildInputs = [makeWrapper autoPatchelfHook];

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/libexec/RLBotServer"

    makeWrapper ${lib.getExe steam-run} "$out/bin/RLBotServer" \
      --add-flags "$out/libexec/RLBotServer" \
      --set-default DOTNET_ROOT ${dotnet-runtime_10}

    runHook postInstall
  '';

  meta = {
    description = "Server component of the RLBot v5 framework";
    homepage = "https://github.com/RLBot/core";
    license = lib.licenses.mit;
    platforms = ["x86_64-linux"];
    mainProgram = "RLBotServer";
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };

  # Upstream tags releases as vX.Y.Z-rcN, which nix-update treats as unstable.
  passthru.nixUpdate.version = "unstable";
})
