{
  stdenvNoCC,
  fetchurl,
  dpkg,
  buildFHSEnv,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  docker,
  expat,
  glib,
  glibc,
  gtk3,
  libgbm,
  libxkbcommon,
  nodejs,
  nspr,
  nss,
  openssl,
  pango,
  systemdLibs,
  uv,
  libx11,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
  libxcb,
}: let
  pname = "claude-desktop";
  version = "1.1.7714";

  src = fetchurl {
    url = "https://github.com/aaddrick/claude-desktop-debian/releases/download/v1.3.23%2Bclaude${version}/claude-desktop_${version}-1.3.23_amd64.deb";
    hash = "sha256-ZJ1m2kUL+pctEXgHjFyEKAbX/cJV4w4aELS0FneoyfY=";
  };

  unwrapped = stdenvNoCC.mkDerivation {
    inherit pname version src;

    nativeBuildInputs = [dpkg];

    unpackPhase = ''
      dpkg-deb -x $src .
    '';

    installPhase = ''
      mkdir -p $out
      cp -r usr/* $out/

      # Patch launcher script to use $out paths instead of /usr
      substituteInPlace $out/bin/claude-desktop \
        --replace-fail '/usr/lib/claude-desktop' "$out/lib/claude-desktop"

      substituteInPlace $out/lib/claude-desktop/launcher-common.sh \
        --replace-fail '/usr/lib/claude-desktop' "$out/lib/claude-desktop"

      # Fix desktop file
      substituteInPlace $out/share/applications/claude-desktop.desktop \
        --replace-fail '/usr/bin/claude-desktop' "claude-desktop"
    '';
  };
in
  buildFHSEnv {
    name = pname;
    targetPkgs = _: [
      unwrapped
      alsa-lib
      at-spi2-atk
      at-spi2-core
      cairo
      cups
      dbus
      docker
      expat
      glib
      glibc
      gtk3
      libgbm
      libxkbcommon
      nodejs
      nspr
      nss
      openssl
      pango
      systemdLibs
      uv
      libx11
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxrandr
      libxcb
    ];
    profile = ''
      # Use native Wayland backend — fixes overlay popup rendering on Hyprland
      export CLAUDE_USE_WAYLAND=1
    '';
    runScript = "${unwrapped}/bin/claude-desktop";
    extraInstallCommands = ''
      mkdir -p $out/share
      cp -r ${unwrapped}/share/applications $out/share/
      cp -r ${unwrapped}/share/icons $out/share/
    '';
    meta = {
      description = "Claude Desktop for Linux";
      mainProgram = pname;
    };
  }
