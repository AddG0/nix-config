# Userspace access to the same vendor HID protocol as razer-battery-care: fan
# and perf modes, and a second opinion when the driver and the desktop disagree.
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  udev,
}:
rustPlatform.buildRustPackage {
  pname = "razer-cli";
  version = "0.6.0-unstable-2024-12-02";

  src = fetchFromGitHub {
    owner = "tdakhran";
    repo = "razer-ctl";
    rev = "8e12e778d303d4ed01eeb2c1e99ce2e97f1c8917";
    hash = "sha256-tJy/G9g8RzOVqJw4A3l44PkZZMZ7mDP0WbGWTlrjBQ0=";
  };

  # Upstream commits a lockfile, so vendor from it rather than carrying a hash.
  cargoLock.lockFile = ./Cargo.lock;

  # razer-tray is a system-tray GUI for the same library; only the CLI is wanted.
  cargoBuildFlags = ["--package" "razer-cli"];
  cargoTestFlags = ["--package" "razer-cli"];

  # hidapi builds its vendored C against libudev for the hidraw backend.
  nativeBuildInputs = [pkg-config];
  buildInputs = [udev];

  meta = {
    description = "Command-line control for Razer Blade laptops over vendor HID";
    homepage = "https://github.com/tdakhran/razer-ctl";
    license = lib.licenses.mit;
    mainProgram = "razer-cli";
    platforms = lib.platforms.linux;
  };
}
