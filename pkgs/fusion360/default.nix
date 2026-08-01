# Self-owned Autodesk Fusion 360 launcher for Wine. We do not run any upstream
# installer script: the recipe (winetricks verbs, registry tweaks, DXVK) is
# distilled into ./fusion360.sh. The only vendored assets are the DXVK
# graphics-config XML and the app icon, both alongside this file.
#
# Fusion itself can't be baked into the store (proprietary, online-activated,
# non-redistributable); the first run downloads Autodesk's installer and the
# winetricks components into a mutable prefix under $HOME.
{
  lib,
  stdenvNoCC,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  p7zip,
  wineWow64Packages,
  winetricks,
  curl,
  wget,
  cabextract,
  unzip,
  samba,
  gnused,
  gnugrep,
  gawk,
  coreutils,
  findutils,
}: let
  # Wine 11.x is required on very new GPUs (RTX 5090): Fusion's Chromium UI client can't
  # init its GPU command buffer under Wine 10.x and exits.
  # X11 driver: normal look, and the 3D viewport runs on the GPU via DXVK/Vulkan. The
  # embedded Chromium panels would black out (their gl backend asks Mesa for a GL context
  # on the NVIDIA GPU and fails - the "dri2 screen" error), so launch forces GL to
  # llvmpipe software (LIBGL_ALWAYS_SOFTWARE). That only touches OpenGL, not Vulkan, so
  # the viewport stays GPU-accelerated while the panels render in software.
  # WARNING: this WoW64 build segfaulted on Fusion's first-run installers, so a fresh
  # --reinstall may fail; launching an already-deployed prefix is fine.
  wine = wineWow64Packages.stable;

  runtimeDeps = [
    wine
    winetricks
    curl
    wget
    cabextract
    unzip
    p7zip
    samba # winbind for Fusion's network auth
    gnused
    gnugrep
    gawk
    coreutils
    findutils
  ];
in
  stdenvNoCC.mkDerivation {
    pname = "fusion360";
    version = "1.0.0";

    dontUnpack = true;

    nativeBuildInputs = [makeWrapper copyDesktopItems];

    desktopItems = [
      (makeDesktopItem {
        name = "fusion360";
        desktopName = "Autodesk Fusion 360";
        comment = "Cloud-based 3D CAD/CAM/CAE (via Wine)";
        exec = "fusion360";
        icon = "fusion360";
        categories = ["Graphics" "Engineering"];
      })
    ];

    dontBuild = true;

    installPhase = ''
      runHook preInstall

      install -Dm644 ${./autodesk_fusion.svg} \
        $out/share/icons/hicolor/scalable/apps/fusion360.svg

      # Fusion graphics config: DirectX (DXVK) renderer for the 3D viewport and the
      # gl backend for the embedded Chromium panels - see configure_graphics.
      install -Dm644 ${./NMachineSpecificOptions.xml} \
        $out/share/fusion360/NMachineSpecificOptions.xml

      install -Dm755 ${./fusion360.sh} $out/libexec/fusion360/fusion360.sh
      substituteInPlace $out/libexec/fusion360/fusion360.sh \
        --replace-fail '@share@' "$out/share/fusion360"

      makeWrapper $out/libexec/fusion360/fusion360.sh $out/bin/fusion360 \
        --prefix PATH : ${lib.makeBinPath runtimeDeps}

      runHook postInstall
    '';

    passthru.nixUpdate.version = "skip"; # pins a git rev, no release tags

    meta = {
      description = "Autodesk Fusion 360 on Linux via Wine (self-contained recipe)";
      longDescription = ''
        Runs Autodesk Fusion 360 under Wine. The first invocation builds a Wine
        prefix under $HOME and installs Fusion (downloads several GB from
        Autodesk); later invocations launch it. The Wine build is pinned by the
        package.
      '';
      homepage = "https://github.com/cryinkfly/Autodesk-Fusion-360-for-Linux";
      # The recipe is MIT; Fusion 360 itself is proprietary.
      license = with lib.licenses; [mit unfree];
      platforms = ["x86_64-linux"];
      mainProgram = "fusion360";
    };
  }
