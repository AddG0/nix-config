# recolor.js as a call prefix, `${recolor} (css) => { …apply css… });`, shared by the comms apps.
{
  lib,
  colors,
}: let
  c = colors.withHashtag;
in
  # recolor.js ends in `};`, a syntax error inside the wrapping parens, so the `;` is stripped.
  "(${lib.removeSuffix ";" (lib.trim (builtins.readFile ./recolor.js))})(${builtins.toJSON (lib.genAttrs (map (n: "base0${n}") ["0" "1" "2" "3" "4" "5" "8" "9" "A" "B" "C" "D" "E"]) (n: c.${n}))},"
