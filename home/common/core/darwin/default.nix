{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = lib.flatten [
    (lib.custom.scanPaths ./.)
  ];

  # Install MacOS applications to the user environment if the targetPlatform is Darwin
  home.file."Applications/home-manager".source = let
    apps = pkgs.buildEnv {
      name = "home-manager-applications";
      paths = config.home.packages;
      pathsToLink = ["/Applications"];
    };
  in
    lib.mkIf pkgs.stdenv.targetPlatform.isDarwin "${apps}/Applications";

  home.packages = with pkgs; [
    pam-reattach
    utm # virtual machine
  ];

  # home.activation.aliasHomeManagerApplications = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  #   app_folder="${config.home.homeDirectory}/Applications/Home Manager Trampolines"
  #   rm -rf "$app_folder"
  #   mkdir -p "$app_folder"
  #   find "$genProfilePath/home-path/Applications" -type l -print | while read -r app; do
  #       app_target="$app_folder/$(basename "$app")"
  #       real_app="$(readlink "$app")"
  #       echo "mkalias \"$real_app\" \"$app_target\"" >&2
  #       $DRY_RUN_CMD ${pkgs.mkalias}/bin/mkalias "$real_app" "$app_target"
  #   done
  # '';
}
