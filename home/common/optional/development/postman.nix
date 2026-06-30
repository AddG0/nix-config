{
  pkgs,
  lib,
  ...
}: let
  # Can't null-route dl.pstmn.io system-wide: nixpkgs fetches the postman tarball
  # from it too. Postman is Electron, so scope the DNS override to this process
  # via Chromium's internal resolver, leaving the system resolver untouched.
  blockedHosts = [
    "dl.pstmn.io"
    "updates.getpostman.com"
    "postman-electron-updates.s3.amazonaws.com"
  ];
  resolverRules = lib.concatMapStringsSep "," (h: "MAP ${h} 0.0.0.0") blockedHosts;

  postman = pkgs.symlinkJoin {
    name = "postman-no-update-${pkgs.postman.version}";
    paths = [pkgs.postman];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/postman \
        --add-flags "--host-resolver-rules='${resolverRules}'"
    '';
  };
in {
  # On Darwin, Postman is managed via homebrew cask for stable path (avoids
  # SMAppService re-registration popups on every nix store path change)
  home.packages = lib.optionals pkgs.stdenv.isLinux [postman];
}
