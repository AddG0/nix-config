# wayscriber shells out to grim/slurp for screen capture but isn't self-contained,
# so capture fails when they're missing from its PATH (as under systemd).
{inputs, ...}: _final: prev:
prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
  wayscriber = let
    base = inputs.wayscriber.packages.${prev.stdenv.hostPlatform.system}.default;
  in
    prev.symlinkJoin {
      inherit (base) name;
      paths = [base];
      nativeBuildInputs = [prev.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/wayscriber \
          --prefix PATH : ${prev.lib.makeBinPath [prev.grim prev.slurp prev.wl-clipboard]}
      '';
    };
}
