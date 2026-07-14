# FLAKE-UPDATE: skips two wayscriber tests that fail in the Nix build sandbox
# after `nix flake update`, neither a real bug in the tool:
#
#   - icon_fn_compares_by_address_and_debugs_stably: the newer rustc/LLVM folds
#     byte-identical fns to one address, so this test — asserting two empty fns
#     compared via `std::ptr::fn_addr_eq` have distinct addresses — spuriously
#     fails. The documented `fn_addr_eq` caveat, not a bug.
#   - render_onboarding_card_without_checklist_stays_compact: a pixel-threshold
#     layout test (span must be < 180px). The sandbox has no system fonts, so
#     fallback metrics push the wrapped body ~2px over. 8/9 ui tests still pass.
#
# Layers onto the base pkgs.wayscriber overlay. Drop this file once upstream
# hardens both tests (black_box the fns; loosen the pixel threshold).
#
# A flake input, not a nixpkgs attr, so the CHECK-ATTR harness can't build it.
# CHECK-RUNTIME: flake-input build failure — re-check by dropping this file, then `nix build .#...wayscriber`; if its test suite passes, the workaround is redundant.
_: _final: prev:
prev.lib.optionalAttrs prev.stdenv.isLinux {
  wayscriber = prev.wayscriber.overrideAttrs (old: {
    checkFlags =
      (old.checkFlags or [])
      ++ [
        "--skip=backend::wayland::toolbar::view::node::tests::icon_fn_compares_by_address_and_debugs_stably"
        "--skip=render_onboarding_card_without_checklist_stays_compact"
      ];
  });
}
