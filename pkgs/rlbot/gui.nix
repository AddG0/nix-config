# RLBotGUI: the match-launching front-end (Wails v3, hence the WebKitGTK deps).
#
# It never spawns the server - it only dials RLBOT_SERVER_IP:RLBOT_SERVER_PORT
# (127.0.0.1:23234), so something else has to be listening.
{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  autoPatchelfHook,
  wrapGAppsHook3,
  webkitgtk_4_1,
  gtk3,
  libsoup_3,
  glib,
  gdk-pixbuf,
  zenity,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "rlbot-gui";
  version = "beta23";

  src = fetchurl {
    url = "https://github.com/RLBot/gui/releases/download/${finalAttrs.version}/rlbotgui";
    hash = "sha256-X+g7APbEd3+w2/xciHXiTihtBzd554jKiQI5HhteGFY=";
  };

  dontUnpack = true;

  nativeBuildInputs = [makeWrapper autoPatchelfHook wrapGAppsHook3];
  buildInputs = [webkitgtk_4_1 gtk3 libsoup_3 glib gdk-pixbuf];

  # Upstream wants zenity, matedialog or qarma on PATH for file pickers.
  gappsWrapperArgs = ["--prefix" "PATH" ":" (lib.makeBinPath [zenity])];

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/rlbotgui"
    runHook postInstall
  '';

  meta = {
    description = "Official GUI for the RLBot v5 framework";
    homepage = "https://github.com/RLBot/gui";
    license = lib.licenses.mit;
    platforms = ["x86_64-linux"];
    mainProgram = "rlbotgui";
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
})
