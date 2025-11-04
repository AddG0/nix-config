{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  qt6,
  openssl,
  libpulseaudio,
  pulseaudio,
  python3,
  bluez,
  makeWrapper,
}:
stdenv.mkDerivation rec {
  pname = "librepods";
  version = "0.1.0-rc.4";

  src = fetchFromGitHub {
    owner = "kavishdevar";
    repo = "librepods";
    rev = "v${version}";
    hash = "sha256-FnDYQ3EPx2hpeCCZvbf5PJo+KCj+YO+DNg+++UpZ7Xs=";
  };

  # We only want to build the Linux desktop app, not Android components
  sourceRoot = "${src.name}/linux";

  patches = [
    ./patches/fix-pipewire-sink-detection.patch
  ];

  patchFlags = [ "-p0" ];

  nativeBuildInputs = [
    cmake
    pkg-config
    qt6.wrapQtAppsHook
    makeWrapper
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtconnectivity
    qt6.qtmultimedia
    openssl
    libpulseaudio
    python3
    bluez
  ];

  runtimeDeps = [
    bluez       # bluetoothctl
    pulseaudio  # pactl
  ];

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
  ];

  postInstall = ''
    # Install icon from source assets
    mkdir -p $out/share/pixmaps
    cp ../assets/airpods.png $out/share/pixmaps/librepods.png

    # Create desktop file since the CMake one expects assets we might not have
    mkdir -p $out/share/applications
    cat > $out/share/applications/me.kavishdevar.librepods.desktop <<EOF
[Desktop Entry]
Type=Application
Name=LibrePods
Comment=AirPods liberated from Apple's ecosystem
Exec=librepods
Icon=librepods
Terminal=false
Categories=Audio;AudioVideo;Utility;Qt;
StartupWMClass=librepods
EOF
  '';

  postFixup = ''
    # Rename binary from applinux to librepods (after Qt wrapping)
    if [ -f $out/bin/.applinux-wrapped ]; then
      mv $out/bin/.applinux-wrapped $out/bin/.librepods-wrapped
    fi
    if [ -f $out/bin/applinux ]; then
      # Save the wrapper content and update the wrapped binary path
      sed 's|\.applinux-wrapped|.librepods-wrapped|g' $out/bin/applinux > $out/bin/librepods
      chmod +x $out/bin/librepods
      rm $out/bin/applinux
    fi

    # Add bluetoothctl and pactl to PATH for runtime
    wrapProgram $out/bin/.librepods-wrapped \
      --prefix PATH : ${lib.makeBinPath runtimeDeps}
  '';

  meta = with lib; {
    description = "AirPods desktop user experience enhancement program for Linux";
    longDescription = ''
      LibrePods brings AirPods features to Linux including:
      - Battery monitoring
      - Automatic ear detection
      - Conversational awareness
      - Switching noise control modes
      - Device renaming
    '';
    homepage = "https://github.com/kavishdevar/librepods";
    license = licenses.agpl3Only;
    platforms = platforms.linux;
    mainProgram = "librepods";
    maintainers = with maintainers; [ ];
  };
}
