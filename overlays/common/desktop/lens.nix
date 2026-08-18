# Lens needs two fixes applied around the AppImage, so this rebuilds the
# wrapper rather than using `overrideAttrs`: the extracted contents are patched
# first, then re-wrapped. Mirrors nixpkgs' pkgs/by-name/le/lens/linux.nix —
# re-check that file on version bumps.
#
#   1. --disable-gpu: invisible window on NVIDIA + Wayland (Electron bug).
#   2. app.asar: the Lens Cloud auth callback server binds `listen(0,
#      "localhost")` but hands the browser the *name* `localhost`, so the two
#      resolve independently. Here it binds ::1 while a v4-only browser dials
#      127.0.0.1 and gets connection refused. See the .py for the mechanics.
_: _final: prev:
prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
  lens = let
    inherit (prev.lens) pname version src;

    contents = prev.appimageTools.extract {
      inherit pname version src;
      postExtract = ''
        ${prev.python3.interpreter} ${./patch-lens-auth-callback-bind.py} \
          "$out/resources/app.asar"
      '';
    };
  in
    prev.appimageTools.wrapAppImage {
      inherit pname version contents;
      inherit (prev.lens) meta;

      passthru = {inherit src;} // (prev.lens.passthru or {});

      nativeBuildInputs = [prev.makeWrapper];

      extraInstallCommands = ''
        wrapProgram $out/bin/${pname} \
          --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
          --add-flags "--disable-gpu"
        install -m 444 -D ${contents}/${pname}.desktop \
          $out/share/applications/${pname}.desktop
        install -m 444 -D ${contents}/usr/share/icons/hicolor/512x512/apps/${pname}.png \
          $out/share/icons/hicolor/512x512/apps/${pname}.png
        substituteInPlace $out/share/applications/${pname}.desktop \
          --replace-fail 'Exec=AppRun' 'Exec=${pname}'
      '';

      extraPkgs = pkgs: [pkgs.nss_latest];
    };
}
