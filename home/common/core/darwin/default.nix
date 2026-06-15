{
  lib,
  pkgs,
  ...
}: {
  imports = lib.flatten [
    (lib.custom.scanPaths ./.)
  ];

  home.packages = with pkgs; [
    pam-reattach
    utm # virtual machine
  ];

  # Disable Sparkle auto-update helpers for all installed apps to prevent
  # macOS approval popups on every nix store path change.
  home.activation.disableSparkleUpdates = lib.hm.dag.entryAfter ["writeBoundary"] ''
    for app_dir in /Applications "$HOME/Applications" "$HOME/Applications/Home Manager Apps" "$HOME/Applications/Nix"; do
      [ -d "$app_dir" ] || continue
      for app in "$app_dir"/*.app; do
        [ -d "$app/Contents/Frameworks/Sparkle.framework" ] || continue
        bundle_id=$(defaults read "$app/Contents/Info" CFBundleIdentifier 2>/dev/null) || continue
        run defaults write "$bundle_id" SUEnableAutomaticChecks -bool false
      done
    done
  '';
}
