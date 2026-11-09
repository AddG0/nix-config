# zsh-completion-sync as ../zsh-completion-sync-fix-path-scan.nix patches it, driven by a fake profile symlink the way NixOS lays out /etc/profiles.
{
  pkgs,
  harness,
  self,
  ...
}: let
  # Plain nixpkgs: the checks' pkgs already carries our overlays, so extending it would patch twice.
  patched = self.inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.extend (import ../zsh-completion-sync-fix-path-scan.nix {});
in
  harness.bats "zsh-completion-sync" [./zsh-completion-sync.bats] {
    nativeBuildInputs = [pkgs.zsh pkgs.coreutils];
    plugin = "${patched.zsh-completion-sync}/share/zsh-completion-sync/zsh-completion-sync.plugin.zsh";
  }
