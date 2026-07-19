# Builder for plugins from the Decky store. The store CDN is content-addressed
# (URL keyed on the artifact's sha256), so `hash` doubles as the URL and the
# fetchurl integrity check — grab it from
# https://plugins.deckbrew.xyz/plugins (`.versions[0].hash`).
{
  stdenvNoCC,
  fetchurl,
  unzip,
}: {
  pname,
  version,
  hash,
  meta ? {},
}:
stdenvNoCC.mkDerivation {
  inherit pname version meta;

  src = fetchurl {
    url = "https://cdn.tzatzikiweeb.moe/file/steam-deck-homebrew/versions/${hash}.zip";
    sha256 = hash;
  };

  nativeBuildInputs = [unzip];
  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;

  # Store zips wrap contents in one top-level dir; land plugin.json at $out root.
  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    if [ -f plugin.json ]; then
      cp -rT . "$out"
    else
      cp -rT "$(ls -d */ | head -1)" "$out"
    fi
    runHook postInstall
  '';
}
