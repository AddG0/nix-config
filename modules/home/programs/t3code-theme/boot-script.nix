# The theme-install script the client loads before the app mounts. Split out from
# default.nix so tests.nix can build it against a fixture palette.
{
  pkgs,
  theme,
}:
pkgs.replaceVarsWith {
  src = ./install-theme.js.in;
  replacements = {
    theme = builtins.toJSON theme;
    # Changes with the palette; the script re-selects the theme when it does.
    revision = builtins.substring 0 12 (builtins.hashString "sha256" (builtins.toJSON theme));
  };
  nativeBuildInputs = [pkgs.nodejs];
  # A syntax error here would only surface as a silently unthemed app.
  postCheck = ''
    cp "$target" boot-script.js
    node --check boot-script.js
  '';
}
