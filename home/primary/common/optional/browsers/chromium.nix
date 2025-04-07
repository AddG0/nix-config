{
  config,
  pkgs,
  ...
}: {
  programs.chromium = {
    enable = true;
    extensions = [
      {id = "aeblfdkhhhdcdjpifhhbdiojplfjncoa";} # 1password
      {id = "aefkmifgmaafnojlojpnekbpbmjiiogg";} # Popup Blocker (strict)
      {id = "kdbmhfkmnlmbkgbabkdealhhbfhlmmon";} # SteamDB
    ];
  };
}
