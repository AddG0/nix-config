# Smoke-test: WP_DIR=<folder of images> nix run .#wallpaper-picker-mac
# Other env: WP_BG / WP_FG / WP_BORDER / WP_ACCENT (#rrggbb).
{
  lib,
  stdenv,
  swift,
}:
stdenv.mkDerivation {
  pname = "wallpaper-picker-mac";
  version = "0.1.0";

  src = ./.;

  # Local package: src = ./. has no upstream URL for nix-update to bump.
  passthru.nixUpdate.version = "skip";

  nativeBuildInputs = [swift];

  buildPhase = ''
    runHook preBuild
    swiftc -O -o wallpaper-picker Logic.swift main.swift
    runHook postBuild
  '';

  # Layout and matching logic only; the window itself is not covered.
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    swiftc -o logic-tests Logic.swift tests/main.swift
    ./logic-tests
    runHook postCheck
  '';

  # A bundle so the window carries a bundle id OmniWM can float it by.
  installPhase = ''
    runHook preInstall
    app=$out/Applications/WallpaperPicker.app/Contents
    install -Dm755 wallpaper-picker $app/MacOS/wallpaper-picker
    cat > $app/Info.plist <<EOF
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict>
      <key>CFBundleIdentifier</key><string>local.wallpaper-picker</string>
      <key>CFBundleName</key><string>WallpaperPicker</string>
      <key>CFBundleExecutable</key><string>wallpaper-picker</string>
      <key>CFBundlePackageType</key><string>APPL</string>
      <key>LSUIElement</key><true/>
    </dict></plist>
    EOF
    mkdir -p $out/bin
    ln -s $app/MacOS/wallpaper-picker $out/bin/wallpaper-picker
    runHook postInstall
  '';

  meta = {
    description = "Thumbnail wallpaper picker for macOS";
    mainProgram = "wallpaper-picker";
    platforms = lib.platforms.darwin;
  };
}
