{
  config,
  lib,
  pkgs,
  ...
}: let
  # rnote's default workspace is the relative path "./" (resolves to the launch
  # cwd), so pin it to a real folder.
  rnoteDir = "${config.home.homeDirectory}/Documents/rnote";
  inherit (lib.hm.gvariant) mkArray mkTuple mkUint32 mkString type;

  # rnote stores paths as `ay`; hm.gvariant has no bytestring builder, so emit a native b'…' literal.
  mkAy = s: {
    _type = "gvariant";
    type = "ay";
    value = s;
    __toString = _: "b'" + lib.escape ["'" "\\"] s + "'";
  };
in {
  # Stylus/drawing-tablet note apps: rnote (infinite canvas), xournalpp (PDF + LaTeX).
  home.packages = with pkgs; [rnote xournalpp];

  home.activation.rnoteWorkspace = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run mkdir -p "${rnoteDir}"
  '';

  dconf.settings."com/github/flxzt/rnote" = {
    selected-workspace-index = mkUint32 0;
    workspace-list = mkArray (type.tupleOf [(type.arrayOf type.uchar) type.string type.uint32 type.string]) [
      (mkTuple [
        (mkAy rnoteDir)
        (mkString "folder-symbolic")
        (mkUint32 442479871)
        (mkString "rnote")
      ])
    ];
  };
}
