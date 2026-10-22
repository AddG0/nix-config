# Upstream CoreDNS Helm chart, rendered at build time by the k3s coredns addon.
{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "coredns-helm-chart";
  version = "1.49.0";

  src = fetchurl {
    url = "https://github.com/coredns/helm/releases/download/coredns-${finalAttrs.version}/coredns-${finalAttrs.version}.tgz";
    hash = "sha256-OU+XLZr+sKWmxCVSj2HJi8m85rDm2XmKpqs6lUxnIIQ=";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    cp $src $out
    runHook postInstall
  '';

  passthru.updateScript = ["nix-update" "--flake" "coredns-helm-chart" "--version-regex" "coredns-(.*)"];

  meta = {
    description = "CoreDNS Helm chart";
    homepage = "https://github.com/coredns/helm";
    license = lib.licenses.asl20;
    platforms = lib.platforms.all;
  };
})
