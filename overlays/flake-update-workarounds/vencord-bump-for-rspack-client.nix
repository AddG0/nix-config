# Discord's web client moved to rspack (Nov 2026); Vencord < 1.15.16 dies on it
# with "i.A is not a constructor" and Discord hangs on its "Starting…" splash.
# CHECK-RUNTIME: drop once the pinned nixpkgs has vencord >= 1.15.16 (`nix eval .#nixosConfigurations.demon.pkgs.vencord.version` without this overlay).
_: _final: prev: {
  vencord = prev.vencord.overrideAttrs (old: {
    version = "1.15.16";
    src = old.src.override {
      tag = "v1.15.16";
      hash = "sha256-aUJubLJpyLAZWiOezqFxPY6oVPgWVPQpajFqrJvrO9U=";
    };
    # 1.15.16 pins @types/react 19 itself, which is all these bumped.
    patches = [];
    postPatch = "";
    pnpmDeps = old.pnpmDeps.overrideAttrs {
      outputHash = "sha256-HS8uZNepvDefjrsG3buVLFCVv7sHvazcwdpcT3EQ/78=";
    };
  });
}
