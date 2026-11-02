{lib, ...}: let
  # Every sibling `<name>.nix` or `<name>/` is a language and must gate itself on `languages.<name>.enable`.
  modules = lib.filterAttrs (entry: _: entry != "default.nix" && entry != "tests") (builtins.readDir ./.);
  languages = map (lib.removeSuffix ".nix") (lib.attrNames modules);
in {
  imports = map (entry: ./. + "/${entry}") (lib.attrNames modules);

  options.languages = lib.genAttrs languages (name: {
    enable = lib.mkEnableOption "${name} support in nvim" // {default = true;};
  });
}
