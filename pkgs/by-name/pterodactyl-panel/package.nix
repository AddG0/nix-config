{
  php83,
  fetchurl,
  lib,
}:
# Built from the upstream release tarball (not the git source): the release
# ships pre-compiled front-end assets under public/assets and a composer.lock,
# but no vendor/ — so this only has to resolve PHP deps, no yarn build.
# Resolved with php83 to satisfy the panel's "^8.2 || ^8.3" constraint; the
# vendor is pure PHP, so php-fpm may run it on a different 8.x at runtime.
php83.buildComposerProject (finalAttrs: {
  pname = "pterodactyl-panel";
  version = "1.15.1";

  src = fetchurl {
    url = "https://github.com/pterodactyl/panel/releases/download/v${finalAttrs.version}/panel.tar.gz";
    hash = "sha256-YsiMA1s+Dzw93Qa8PvEiSdCHrw52X0mHi2MnoGbthgs=";
  };

  # Release tarball unpacks its files at the top level (no wrapping directory).
  sourceRoot = ".";

  # Let the (read-only store) app load its .env from a writable state dir,
  # mirroring the APP_STORAGE_PATH hook the panel already ships.
  postPatch = ''
    substituteInPlace bootstrap/app.php \
      --replace-fail "if (isset(\$_ENV['APP_STORAGE_PATH'])) {" "if (isset(\$_ENV['APP_ENV_PATH'])) {
        \$app->useEnvironmentPath(\$_ENV['APP_ENV_PATH']);
    }

    if (isset(\$_ENV['APP_STORAGE_PATH'])) {"
  '';

  vendorHash = "sha256-kjx6ZJtk0VfYzKw0QuH3u7L+9PScYbAjOoT4LBtQgVA=";

  # php83.buildComposerProject (v1) builds an internal composer-repository
  # derivation via mkComposerRepository, but doesn't forward sourceRoot to
  # it — so it hits the same "unpacker produced multiple directories" issue
  # on this flat tarball. Build it explicitly, passing sourceRoot through.
  composerRepository = php83.mkComposerRepository {
    inherit (finalAttrs) pname version src vendorHash;
    sourceRoot = ".";
    composerNoDev = true;
    composerNoPlugins = true;
    composerNoScripts = true;
    composerStrictValidation = true;
  };

  passthru.updateScript = [./update.sh];

  meta = {
    description = "Pterodactyl game server management panel";
    homepage = "https://pterodactyl.io";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
})
