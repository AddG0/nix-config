{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  webkitgtk_4_1,
  libayatana-appindicator,
  dconf,
  glib,
  gsettings-desktop-schemas,
  gtk3,
  gst_all_1,
  iw,
  wirelesstools,
  nettools,
  xdg-utils,
  iproute2,
  iptables,
  procps,
}: let
  gstPlugins = with gst_all_1; [
    gst-plugins-base # provides appsink, the element WebKit actually needs
    gst-plugins-good
  ];
  # Schema bundles that hold GTK and GNOME interface settings WebKit reads
  # via GSettings. nixpkgs convention: $out/share/gsettings-schemas/$name.
  schemaDataDirs =
    lib.concatMapStringsSep ":"
    (drv: "${drv}/share/gsettings-schemas/${drv.name}")
    [glib gsettings-desktop-schemas gtk3];
  guiPath = [iw wirelesstools nettools xdg-utils];
  # Discovery and Teleport shell out to arp/ip/iw/iptables/sysctl.
  daemonPath = [
    nettools
    iproute2
    iw
    wirelesstools
    iptables
    procps
  ];
  pname = "wifiman-desktop";
  version = "1.2.8";
in
  stdenv.mkDerivation {
    inherit pname version;

    src = fetchurl {
      url = "https://desktop.wifiman.com/wifiman-desktop-${version}-amd64.deb";
      hash = "sha256-R+MbwxfnBV9VcYWeM1NM08LX1Mz9+fy4r6uZILydlks=";
    };

    nativeBuildInputs = [
      dpkg
      autoPatchelfHook
      makeWrapper
    ];

    buildInputs = [
      webkitgtk_4_1
      libayatana-appindicator
    ];

    unpackPhase = ''
      dpkg -x $src .
    '';

    installPhase = ''
      runHook preInstall

      install -Dm755 usr/bin/wifiman-desktop $out/bin/wifiman-desktop
      install -Dm755 usr/lib/wifiman-desktop/wifiman-desktopd $out/bin/wifiman-desktopd

      # Daemon's runtime assets (loaded relative to its working directory):
      # .env, wg, wg-quick, wireguard-go, wg_report.sh.
      mkdir -p $out/libexec/wifiman-desktop
      cp -r usr/lib/wifiman-desktop/. $out/libexec/wifiman-desktop/
      rm $out/libexec/wifiman-desktop/wifiman-desktopd

      mkdir -p $out/share
      cp -r usr/share/. $out/share/

      # Upstream's .desktop is rough: Name is the kebab id, Categories is empty,
      # and Exec has no field code so xdg-open drops the wifiman-desktop-dl://
      # callback URL on the deep-link login flow.
      substituteInPlace $out/share/applications/wifiman-desktop.desktop \
        --replace-fail "Exec=wifiman-desktop"      "Exec=wifiman-desktop %u" \
        --replace-fail "Name=wifiman-desktop"      "Name=WiFiMan Desktop" \
        --replace-fail "Categories="               "Categories=Network;"

      runHook postInstall
    '';

    postFixup = ''
      wrapProgram $out/bin/wifiman-desktop \
        --prefix PATH : ${lib.makeBinPath guiPath} \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [libayatana-appindicator]} \
        --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : "${lib.concatMapStringsSep ":" (p: "${p}/lib/gstreamer-1.0") gstPlugins}" \
        --prefix GIO_EXTRA_MODULES : ${dconf.lib}/lib/gio/modules \
        --prefix XDG_DATA_DIRS : ${schemaDataDirs} \
        --set-default WEBKIT_DISABLE_DMABUF_RENDERER 1
    '';

    # The daemon binary is left unwrapped on purpose: it resolves its state
    # paths (service.json, log file) from `os.Executable()`, so it must run
    # from a writable directory. Consumers should copy it into a mutable
    # location and set PATH via the systemd unit. The runtime deps are
    # exposed here so the module doesn't have to re-list them.
    passthru = {
      nixUpdate.version = "skip"; # non-standard URL, no GitHub releases
      daemonRuntimeDeps = daemonPath;
    };

    meta = {
      description = "WiFiMan Desktop - Network scanner and speed test by Ubiquiti";
      homepage = "https://ui.com/download/app/wifiman-desktop";
      license = lib.licenses.unfree;
      platforms = ["x86_64-linux"];
      mainProgram = "wifiman-desktop";
    };
  }
