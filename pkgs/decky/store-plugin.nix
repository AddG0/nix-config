# Builder for plugins from the Decky store. The store CDN is content-addressed
# (URL keyed on the artifact's sha256), so `hash` doubles as the URL and the
# fetchurl integrity check — grab it from
# https://plugins.deckbrew.xyz/plugins (`.versions[0].hash`).
{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
  writeShellApplication,
  curl,
  jq,
  git,
  gawk,
}: {
  pname,
  version,
  hash,
  storeName, # the store's display name (deckbrew `.name`), for updates
  meta ? {},
}: let
  updateScript = writeShellApplication {
    name = "decky-store-update";
    runtimeInputs = [curl jq git gawk];
    # Strip the shebang; writeShellApplication supplies its own + set -euo.
    text = lib.removePrefix "#!/usr/bin/env bash\n" (builtins.readFile ./update.sh);
  };
in
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

    # nix-update can't read the deckbrew store; this pulls version+hash from it.
    passthru.updateScript = [(lib.getExe updateScript) storeName pname];
  }
