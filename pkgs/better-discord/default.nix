{
  lib,
  stdenv,
  fetchFromGitHub,
  cacert,
  nodejs,
  nodePackages,
}: let
  pname = "better-discord";
  version = "canary";
in
  stdenv.mkDerivation {
    inherit pname version;

    src = fetchFromGitHub {
      owner = "BetterDiscord";
      repo = "BetterDiscord";
      rev = "eb367a0a3bd4a2147281584e80f8a037b575d73a";
      sha256 = "sha256-I50gpLYdtU2q+rBKzrAdd0mXh9ABh6mzJR8WDfc4oDY=";
    };

    nativeBuildInputs = [
      nodejs
      nodePackages.pnpm
      cacert
    ];

    buildPhase = ''
      # Install dependencies
      export HOME=$TMPDIR
      export NODE_EXTRA_CA_CERTS=${cacert}/etc/ssl/certs/ca-bundle.crt  # Explicitly set CA path
      pnpm install

      # Build BetterDiscord
      pnpm build
    '';

    installPhase = ''
      mkdir -p $out/lib/better-discord
      cp -r . $out/lib/better-discord/  # Copy everything to preserve scripts/inject.js
      cp -r node_modules $out/lib/better-discord/  # Ensure dependencies are there
    '';

    meta = with lib; {
      description = "A client modification for Discord";
      homepage = "https://github.com/BetterDiscord/BetterDiscord";
      license = licenses.mit;
      platforms = platforms.all;
    };
  }
