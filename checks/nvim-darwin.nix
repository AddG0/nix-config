# Guard: the standalone nvim (`nix run .#nvim`) must keep evaluating on
# aarch64-darwin (Apple Silicon). The regression we hit once — a Linux-only
# package (kotlin-lsp) sneaking into the nixvim closure — fails at *eval*
# (meta.platforms refusal), not at build. So we force the darwin derivation's
# drvPath to evaluate; `builtins.seq` discards the result so the darwin output is
# never built, letting this run in CI / pre-commit on Linux with no Mac.
#
# The auto-generated `package-nvim` check (checks/packages.nix) can't cover this:
# it filters out packages that fail `tryEval`, so a broken darwin build would
# silently disappear from the checks instead of failing them.
{self, ...}: {
  perSystem = {pkgs, ...}: {
    checks.nvim-aarch64-darwin-evals = pkgs.runCommand "nvim-aarch64-darwin-evals" {
      forced = builtins.seq self.packages.aarch64-darwin.nvim.drvPath "ok";
    } "touch $out";
  };
}
