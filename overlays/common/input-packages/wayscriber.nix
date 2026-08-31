# wayscriber shells out to grim/slurp for screen capture but isn't self-contained,
# so capture fails when they're missing from its PATH (as under systemd).
#
# The wrapper reads the unwrapped package from `final` so later overlays can
# patch the program itself; symlinkJoin stringifies `paths`, so overriding the
# wrapper cannot reach it.
{inputs, ...}: final: prev:
prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
  wayscriber-unwrapped = inputs.wayscriber.packages.${prev.stdenv.hostPlatform.system}.default;

  wayscriber = prev.symlinkJoin {
    inherit (final.wayscriber-unwrapped) name;
    paths = [final.wayscriber-unwrapped];
    nativeBuildInputs = [prev.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/wayscriber \
        --prefix PATH : ${prev.lib.makeBinPath [prev.grim prev.slurp prev.wl-clipboard]}
    '';
  };
}
