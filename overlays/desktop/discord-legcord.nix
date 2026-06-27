# Legcord with Discord branding (binary alias + Discord icons/desktop entry).
_: _final: prev: {
  discord-legcord = prev.stdenv.mkDerivation {
    pname = "discord-legcord";
    inherit (prev.legcord) version;

    dontUnpack = true;

    nativeBuildInputs = [];

    installPhase = ''
      mkdir -p $out/bin $out/share/applications $out/share/icons/hicolor

      # Link legcord binary and create discord alias
      ln -s "${prev.legcord}/bin/legcord" "$out/bin/legcord"
      ln -s "$out/bin/legcord" "$out/bin/discord"

      # Copy Discord icons as legcord.png (to match Icon=legcord)
      for size in 16 32 48 64 128 256 512 1024; do
        src_icon="${prev.discord}/share/icons/hicolor/''${size}x''${size}/apps/discord.png"
        if [ -f "$src_icon" ]; then
          mkdir -p "$out/share/icons/hicolor/''${size}x''${size}/apps"
          cp "$src_icon" "$out/share/icons/hicolor/''${size}x''${size}/apps/legcord.png"
        fi
      done

      # Create desktop file named legcord.desktop (matches desktopFile: legcord)
      cat > "$out/share/applications/legcord.desktop" << EOF
      [Desktop Entry]
      Name=Discord
      Comment=All-in-one voice and text chat for gamers
      Exec=legcord
      Icon=legcord
      Type=Application
      Categories=Network;InstantMessaging;
      StartupWMClass=legcord
      EOF
    '';
  };
}
