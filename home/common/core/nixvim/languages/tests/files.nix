# A language switched off leaves nvim without its server and tools; the others keep theirs.
{
  harness,
  lib,
  pkgs,
  self,
  ...
}: let
  inherit (pkgs.stdenv.hostPlatform) system;
  nixvim = languages:
    (self.inputs.nixvim.lib.evalNixvim {
      inherit system;
      modules = [
        ../.
        {
          inherit languages;
          # ../lsp.nix turns this on; without it no server package reaches nvim's PATH.
          plugins.lsp.enable = true;
          _module.args = {
            inherit self;
            customPkgs = self.legacyPackages.${system};
            colors = {};
            muted = {};
            fonts = {};
            osConfig = null;
            flakeDir = null;
          };
        }
      ];
    })
    .config;
  everything = nixvim {};
  withoutRust = nixvim {rust.enable = false;};
  nothing = nixvim (lib.mapAttrs (_: _: {enable = false;}) everything.languages);
  hasPackage = config: name: lib.any (p: lib.getName p == name) config.extraPackages;
  # `*` holds the defaults every server shares, not a server.
  enabledServers = config: lib.attrNames (lib.filterAttrs (name: server: name != "*" && server.enable or false) config.lsp.servers);
in
  harness.check "nvim-languages-files" (harness.values {
    "test rust-analyzer reaches nvim's PATH while rust is on" = {
      expr = everything.plugins.lsp.servers.rust_analyzer.enable && hasPackage everything "rust-analyzer";
      expected = true;
    };
    "test a disabled language's server is off" = {
      expr = withoutRust.plugins.lsp.servers.rust_analyzer.enable;
      expected = false;
    };
    "test a disabled language's tools leave nvim's PATH" = {
      expr = hasPackage withoutRust "rust-analyzer";
      expected = false;
    };
    "test the other languages stay on when one is disabled" = {
      expr = withoutRust.plugins.lsp.servers.lua_ls.enable;
      expected = true;
    };
    "test every language gates its servers on its own switch" = {
      expr = enabledServers nothing;
      expected = [];
    };
    "test every language gates its tools on its own switch" = {
      expr = map lib.getName nothing.extraPackages;
      expected = [];
    };
  })
