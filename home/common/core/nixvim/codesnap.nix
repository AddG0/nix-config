# Code screenshots — the nvim analog of VSCode's CodeSnap (adpyke.codesnap, same
# family) and JetBrains' Easy Code Screenshots. Rust-rendered rounded window with
# a gradient background. nixpkgs ships the prebuilt generator binary.
#
# Usage: select code in visual mode, then
#   <leader>cy → copy a styled PNG to the system clipboard
#   <leader>cY → save it to save_path
{
  pkgs,
  lib,
  fonts,
  ...
}: {
  extraPlugins = [pkgs.vimPlugins.codesnap-nvim];

  # codesnap appends its generator lib dir to package.cpath as a catch-all, which
  # shadows other C modules — it makes blink.cmp's `require('blink_cmp_fuzzy')`
  # load codesnap's libgenerator.so (no matching symbol), so blink's Rust fuzzy
  # matcher silently falls back to the slow Lua one. Preload blink's fuzzy lib
  # here — extraConfigLuaPre runs before codesnap.setup touches cpath — so it's
  # cached correctly before the collision.
  extraConfigLuaPre = ''
    pcall(require, "blink.cmp.fuzzy.rust")
  '';

  # The generator copies the PNG to the clipboard; on Wayland that needs
  # wl-clipboard. Linux-only so the aarch64-darwin standalone build still evals.
  extraPackages = lib.optionals pkgs.stdenv.hostPlatform.isLinux [pkgs.wl-clipboard];

  # setup() deep-merges over the defaults, so this only overrides what we want.
  extraConfigLua = ''
    require("codesnap").setup({
      show_workspace = false,
      snapshot_config = {
        watermark = { content = "" },
        code_config = {
          font_family = "${fonts.monospace.name}",
          breadcrumbs = { enable = true, separator = "/" },
        },
        -- ray.so "Breeze" gradient (pink → purple) — matches the VSCode CodeSnap config.
        background = {
          start = { x = 0, y = 0 },
          ["end"] = { x = "max", y = "max" },
          stops = {
            { position = 0, color = "#cf2f98" },
            { position = 1, color = "#6a3dec" },
          },
        },
      },
    })
  '';

  keymaps = [
    {
      mode = "x";
      key = "<leader>cy";
      action = "<cmd>CodeSnap<cr>";
      options.desc = "Code screenshot → clipboard";
    }
    {
      # :CodeSnapSave requires an explicit .png path (it doesn't read a config
      # default), so build a timestamped file in codesnap's default pictures dir
      # ($XDG_PICTURES_DIR / ~/Pictures), creating it if needed.
      mode = "x";
      key = "<leader>cY";
      action.__raw = ''
        function()
          local dir = require("codesnap.utils.path").get_default_save_path()
          vim.fn.mkdir(dir, "p")
          -- project name = git root basename, else cwd basename
          local root = vim.fs.root(0, ".git") or vim.fn.getcwd()
          local project = vim.fn.fnamemodify(root, ":t")
          require("codesnap").save(dir .. "/codesnap-" .. project .. "-" .. os.date("%Y%m%d-%H%M%S") .. ".png")
        end
      '';
      options.desc = "Code screenshot → file";
    }
  ];
}
