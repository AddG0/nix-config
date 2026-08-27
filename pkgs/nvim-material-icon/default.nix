# Drop-in nvim-web-devicons replacement with Material Design Icon glyphs —
# ships its module tree as lua/nvim-web-devicons.lua, so any plugin that does
# `require("nvim-web-devicons")` (Snacks, bufferline, lualine, ...) picks this
# up transparently once it's the only devicons-shaped plugin on the runtimepath.
{
  lib,
  vimUtils,
  fetchFromGitHub,
}:
vimUtils.buildVimPlugin {
  pname = "nvim-material-icon";
  version = "unstable-2025-10-25";

  src = fetchFromGitHub {
    owner = "DaikyXendo";
    repo = "nvim-material-icon";
    rev = "5e75c5e631cba8f0001f189af9d0d9beb5276501";
    hash = "sha256-e8g58zyW/K9UP2TPkZt1P3k/jTLX1EARZVRjGrHXPuk=";
  };

  # buildVimPlugin's default check derives the module name from `pname`
  # ("nvim-material-icon"), but the plugin only exposes "nvim-web-devicons".
  doCheck = false;

  meta = {
    description = "Material Design Icon glyphs, as a drop-in nvim-web-devicons replacement";
    homepage = "https://github.com/DaikyXendo/nvim-material-icon";
    license = lib.licenses.mit;
  };
}
