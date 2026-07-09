# Bake a list of addons into a copy of the panel. Each addon's `install` runs
# with the panel tree as CWD and its source at $src; `needsAssetBuild` triggers
# a webpack rebuild (for addons that change front-end source, not prebuilt ones).
{
  pkgs,
  lib,
}: {
  panel,
  addons,
}: let
  appRoot = "${panel}/share/php/pterodactyl-panel";
  needsBuild = lib.any (a: a.needsAssetBuild or false) addons;

  offlineDeps = pkgs.fetchYarnDeps {
    yarnLock = "${appRoot}/yarn.lock";
    hash = "sha256-OvoTRw66wi3zLeWUpWGHIbYFYqSYrlEOEUYJ1Hg0ApM=";
  };
in
  pkgs.stdenvNoCC.mkDerivation {
    pname = "pterodactyl-panel-addons";
    inherit (panel) version;
    dontUnpack = true;

    nativeBuildInputs =
      [pkgs.unzip]
      ++ lib.optionals needsBuild [pkgs.nodejs pkgs.yarn pkgs.fixup-yarn-lock];

    buildPhase = ''
      runHook preBuild
      export HOME=$(mktemp -d)
      cp -r ${appRoot} ./panel
      chmod -R u+w ./panel

      # Subshell so per-addon installs run with the panel tree as CWD without
      # disturbing the build root for installPhase.
      (
        cd ./panel
        ${lib.concatMapStringsSep "\n" (a: ''
          echo "[+] Installing addon ${a.name}..."
          ( export src="${a.source}"; ${a.install} )
        '')
        addons}

        ${lib.optionalString needsBuild ''
        echo "[+] Rebuilding front-end assets..."
        yarn config --offline set yarn-offline-mirror ${offlineDeps}
        fixup-yarn-lock yarn.lock
        yarn install --offline --frozen-lockfile --ignore-scripts --no-progress
        patchShebangs node_modules
        export NODE_OPTIONS="--max-old-space-size=4096 --openssl-legacy-provider"
        NODE_ENV=production ./node_modules/.bin/webpack --mode production
        rm -rf node_modules
      ''}
      )
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/php/pterodactyl-panel
      cp -r ./panel/. $out/share/php/pterodactyl-panel/
      runHook postInstall
    '';

    meta = panel.meta // {description = "Pterodactyl panel with addons baked in";};
  }
