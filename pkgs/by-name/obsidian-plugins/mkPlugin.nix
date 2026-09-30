# Plugins are published as three loose release assets, never an archive, and
# home-manager reads manifest.json from $out's root to derive the plugin id.
{
  lib,
  stdenvNoCC,
  fetchurl,
}: {
  pname,
  version,
  repo,
  hashes,
  meta,
  postInstall ? "",
}:
stdenvNoCC.mkDerivation {
  inherit pname version meta postInstall;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (
        file: hash: "cp ${fetchurl {
          url = "https://github.com/${repo}/releases/download/${version}/${file}";
          inherit hash;
        }} $out/${file}"
      )
      hashes)}
    chmod -R u+w $out
    runHook postInstall
  '';
}
