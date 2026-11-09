# Legcord with Discord branding (binary alias + Discord icons/desktop entry).
_: _final: prev: {
  discord-legcord = prev.stdenv.mkDerivation {
    pname = "discord-legcord";
    inherit (prev.legcord) version;

    dontUnpack = true;

    nativeBuildInputs = [prev.copyDesktopItems];

    # Named legcord to match the Icon=legcord icons copied below.
    desktopItems = [
      (prev.makeDesktopItem {
        name = "legcord";
        desktopName = "Discord";
        comment = "All-in-one voice and text chat for gamers";
        exec = "legcord";
        icon = "legcord";
        categories = ["Network" "InstantMessaging"];
        startupWMClass = "legcord";
      })
    ];

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin $out/share/icons/hicolor

      ln -s "${prev.legcord}/bin/legcord" "$out/bin/legcord"
      ln -s "$out/bin/legcord" "$out/bin/discord"

      # Discord icons as legcord.png so Icon=legcord resolves.
      for size in 16 32 48 64 128 256 512 1024; do
        src_icon="${prev.discord}/share/icons/hicolor/''${size}x''${size}/apps/discord.png"
        if [ -f "$src_icon" ]; then
          mkdir -p "$out/share/icons/hicolor/''${size}x''${size}/apps"
          cp "$src_icon" "$out/share/icons/hicolor/''${size}x''${size}/apps/legcord.png"
        fi
      done
      runHook postInstall
    '';
  };
}
