# Generic: bake the Blueprint framework + extensions into a copy of the panel.
#
# Blueprint's installer wants a live DB and runs its own yarn — neither of which
# belongs in a pure build. So yarn + `php artisan` are stubbed during the
# blueprint run (it then only merges files); DB migrations are deferred to the
# runtime setup service, and the front-end is rebuilt explicitly afterwards.
#
# NOTE: the `blueprint` package must be front-end compatible with this panel
# version — Blueprint's webpack build runs ForkTsCheckerWebpackPlugin, so a
# mismatch fails the asset build with TSxxxx errors. Each extension's `name`
# must be its conf.yml identifier (what `blueprint.sh <id> -install` expects).
{
  pkgs,
  lib,
}: {
  panel,
  blueprint,
  extensions,
}: let
  appRoot = "${panel}/share/php/pterodactyl-panel";

  # Blueprint ships a pre-merged panel+blueprint yarn.lock (a superset of the
  # panel's); the mirror must come from it since we merge Blueprint in first.
  offlineDeps = pkgs.fetchYarnDeps {
    yarnLock = "${blueprint}/libexec/blueprint/yarn.lock";
    hash = "sha256-J4U9Mcs+SIYku3AKbtMMjqugqMOVBHGMJ6nt3kSIg28=";
  };

  yarnStub = pkgs.writeShellScriptBin "yarn" ''
    echo "[build-stub] skipping blueprint-invoked: yarn $*" >&2
    exit 0
  '';
  phpStub = pkgs.writeShellScriptBin "php" ''
    case " $* " in
      *" artisan "*) echo "[build-stub] skipping: php $*" >&2; exit 0 ;;
    esac
    exec ${pkgs.php83}/bin/php "$@"
  '';
in
  pkgs.stdenvNoCC.mkDerivation {
    pname = "pterodactyl-panel-blueprint";
    inherit (panel) version;
    dontUnpack = true;

    # unzip/zip/curl/git/ncurses(tput) satisfy Blueprint's dependency check.
    nativeBuildInputs = with pkgs; [nodejs yarn fixup-yarn-lock unzip zip curl git ncurses];

    buildPhase = ''
      runHook preBuild
      export HOME=$(mktemp -d)
      cp -r ${appRoot} ./panel
      chmod -R u+w ./panel
      cp -r ${blueprint}/libexec/blueprint/. ./panel/

      (
        cd ./panel
        cat > .blueprintrc <<EOF
        WEBUSER="pterodactyl"
        OWNERSHIP="pterodactyl:pterodactyl"
        USERSHELL="/bin/sh"
        EOF

        # Blueprint's dependency check needs a populated node_modules first.
        yarn config --offline set yarn-offline-mirror ${offlineDeps}
        fixup-yarn-lock yarn.lock
        yarn install --offline --frozen-lockfile --ignore-scripts --no-progress
        patchShebangs node_modules
        # Blueprint's webpack predates OpenSSL 3 (md4) → legacy provider on Node 17+.
        export NODE_OPTIONS="--max-old-space-size=4096 --openssl-legacy-provider"
        export PATH="$PWD/node_modules/.bin:$PATH"

        # Stubbed yarn/php make these blueprint runs merge files only.
        echo "[+] Bootstrapping Blueprint framework..."
        PATH="${yarnStub}/bin:${phpStub}/bin:$PATH" TERM=dumb bash ./blueprint.sh || true
        ${lib.concatMapStringsSep "\n" (e: ''
          echo "[+] Installing extension ${e.name}..."
          cp "${e.source}" "./${e.name}.blueprint"
          PATH="${yarnStub}/bin:${phpStub}/bin:$PATH" TERM=dumb bash ./blueprint.sh "${e.name}" -install || true
        '')
        extensions}

        echo "[+] Building front-end assets..."
        ( cd public/assets && find . \( -name "*.js" -o -name "*.map" \) -type f -delete )
        NODE_ENV=production ./node_modules/.bin/webpack --mode production

        rm -rf node_modules .blueprintrc yarn-error.log
      )
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/php/pterodactyl-panel
      cp -r ./panel/. $out/share/php/pterodactyl-panel/
      runHook postInstall
    '';

    meta = panel.meta // {description = "Pterodactyl panel with Blueprint + extensions baked in";};
  }
