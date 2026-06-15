# Curated wallhaven.cc wallpapers, declaratively installed into
# ~/Pictures/Wallpapers/default/ via `wallpapers.images` (declared in
# wallpaper.nix). Declaring the `default` folder auto-disables the
# stylix-image seed — see `wallpapers.defaultSeed.enable` default.
#
# To add a wallpaper: add a `{ id; ext; hash; }` entry to `wallhavens`.
# Get the hash with `nix hash file <downloaded-file>`.
# Wallhaven CDN URL pattern: w.wallhaven.cc/full/<first 2 chars>/wallhaven-<id>.<ext>
{pkgs, ...}: let
  wh = id: ext: hash: {
    name = "wallhaven-${id}.${ext}";
    value = pkgs.fetchurl {
      name = "wallhaven-${id}.${ext}";
      url = "https://w.wallhaven.cc/full/${builtins.substring 0 2 id}/wallhaven-${id}.${ext}";
      inherit hash;
    };
  };
in {
  wallpapers.images.default = builtins.listToAttrs [
    (wh "1kv693" "jpg" "sha256-lyG1RnHxKk/eDYtRV9jdsluTt6SotiYypLeSuwumWUU=")
    (wh "1ky673" "png" "sha256-V725g6majvaVQLCZQ9ucQPBDq0Jw3De9sOpUjB6Uzts=")
    (wh "1p75xv" "jpg" "sha256-5q1/izpKGI93TmQHPEx0xWh0Ebp6b3qQU+2pfvxSgS8=")
    (wh "1pv19v" "png" "sha256-NwQOCBXaw6D3cBwM0sDShPebcrx7eGUCaGrENFj3Qvg=")
    (wh "285e6x" "png" "sha256-Ni3XkTxRKxiysLZJUJ0QFMLz/WUgPFMsumvdWyWLblE=")
    (wh "2y53dy" "jpg" "sha256-Xql/XCiviSsHvABJ4I2FvVtU8Mh9sO6EzmlM9YW1NiU=")
    (wh "3kpvkd" "jpg" "sha256-75SQRAvHovMtseT86mZK+XmKe9IVxjm4QkhEZ419qgw=")
    (wh "3lpymv" "png" "sha256-/f5eZgv9mBr7ozSgQYbm+9qfs4ED/hn+uTTbpfNe07g=")
    (wh "5g22q5" "png" "sha256-snqkeQecU0opsBfIrnkl6aiV71hSCmqnZBAsibNG4w8=")
    (wh "7jrmme" "jpg" "sha256-RRnLXbDkxoOXmOHT2bCCOfy5ZrVgk6m+pgHfc2R67yM=")
    (wh "eolmrl" "jpg" "sha256-XtV9TqFQUVGxlJbn90T1aCFKNBF9uWVX5MlAi3u/6Uk=")
    (wh "g7mpj7" "jpg" "sha256-2KdHSu4Wsd2bn9D28WK5+WWd87QPTvxWXljY8UCpaR8=")
    (wh "g83qpe" "jpg" "sha256-orMabHyGVacR9m/sK9Am0G1+tYopvwa/n0K20kPNI9A=")
    (wh "gpedg3" "jpg" "sha256-8IhJk6aIO/e3l6/bgif3/tqtyW3Caz1+nW7fQhAKW8k=")
    (wh "j5v28q" "jpg" "sha256-+boclAxlwK9OPqKEj+04iburJkzvyGOqrYK27OcIqnY=")
    (wh "kw22p1" "jpg" "sha256-rzg4/DYoXqoNmtAvEfVjqcKurblBPBKA6R1GYv0h3g4=")
    (wh "kwd36d" "jpg" "sha256-eGJ6aiBcWJty3GVsvYodl0Zv1CuQomCaMnn0YFUlc/s=")
    (wh "m3kggk" "jpg" "sha256-rDlAmzCfL/392Fi3dVGSExA4zwxWdqImKk9hcHF0oUg=")
    (wh "md6578" "jpg" "sha256-hRj4n9DsWhfl3YCs3jXzFba7QCEt6FHGPdlj/AMSqP0=")
    (wh "pkz5r9" "png" "sha256-Kf1rv8LujcKWUYbuk3wKzw5UiFHGDOGQO1cwaE1FG40=")
    (wh "r22x8m" "jpg" "sha256-yGqF/mCPyJ3N3hf46r5jgtnb6tpTyNb696VjS1gYNfo=")
    (wh "wed2qq" "png" "sha256-AU8Gu6VlvLT2QIUH2Ou2PS7F+msdSgz3FLXlFcgvWgY=")
    (wh "x6m79l" "png" "sha256-+BguNjnWMIV6Pg3rjRUDTozxlPaom0sWnWrsujFDrq0=")
    (wh "xl19lv" "jpg" "sha256-kt7+MeoXQPqPQeK9Uodjne7XY0IdUcaOQdHUiEj/p5g=")
    (wh "yjk6ml" "jpg" "sha256-zYSHfhf8XDwjnkSe1WO49O9g32y9Ee73zmwKWdD4Ffk=")
    (wh "yxe85x" "jpg" "sha256-z/attvjcG1nReBjCVBY/JS2Eu2U44+Pd2OtIF1dPb1M=")
    (wh "zp8o3j" "jpg" "sha256-Mhlx8SZBt69AgKHfGuRtWtaRybUi9NeJzFo5qeeDX2w=")
  ];
}
