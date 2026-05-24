{
  config,
  pkgs,
  ...
}: {
  environment.systemPackages = [pkgs.boxflat];

  # Registers boxflat's 99-boxflat.rules for MOZA USB serial (vendor 346e).
  services.udev.packages = [pkgs.boxflat];

  # Override the in-tree hid-universal-pidff with a newer out-of-tree build.
  #
  # The kernel-shipped module has an integer overflow in pidff_rescale() that
  # fires on the periodic-effect phase parameter Forza sends (65353 rescales
  # to -29637, which doesn't fit the 16-bit field). The module then SILENTLY
  # DROPS those effect uploads — not "occasional FFB drops at high speed" as
  # I first thought, but a continuous spam during active gameplay that kills
  # most of the road-feel/surface/bump FFB. Symptom: wheel feels dead or
  # weak in-game; dmesg fills with `implement() called with too large value
  # -29637 (n: 16)`.
  #
  #   Bug:  https://github.com/JacKeTUs/universal-pidff/issues/116
  #   Fix:  https://github.com/JacKeTUs/universal-pidff/pull/117 (merged
  #         2026-04-20) + LKML overflow follow-up on main 2026-05-19.
  #
  # nixpkgs ships universal-pidff 0.2.2 (2026-02-03), which predates the fix.
  # Pinning to a post-fix main commit until 0.2.3 is tagged and bumped.
  # Modules installed under updates/ take priority over kernel/ in depmod
  # ordering, so this shadows the in-tree module without blacklisting.
  #
  # Cleanup path:
  #   Stage 1 — nixpkgs bumps to >= 0.2.3 (check with
  #     `nix eval --raw nixpkgs#linuxPackages.universal-pidff.version`).
  #     Then drop the overrideAttrs wrapper:
  #       boot.extraModulePackages = [config.boot.kernelPackages.universal-pidff];
  #   Stage 2 — fix lands in the in-tree kernel module. Verify by commenting
  #     this block out, rebuilding, and grepping `dmesg | grep "too large value"`
  #     after some Forza playtime. If silent, delete the whole block.
  boot.extraModulePackages = [
    (config.boot.kernelPackages.universal-pidff.overrideAttrs (_: {
      version = "unstable-2026-05-19";
      src = pkgs.fetchFromGitHub {
        owner = "JacKeTUs";
        repo = "universal-pidff";
        rev = "9b7760c6ca77d252d7ec915823d1464bf718bdc7";
        hash = "sha256-pAxPke/Vli68qx7cZ2BMC3MzR3pvxZClYMrJwsVMeFI=";
      };
    }))
  ];
}
