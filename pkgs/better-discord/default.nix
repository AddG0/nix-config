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
      rev = version;
      sha256 = "sha256-oKXNw8vD8xRje07XRoAIdWNYC0mJJS/0lWB/OT9HnwQ="; # Replace with actual hash
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
