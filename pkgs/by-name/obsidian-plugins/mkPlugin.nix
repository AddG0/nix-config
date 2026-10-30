# Plugins are published as three loose release assets, never an archive. `manifestId` spares
# home-manager reading manifest.json at eval time, which forces a build for the target platform.
{
  lib,
  stdenvNoCC,
  fetchurl,
  writeShellApplication,
  curl,
  jq,
  openssl,
}: args @ {
  pname,
  version,
  repo,
  hashes,
  manifestId,
  meta,
  postInstall ? "",
  passthru ? {},
}: let
  updateScript = writeShellApplication {
    name = "obsidian-plugin-update";
    runtimeInputs = [curl jq openssl];
    text = builtins.readFile ./update.sh;
  };
in
  stdenvNoCC.mkDerivation {
    inherit pname version meta postInstall;

    passthru =
      passthru
      // {
        inherit manifestId;
        updateScript = [(lib.getExe updateScript) pname repo (builtins.unsafeGetAttrPos "version" args).file];
      };

    dontUnpack = true;
    nativeBuildInputs = [jq];

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
      id=$(jq -r .id $out/manifest.json)
      if [ "$id" != ${lib.escapeShellArg manifestId} ]; then
        echo "${pname}: manifestId is ${lib.escapeShellArg manifestId} but manifest.json says $id" >&2
        exit 1
      fi
      runHook postInstall
    '';
  }
