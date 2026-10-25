{
  lib,
  buildGoModule,
  fetchFromGitHub,
  pkg-config,
  wayland,
  libpng,
}:
buildGoModule rec {
  pname = "wlcrosshair";
  version = "1.2";

  src = fetchFromGitHub {
    owner = "marzeq";
    repo = "wlcrosshair";
    rev = version;
    hash = "sha256-bNhhocLX88AsTqjEIDXk7AdA1lcsWOVwQ6tPpIMlGAM=";
  };

  vendorHash = "sha256-CVycV7wxo7nOHm7qjZKfJrIkNcIApUNzN1mSIIwQN0g=";

  # Anchored to all four edges, niri configures the surface to the whole output and the image
  # is stretched to fill it.
  patches = [./no-anchor.patch];

  nativeBuildInputs = [pkg-config];
  buildInputs = [wayland libpng];

  subPackages = [
    "cmd/wlcrosshair"
    "cmd/wlcrosshairctl"
  ];

  postInstall = ''
    mkdir -p $out/share/wlcrosshair/samples
    cp -r sample_crosshairs/. $out/share/wlcrosshair/samples/
  '';

  passthru.nixUpdate.version = "skip";

  meta = with lib; {
    description = "Simple crosshair overlay for Wayland (layer-shell)";
    homepage = "https://github.com/marzeq/wlcrosshair";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "wlcrosshair";
  };
}
