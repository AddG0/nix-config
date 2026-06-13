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
  version = "1.11847.5";
  wrapperVersion = "2.0.19";

  src = fetchurl {
    url = "https://github.com/aaddrick/claude-desktop-debian/releases/download/v${wrapperVersion}%2Bclaude${version}/claude-desktop_${version}-${wrapperVersion}_amd64.deb";
    hash = "sha256-9KhKFuzI0auKjK/wWGeCab+GscfXS+yUtF9+rzB6seU=";
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

      # Patch launcher scripts to use $out paths instead of /usr.
      # Use --replace-quiet because the set of files holding the path varies
      # across upstream versions (e.g. launcher-common.sh dropped its reference
      # in 2.0.10).
      for f in \
        "$out/bin/claude-desktop" \
        "$out/lib/claude-desktop/launcher-common.sh" \
        "$out/lib/claude-desktop/doctor.sh"; do
        [ -f "$f" ] && substituteInPlace "$f" \
          --replace-quiet '/usr/lib/claude-desktop' "$out/lib/claude-desktop"
      done

      # Fix desktop file
      substituteInPlace $out/share/applications/claude-desktop.desktop \
        --replace-fail '/usr/bin/claude-desktop' "claude-desktop"
    '';
  };
in
  buildFHSEnv {
    inherit pname version;
    passthru.updateScript = [./update.sh];
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
